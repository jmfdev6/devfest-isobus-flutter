// shapefile.dart — lê e grava shapefiles ESRI (.shp + .shx + .dbf + .prj), sem dependências
//
// .shp: cabeçalho de 100 bytes e registros (número e tamanho em big-endian, o resto em
//       little-endian). Lemos polígonos (5, 15, 25), linhas (3, 13, 23) e pontos (1).
// .dbf: a tabela de atributos (dBASE III): um registro por geometria, na mesma ordem.
// .prj: o sistema de coordenadas. Graus (WGS84/SIRGAS) entram direto; Transversa de
//       Mercator (UTM, como SIRGAS 2000 / UTM 21S) é convertida para graus na leitura.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

typedef XY = ({double x, double y});

/// Uma geometria do shapefile: anéis (ou linhas) de pontos (x = longitude, y = latitude,
/// em graus, depois da leitura).
class Feicao {
  Feicao(this.tipo, this.aneis, this.atributos);

  /// 1 = ponto, 3 = linha, 5 = polígono (as variantes Z e M viram estas).
  final int tipo;
  final List<List<XY>> aneis;
  final Map<String, Object?> atributos;

  bool get poligono => tipo == 5;
}

/// Um campo do .dbf: N (número), F (número em ponto flutuante), C (texto), D (data)...
typedef Campo = ({String nome, String tipo, int tamanho, int decimais});

class Shapefile {
  Shapefile(
    this.feicoes, {
    this.campos = const [],
    this.sistema = 'graus (sem .prj)',
  });

  /// As geometrias, sempre em graus (lon, lat).
  final List<Feicao> feicoes;
  final List<Campo> campos;

  /// De onde vieram as coordenadas, para mostrar na tela ("SIRGAS_2000_UTM_Zone_21S"...).
  final String sistema;

  List<Campo> get camposNumericos => [
    for (final c in campos)
      if (c.tipo == 'N' || c.tipo == 'F') c,
  ];

  /// Lê caminho.shp, e o .dbf e o .prj ao lado (se existirem). Coordenadas projetadas
  /// (Transversa de Mercator/UTM) viram graus aqui.
  static Shapefile ler(String caminhoShp) {
    final base = caminhoShp.replaceAll(
      RegExp(r'\.shp$', caseSensitive: false),
      '',
    );
    final geometrias = lerShp(File(caminhoShp).readAsBytesSync());
    final dbf = _irmao(base, 'dbf');
    final prj = _irmao(base, 'prj')?.readAsStringSync();
    final tabela = dbf == null ? null : lerDbf(dbf.readAsBytesSync());

    // as coordenadas: graus, ou uma projeção que sabemos desfazer
    XY Function(XY) paraGraus = (p) => p;
    var sistema = 'graus (sem .prj)';
    if (prj != null) {
      sistema =
          RegExp(r'^\s*\w+\["([^"]+)"').firstMatch(prj)?.group(1) ??
          'desconhecido';
      if (prj.toUpperCase().contains('PROJCS')) {
        final tm = TransversaDeMercator.doPrj(prj);
        paraGraus = tm.paraGraus;
      }
    } else {
      // sem .prj: só aceita se parecer graus
      final algum = geometrias
          .whereType<({int tipo, List<List<XY>> aneis})>()
          .expand((g) => g.aneis)
          .expand((a) => a);
      if (algum.any((p) => p.x.abs() > 180 || p.y.abs() > 90)) {
        throw const FormatException(
          'sem o arquivo .prj não dá para saber a projeção, e as coordenadas não são graus',
        );
      }
    }
    return Shapefile(
      [
        for (var i = 0; i < geometrias.length; i++)
          if (geometrias[i] != null)
            Feicao(
              geometrias[i]!.tipo,
              [
                for (final a in geometrias[i]!.aneis)
                  [for (final p in a) paraGraus(p)],
              ],
              tabela != null && i < tabela.registros.length
                  ? tabela.registros[i]
                  : const {},
            ),
      ],
      campos: tabela?.campos ?? const [],
      sistema: sistema,
    );
  }

  // o .dbf pode vir como .DBF (alguns programas gravam em maiúsculas)
  static File? _irmao(String base, String ext) {
    for (final e in [ext, ext.toUpperCase()]) {
      final f = File('$base.$e');
      if (f.existsSync()) return f;
    }
    return null;
  }

  /// As geometrias do .shp, na ordem dos registros (null = registro vazio).
  static List<({int tipo, List<List<XY>> aneis})?> lerShp(Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    if (bytes.length < 100 || d.getInt32(0, Endian.big) != 9994) {
      throw const FormatException('não é um .shp (código de arquivo != 9994)');
    }
    final fim =
        d.getInt32(24, Endian.big) * 2; // o tamanho vem em palavras de 16 bits
    final saida = <({int tipo, List<List<XY>> aneis})?>[];
    var p = 100;
    while (p + 8 <= fim && p + 8 <= bytes.length) {
      final tamanho = d.getInt32(p + 4, Endian.big) * 2;
      final c = p + 8; // o conteúdo do registro
      p = c + tamanho;
      final tipo = d.getInt32(c, Endian.little);
      switch (tipo) {
        case 0:
          saida.add(null);
        case 1 || 11 || 21:
          saida.add((
            tipo: 1,
            aneis: [
              [
                (
                  x: d.getFloat64(c + 4, Endian.little),
                  y: d.getFloat64(c + 12, Endian.little),
                ),
              ],
            ],
          ));
        case 3 || 5 || 13 || 15 || 23 || 25:
          // caixa (4 doubles), número de partes e de pontos, o início de cada parte, os pontos
          final partes = d.getInt32(c + 36, Endian.little);
          final pontos = d.getInt32(c + 40, Endian.little);
          final inicioPontos = c + 44 + 4 * partes;
          final inicios = [
            for (var i = 0; i < partes; i++)
              d.getInt32(c + 44 + 4 * i, Endian.little),
          ];
          final aneis = <List<XY>>[];
          for (var i = 0; i < partes; i++) {
            final de = inicios[i],
                ate = i + 1 < partes ? inicios[i + 1] : pontos;
            aneis.add([
              for (var k = de; k < ate; k++)
                (
                  x: d.getFloat64(inicioPontos + 16 * k, Endian.little),
                  y: d.getFloat64(inicioPontos + 16 * k + 8, Endian.little),
                ),
            ]);
          }
          saida.add((tipo: tipo % 10 == 5 ? 5 : 3, aneis: aneis));
        default:
          throw FormatException('tipo de geometria $tipo não suportado');
      }
    }
    return saida;
  }

  /// A tabela do .dbf: os campos e um mapa campo -> valor (número ou texto) por geometria.
  static ({List<Campo> campos, List<Map<String, Object?>> registros}) lerDbf(
    Uint8List bytes,
  ) {
    final d = ByteData.sublistView(bytes);
    final registros = d.getUint32(4, Endian.little);
    final cabecalho = d.getUint16(8, Endian.little);
    final tamanhoRegistro = d.getUint16(10, Endian.little);
    final campos = <Campo>[];
    for (var p = 32; p + 32 <= cabecalho && bytes[p] != 0x0D; p += 32) {
      final nome = latin1.decode(
        bytes.sublist(p, p + 11).takeWhile((b) => b != 0).toList(),
      );
      campos.add((
        nome: nome.trim(),
        tipo: String.fromCharCode(bytes[p + 11]),
        tamanho: bytes[p + 16],
        decimais: bytes[p + 17],
      ));
    }
    final saida = <Map<String, Object?>>[];
    for (var r = 0; r < registros; r++) {
      var p =
          cabecalho +
          r * tamanhoRegistro +
          1; // o 1º byte marca registro apagado
      final linha = <String, Object?>{};
      for (final c in campos) {
        final texto = latin1.decode(bytes.sublist(p, p + c.tamanho)).trim();
        p += c.tamanho;
        linha[c.nome] = (c.tipo == 'N' || c.tipo == 'F')
            ? num.tryParse(texto.replaceAll(',', '.'))
            : texto;
      }
      saida.add(linha);
    }
    return (campos: campos, registros: saida);
  }

  /// O .prj de coordenadas geográficas WGS84 (o que gravamos).
  static const prjWgs84 =
      'GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],'
      'PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]]';

  /// Grava polígonos (em graus) com atributos: base.shp, .shx, .dbf, .prj e .cpg.
  /// Cada polígono é uma lista de anéis; o anel externo vai no sentido horário.
  static void gravarPoligonos(
    String base,
    List<List<List<XY>>> poligonos,
    List<Campo> campos,
    List<List<Object?>> registros,
  ) {
    final conteudos = <Uint8List>[];
    var minX = double.infinity,
        minY = double.infinity,
        maxX = -double.infinity,
        maxY = -double.infinity;
    for (final poligono in poligonos) {
      // cada anel fechado (o último ponto repete o primeiro)
      final aneis = [
        for (final a in poligono) a.first == a.last ? a : [...a, a.first],
      ];
      final pontos = aneis.fold<int>(0, (s, a) => s + a.length);
      final b = ByteData(44 + 4 * aneis.length + 16 * pontos);
      final xs = aneis.expand((a) => a.map((p) => p.x)),
          ys = aneis.expand((a) => a.map((p) => p.y));
      final caixa = [
        xs.reduce(math.min),
        ys.reduce(math.min),
        xs.reduce(math.max),
        ys.reduce(math.max),
      ];
      minX = math.min(minX, caixa[0]);
      minY = math.min(minY, caixa[1]);
      maxX = math.max(maxX, caixa[2]);
      maxY = math.max(maxY, caixa[3]);
      b.setInt32(0, 5, Endian.little);
      for (var i = 0; i < 4; i++) {
        b.setFloat64(4 + 8 * i, caixa[i], Endian.little);
      }
      b.setInt32(36, aneis.length, Endian.little);
      b.setInt32(40, pontos, Endian.little);
      var k = 0, off = 44 + 4 * aneis.length;
      for (var i = 0; i < aneis.length; i++) {
        b.setInt32(44 + 4 * i, k, Endian.little);
        for (final p in aneis[i]) {
          b.setFloat64(off, p.x, Endian.little);
          b.setFloat64(off + 8, p.y, Endian.little);
          off += 16;
          k++;
        }
      }
      conteudos.add(b.buffer.asUint8List());
    }

    Uint8List cabecalho(int tamanhoBytes) {
      final c = ByteData(100);
      c.setInt32(0, 9994, Endian.big);
      c.setInt32(24, tamanhoBytes ~/ 2, Endian.big);
      c.setInt32(28, 1000, Endian.little);
      c.setInt32(32, 5, Endian.little);
      for (final (i, v) in [minX, minY, maxX, maxY].indexed) {
        c.setFloat64(36 + 8 * i, poligonos.isEmpty ? 0 : v, Endian.little);
      }
      return c.buffer.asUint8List();
    }

    final shp = BytesBuilder(), shx = BytesBuilder();
    var posicao = 50; // em palavras de 16 bits, depois do cabeçalho
    for (final (i, c) in conteudos.indexed) {
      final r = ByteData(8)
        ..setInt32(0, i + 1, Endian.big)
        ..setInt32(4, c.length ~/ 2, Endian.big);
      shp
        ..add(r.buffer.asUint8List())
        ..add(c);
      shx.add(
        (ByteData(8)
              ..setInt32(0, posicao, Endian.big)
              ..setInt32(4, c.length ~/ 2, Endian.big))
            .buffer
            .asUint8List(),
      );
      posicao += 4 + c.length ~/ 2;
    }
    File(
      '$base.shp',
    ).writeAsBytesSync([...cabecalho(100 + shp.length), ...shp.takeBytes()]);
    File(
      '$base.shx',
    ).writeAsBytesSync([...cabecalho(100 + shx.length), ...shx.takeBytes()]);

    // .dbf (dBASE III): cabeçalho, um descritor de 32 bytes por campo, 0x0D, registros, 0x1A
    final tamanhoRegistro = 1 + campos.fold<int>(0, (s, c) => s + c.tamanho);
    final agora = DateTime.now();
    final dbf = BytesBuilder();
    final cab = ByteData(32)
      ..setUint8(0, 3)
      ..setUint8(1, agora.year - 1900)
      ..setUint8(2, agora.month)
      ..setUint8(3, agora.day)
      ..setUint32(4, registros.length, Endian.little)
      ..setUint16(8, 32 + 32 * campos.length + 1, Endian.little)
      ..setUint16(10, tamanhoRegistro, Endian.little);
    dbf.add(cab.buffer.asUint8List());
    for (final c in campos) {
      final d = Uint8List(32);
      final nome = latin1.encode(
        c.nome.length > 10 ? c.nome.substring(0, 10) : c.nome,
      );
      d.setRange(0, nome.length, nome);
      d[11] = c.tipo.codeUnitAt(0);
      d[16] = c.tamanho;
      d[17] = c.decimais;
      dbf.add(d);
    }
    dbf.addByte(0x0D);
    for (final r in registros) {
      dbf.addByte(0x20); // registro válido
      for (final (i, c) in campos.indexed) {
        final v = r[i];
        final texto = v == null
            ? ''
            : (c.tipo == 'N' || c.tipo == 'F') && v is num
            ? (c.decimais > 0
                      ? v.toStringAsFixed(c.decimais)
                      : v.round().toString())
                  .padLeft(c.tamanho)
            : v.toString().padRight(c.tamanho);
        dbf.add(
          latin1.encode(
            texto.length > c.tamanho ? texto.substring(0, c.tamanho) : texto,
          ),
        );
      }
    }
    dbf.addByte(0x1A);
    File('$base.dbf').writeAsBytesSync(dbf.takeBytes());
    File('$base.prj').writeAsStringSync(prjWgs84);
    File('$base.cpg').writeAsStringSync('ISO-8859-1');
  }
}

/// A projeção Transversa de Mercator (a UTM é uma delas), num elipsoide: as fórmulas do
/// "Map Projections — A Working Manual" (Snyder, 1987, p. 60–64). Precisão de milímetros
/// dentro de uma zona UTM.
class TransversaDeMercator {
  TransversaDeMercator({
    required this.a,
    required this.f,
    required this.meridianoCentral,
    this.latitudeOrigem = 0,
    this.escala = 0.9996,
    this.falsoLeste = 500000,
    this.falsoNorte = 0,
  });

  final double a, f; // semieixo maior (m) e achatamento
  final double meridianoCentral, latitudeOrigem; // graus
  final double escala, falsoLeste, falsoNorte;

  /// Do texto WKT do .prj: o elipsoide e os parâmetros da projeção.
  factory TransversaDeMercator.doPrj(String prj) {
    if (!RegExp('Transverse_Mercator', caseSensitive: false).hasMatch(prj)) {
      final nome =
          RegExp(r'PROJECTION\["([^"]+)"').firstMatch(prj)?.group(1) ?? '?';
      throw FormatException(
        'projeção "$nome" não suportada: exporte em graus (EPSG:4326/4674) ou em UTM',
      );
    }
    final parametros = <String, double>{
      for (final m in RegExp(
        r'PARAMETER\["([^"]+)",\s*([-0-9.eE+]+)\]',
      ).allMatches(prj))
        m.group(1)!.toLowerCase(): double.parse(m.group(2)!),
    };
    final elipsoide = RegExp(
      r'SPHEROID\["[^"]*",\s*([0-9.eE+]+),\s*([0-9.eE+]+)',
    ).firstMatch(prj);
    final inverso = elipsoide == null
        ? 298.257222101
        : double.parse(elipsoide.group(2)!);
    return TransversaDeMercator(
      a: elipsoide == null ? 6378137 : double.parse(elipsoide.group(1)!),
      f: inverso == 0 ? 0 : 1 / inverso,
      meridianoCentral:
          parametros['central_meridian'] ??
          parametros['longitude_of_origin'] ??
          0,
      latitudeOrigem: parametros['latitude_of_origin'] ?? 0,
      escala: parametros['scale_factor'] ?? 0.9996,
      falsoLeste: parametros['false_easting'] ?? 500000,
      falsoNorte: parametros['false_northing'] ?? 0,
    );
  }

  double get _e2 => f * (2 - f);

  // o comprimento do meridiano do equador até a latitude phi (radianos)
  double _m(double phi) {
    final e2 = _e2, e4 = e2 * e2, e6 = e4 * e2;
    return a *
        ((1 - e2 / 4 - 3 * e4 / 64 - 5 * e6 / 256) * phi -
            (3 * e2 / 8 + 3 * e4 / 32 + 45 * e6 / 1024) * math.sin(2 * phi) +
            (15 * e4 / 256 + 45 * e6 / 1024) * math.sin(4 * phi) -
            (35 * e6 / 3072) * math.sin(6 * phi));
  }

  /// Metros (leste = x, norte = y) -> graus (x = longitude, y = latitude).
  XY paraGraus(XY p) {
    final e2 = _e2, ep2 = e2 / (1 - e2);
    final m = _m(latitudeOrigem * math.pi / 180) + (p.y - falsoNorte) / escala;
    final mu =
        m / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));
    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final phi1 =
        mu +
        (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) * math.sin(4 * mu) +
        (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
        (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);
    final s = math.sin(phi1), c = math.cos(phi1), t = math.tan(phi1);
    final c1 = ep2 * c * c, t1 = t * t;
    final n1 = a / math.sqrt(1 - e2 * s * s);
    final r1 = a * (1 - e2) / math.pow(1 - e2 * s * s, 1.5);
    final d = (p.x - falsoLeste) / (n1 * escala);
    final lat =
        phi1 -
        (n1 * t / r1) *
            (d * d / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ep2) *
                    math.pow(d, 4) /
                    24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * t1 * t1 -
                        252 * ep2 -
                        3 * c1 * c1) *
                    math.pow(d, 6) /
                    720);
    final lon =
        (d -
            (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 +
            (5 - 2 * c1 + 28 * t1 - 3 * c1 * c1 + 8 * ep2 + 24 * t1 * t1) *
                math.pow(d, 5) /
                120) /
        c;
    return (x: meridianoCentral + lon * 180 / math.pi, y: lat * 180 / math.pi);
  }
}
