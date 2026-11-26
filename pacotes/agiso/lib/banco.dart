// banco.dart — guarda talhões, trabalhos e mapas de aplicação num SQLite local (drift)
//
// Um arquivo só, compartilhado pela cabine e pelo simulador:
//   ~/.local/share/cabine-isobus/agro.sqlite
// O simulador importa o shapefile e marca o talhão como ATIVO; a cabine lê o ativo e
// usa o mesmo mapa de prescrição no TC-GEO. Cada trabalho guarda o mapa de aplicação
// (a grade com a taxa aplicada em cada célula), comprimido.
//
// O código gerado (banco.g.dart) sai de: dart run build_runner build
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'geo.dart';

part 'banco.g.dart';

@DataClassName('TalhaoSalvo')
class Talhoes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nome => text()();

  /// Contorno e zonas de prescrição em graus (JSON).
  TextColumn get geometria => text()();
  IntColumn get taxaPadrao => integer()();
  RealColumn get origemLat => real()();
  RealColumn get origemLon => real()();
  BoolColumn get ativo => boolean().withDefault(const Constant(false))();
  DateTimeColumn get criadoEm => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Trabalho')
class Trabalhos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get talhaoId => integer().references(Talhoes, #id)();
  DateTimeColumn get inicio => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get fim => dateTime().nullable()(); // null = em andamento
  RealColumn get hectares => real().withDefault(const Constant(0))();
  RealColumn get sementes => real().withDefault(const Constant(0))();
  RealColumn get distanciaM => real().withDefault(const Constant(0))();
}

/// O mapa de aplicação de um trabalho: a grade do [MapaAplicacao], comprimida (zlib).
@DataClassName('MapaSalvo')
class MapasAplicacao extends Table {
  IntColumn get trabalhoId => integer().references(Trabalhos, #id)();
  RealColumn get origemE => real()();
  RealColumn get origemN => real()();
  RealColumn get celula => real()();
  IntColumn get largura => integer()();
  IntColumn get altura => integer()();
  BlobColumn get dados => blob()();

  /// Onde a plantadeira passou duas vezes (zlib); null nos mapas da versão 1.
  BlobColumn get sobrepostas => blob().nullable()();
  DateTimeColumn get atualizadoEm =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {trabalhoId};
}

@DriftDatabase(tables: [Talhoes, Trabalhos, MapasAplicacao])
class Banco extends _$Banco {
  Banco(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, de, para) async {
      if (de < 2)
        await m.addColumn(
          mapasAplicacao,
          mapasAplicacao.sobrepostas,
        ); // v2: sobreposição
    },
  );

  static String caminhoPadrao() {
    final dados =
        Platform.environment['XDG_DATA_HOME'] ??
        '${Platform.environment['HOME']}/.local/share';
    return '$dados/cabine-isobus/agro.sqlite';
  }

  /// Abre (ou cria) o banco. A cabine e o simulador abrem o mesmo arquivo ao mesmo
  /// tempo: WAL deixa um ler enquanto o outro escreve, e o busy_timeout espera a vez.
  static Banco abrir([String? caminho]) {
    final arquivo = File(caminho ?? caminhoPadrao());
    arquivo.parent.createSync(recursive: true);
    return Banco(
      NativeDatabase.createInBackground(
        arquivo,
        setup: (db) {
          db.execute('PRAGMA journal_mode = WAL');
          db.execute('PRAGMA busy_timeout = 5000');
        },
      ),
    );
  }

  // --- talhões ---

  /// Guarda o talhão e o marca como o ativo (o que a cabine usa).
  Future<int> salvarTalhao(Talhao t) => transaction(() async {
    await update(talhoes).write(const TalhoesCompanion(ativo: Value(false)));
    return into(talhoes).insert(
      TalhoesCompanion.insert(
        nome: t.nome,
        geometria: jsonEncode({
          'contorno': [
            for (final p in t.geo.contorno)
              [
                for (final a in p)
                  [
                    for (final g in a) [g.lon, g.lat],
                  ],
              ],
          ],
          'zonas': [
            for (final z in t.geo.zonas)
              {
                'taxa': z.taxa,
                'aneis': [
                  for (final a in z.aneis)
                    [
                      for (final g in a) [g.lon, g.lat],
                    ],
                ],
              },
          ],
        }),
        taxaPadrao: t.taxaPadrao,
        origemLat: t.lat0,
        origemLon: t.lon0,
        ativo: const Value(true),
      ),
    );
  });

  Future<void> ativarTalhao(int id) => transaction(() async {
    await update(talhoes).write(const TalhoesCompanion(ativo: Value(false)));
    await (update(talhoes)..where((t) => t.id.equals(id))).write(
      const TalhoesCompanion(ativo: Value(true)),
    );
  });

  /// O id do talhão ativo: barato, para a cabine perguntar de tempos em tempos.
  Future<int?> idTalhaoAtivo() async {
    final linha =
        await (selectOnly(talhoes)
              ..addColumns([talhoes.id])
              ..where(talhoes.ativo.equals(true))
              ..limit(1))
            .getSingleOrNull();
    return linha?.read(talhoes.id);
  }

  Future<({int id, Talhao talhao})?> talhaoAtivo() async {
    final s =
        await (select(talhoes)
              ..where((t) => t.ativo.equals(true))
              ..limit(1))
            .getSingleOrNull();
    return s == null ? null : (id: s.id, talhao: _talhao(s));
  }

  /// Um talhão guardado (para ver um trabalho antigo de outro talhão).
  Future<Talhao?> talhao(int id) async {
    final s = await (select(
      talhoes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return s == null ? null : _talhao(s);
  }

  Future<List<TalhaoSalvo>> listarTalhoes() =>
      (select(talhoes)..orderBy([(t) => OrderingTerm.desc(t.criadoEm)])).get();

  static Talhao _talhao(TalhaoSalvo s) {
    final g = jsonDecode(s.geometria) as Map<String, dynamic>;
    List<List<PontoGeo>> aneis(List<dynamic> lista) => [
      for (final a in lista)
        [
          for (final p in (a as List))
            (lon: (p[0] as num).toDouble(), lat: (p[1] as num).toDouble()),
        ],
    ];
    return Talhao.deGeo(
      nome: s.nome,
      contorno: [for (final p in g['contorno'] as List) aneis(p as List)],
      zonas: [
        for (final z in g['zonas'] as List)
          (aneis: aneis(z['aneis'] as List), taxa: z['taxa'] as int),
      ],
      taxaPadrao: s.taxaPadrao,
      origem: (lon: s.origemLon, lat: s.origemLat),
    );
  }

  // --- trabalhos e mapas de aplicação ---

  Future<int> iniciarTrabalho(int talhaoId) =>
      into(trabalhos).insert(TrabalhosCompanion.insert(talhaoId: talhaoId));

  /// O trabalho em andamento no talhão (para continuar de onde parou).
  Future<Trabalho?> trabalhoAberto(int talhaoId) =>
      (select(trabalhos)
            ..where((t) => t.talhaoId.equals(talhaoId) & t.fim.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.inicio)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<Trabalho>> trabalhosDo(int talhaoId) =>
      (select(trabalhos)
            ..where((t) => t.talhaoId.equals(talhaoId))
            ..orderBy([(t) => OrderingTerm.desc(t.inicio)]))
          .get();

  /// Grava o mapa de aplicação e os totais do trabalho (e encerra, se pedido).
  Future<void> salvarTrabalho(
    int id,
    MapaAplicacao mapa, {
    double distancia = 0,
    bool encerrar = false,
  }) => transaction(() async {
    await into(mapasAplicacao).insertOnConflictUpdate(
      MapasAplicacaoCompanion.insert(
        trabalhoId: Value(id),
        origemE: mapa.origemE,
        origemN: mapa.origemN,
        celula: mapa.celula,
        largura: mapa.largura,
        altura: mapa.altura,
        dados: Uint8List.fromList(zlib.encode(mapa.dados)),
        sobrepostas: Value(Uint8List.fromList(zlib.encode(mapa.sobrepostas))),
        atualizadoEm: Value(DateTime.now()),
      ),
    );
    await (update(trabalhos)..where((t) => t.id.equals(id))).write(
      TrabalhosCompanion(
        hectares: Value(mapa.hectares),
        sementes: Value(mapa.sementes),
        distanciaM: Value(distancia),
        fim: encerrar ? Value(DateTime.now()) : const Value.absent(),
      ),
    );
  });

  /// Volta a trabalhar num trabalho encerrado (encerrando o que estiver aberto no talhão).
  Future<void> reabrirTrabalho(int id) => transaction(() async {
    final t = await (select(
      trabalhos,
    )..where((t) => t.id.equals(id))).getSingle();
    await (update(trabalhos)
          ..where((j) => j.talhaoId.equals(t.talhaoId) & j.fim.isNull()))
        .write(TrabalhosCompanion(fim: Value(DateTime.now())));
    await (update(trabalhos)..where((j) => j.id.equals(id))).write(
      const TrabalhosCompanion(fim: Value(null)),
    );
  });

  Future<MapaAplicacao?> mapaDoTrabalho(int id) async {
    final m = await (select(
      mapasAplicacao,
    )..where((t) => t.trabalhoId.equals(id))).getSingleOrNull();
    if (m == null) return null;
    return MapaAplicacao.de(
      origemE: m.origemE,
      origemN: m.origemN,
      celula: m.celula,
      largura: m.largura,
      altura: m.altura,
      dados: Uint8List.fromList(zlib.decode(m.dados)),
      sobrepostas: m.sobrepostas == null
          ? null
          : Uint8List.fromList(zlib.decode(m.sobrepostas!)),
    );
  }
}
