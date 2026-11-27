// geo.dart — o talhão, o mapa de aplicação e o TC automático (TC-GEO e TC-SEC)
//
// A cada posição do GPS (NMEA 2000), o TC:
//   1. acha em que zona do mapa de prescrição a barra está e manda a taxa dela (DDI 11);
//   2. liga cada seção só se ela estiver DENTRO do talhão e FORA do que já foi plantado;
//   3. grava no mapa de aplicação o que as seções ligadas DE VERDADE (DDI 161)
//      cobriram, com a taxa que a plantadeira informou (DDI 11).
import 'dart:math' as math;
import 'dart:typed_data';

import 'agiso.dart';

/// Um ponto em metros: leste e norte a partir da origem do talhão.
typedef Ponto = ({double e, double n});

/// Um ponto em graus.
typedef PontoGeo = ({double lon, double lat});

/// Um polígono: o anel externo e os buracos (par-ou-ímpar decide o que é dentro).
typedef Poligono = List<List<Ponto>>;

class Zona {
  Zona(this.poligono, this.taxa);
  final Poligono poligono;
  final int taxa; // sementes/ha
}

/// O talhão: o contorno e o mapa de prescrição (zonas com taxa), em metros a partir
/// do canto sudoeste. Vem do banco, ou é o retângulo padrão da demo.
class Talhao {
  Talhao._(
    this.nome,
    this.lat0,
    this.lon0,
    this.contorno,
    this.zonas,
    this.taxaPadrao,
    this.geo,
  );

  final String nome;
  final double lat0, lon0; // a origem (canto sudoeste)
  final List<Poligono>
  contorno; // a área do talhão: dentro de QUALQUER um destes
  final List<Zona> zonas;
  final int taxaPadrao; // a taxa onde nenhuma zona cobre

  /// A versão em graus, para guardar no banco (contorno e zonas).
  final ({
    List<List<List<PontoGeo>>> contorno,
    List<({List<List<PontoGeo>> aneis, int taxa})> zonas,
  })
  geo;

  static const _metrosPorGrau = 111320.0;

  /// A partir de polígonos em graus. A origem é o canto sudoeste, se não vier dada.
  factory Talhao.deGeo({
    required String nome,
    required List<List<List<PontoGeo>>> contorno,
    List<({List<List<PontoGeo>> aneis, int taxa})> zonas = const [],
    int taxaPadrao = 16000,
    PontoGeo? origem,
  }) {
    final todos = [
      for (final p in contorno)
        for (final a in p) ...a,
    ];
    if (todos.isEmpty) throw const FormatException('o talhão não tem contorno');
    final lat0 = origem?.lat ?? todos.map((p) => p.lat).reduce(math.min);
    final lon0 = origem?.lon ?? todos.map((p) => p.lon).reduce(math.min);
    final cosLat = math.cos(lat0 * math.pi / 180);
    Ponto local(PontoGeo p) => (
      e: (p.lon - lon0) * _metrosPorGrau * cosLat,
      n: (p.lat - lat0) * _metrosPorGrau,
    );
    Poligono metros(List<List<PontoGeo>> aneis) => [
      for (final a in aneis) [for (final p in a) local(p)],
    ];
    return Talhao._(
      nome,
      lat0,
      lon0,
      [for (final p in contorno) metros(p)],
      [for (final z in zonas) Zona(metros(z.aneis), z.taxa)],
      taxaPadrao,
      (contorno: contorno, zonas: zonas),
    );
  }

  /// O talhão da demo: 60 x 120 m em Sinop (MT), três faixas de prescrição de sul a
  /// norte. É o mesmo que o ./build/trator percorre (simuladores/trator.cpp).
  factory Talhao.padrao() {
    const lat0 = -11.8640, lon0 = -55.5050;
    final cosLat = math.cos(lat0 * math.pi / 180);
    PontoGeo g(double e, double n) => (
      lon: lon0 + e / (_metrosPorGrau * cosLat),
      lat: lat0 + n / _metrosPorGrau,
    );
    List<List<PontoGeo>> retangulo(double n0, double n1) => [
      [g(0, n0), g(60, n0), g(60, n1), g(0, n1)],
    ];
    return Talhao.deGeo(
      nome: 'Demo Sinop 60 x 120 m',
      contorno: [retangulo(0, 120)],
      zonas: [
        (aneis: retangulo(0, 40), taxa: 12000),
        (aneis: retangulo(40, 80), taxa: 20000),
        (aneis: retangulo(80, 120), taxa: 16000),
      ],
      origem: (lon: lon0, lat: lat0),
    );
  }

  /// Graus -> metros (leste, norte) a partir da origem.
  Ponto local(double lat, double lon) => (
    e: (lon - lon0) * _metrosPorGrau * math.cos(lat0 * math.pi / 180),
    n: (lat - lat0) * _metrosPorGrau,
  );

  /// Metros (leste, norte) -> graus: o inverso de [local].
  ({double lat, double lon}) graus(double e, double n) => (
    lat: lat0 + n / _metrosPorGrau,
    lon: lon0 + e / (_metrosPorGrau * math.cos(lat0 * math.pi / 180)),
  );

  bool dentro(double e, double n) => contorno.any((p) => dentroDe(p, e, n));

  /// A taxa da zona (null fora do talhão).
  int? taxa(double e, double n) {
    if (!dentro(e, n)) return null;
    for (final z in zonas) {
      if (dentroDe(z.poligono, e, n)) return z.taxa;
    }
    return taxaPadrao;
  }

  /// Par-ou-ímpar: um raio para leste cruza a borda um número ímpar de vezes?
  static bool dentroDe(Poligono p, double e, double n) {
    var dentro = false;
    for (final anel in p) {
      for (var i = 0, j = anel.length - 1; i < anel.length; j = i++) {
        final a = anel[i], b = anel[j];
        if ((a.n > n) != (b.n > n) &&
            e < (b.e - a.e) * (n - a.n) / (b.n - a.n) + a.e) {
          dentro = !dentro;
        }
      }
    }
    return dentro;
  }

  /// A caixa que contém o talhão.
  ({double minE, double minN, double maxE, double maxN}) get limites {
    final todos = [
      for (final p in contorno)
        for (final a in p) ...a,
    ];
    return (
      minE: todos.map((p) => p.e).reduce(math.min),
      minN: todos.map((p) => p.n).reduce(math.min),
      maxE: todos.map((p) => p.e).reduce(math.max),
      maxN: todos.map((p) => p.n).reduce(math.max),
    );
  }
}

/// A barra da plantadeira: 9,144 m em 6 seções, 5 m atrás da antena do GPS.
class Barra {
  static const largura = 9.144, secoes = 6, recuo = 5.0;
  static const larguraSecao = largura / secoes;

  /// Deslocamento lateral do centro da seção i (positivo = à direita, como no DDOP).
  static double lateral(int i) => -largura / 2 + larguraSecao * (i + 0.5);

  /// Um ponto da barra: [lado] metros à direita do centro, [adiante] metros à frente.
  /// (e, n, rumo) é a pose da BARRA (veja [Engate]), não a do trator.
  static Ponto ponto(
    double e,
    double n,
    double rumoGraus, {
    double lado = 0,
    double adiante = 0,
  }) {
    final h = rumoGraus * math.pi / 180;
    return (
      e: e + math.sin(h) * adiante + math.cos(h) * lado,
      n: n + math.cos(h) * adiante - math.sin(h) * lado,
    );
  }

  /// O centro da seção i.
  static Ponto secao(
    double e,
    double n,
    double rumoGraus,
    int i, {
    double adiante = 0,
  }) => ponto(e, n, rumoGraus, lado: lateral(i), adiante: adiante);
}

/// A plantadeira é REBOCADA: gira em torno do pino do engate, como de verdade. Nas
/// curvas a barra corta por dentro do caminho do trator; em reta fica a [Barra.recuo] m.
class Engate {
  static const antenaAoEngate =
      2.2; // da antena (meio do trator) ao pino do engate
  static const engateABarra = Barra.recuo - antenaAoEngate; // do pino às linhas

  Ponto? _barra;

  /// A pose da barra (centro das linhas e rumo) depois que o trator chegou em (e, n, rumo).
  ({double e, double n, double rumo}) seguir(
    double e,
    double n,
    double rumoGraus,
  ) {
    final h = rumoGraus * math.pi / 180;
    final pino = (
      e: e - math.sin(h) * antenaAoEngate,
      n: n - math.cos(h) * antenaAoEngate,
    );
    var b = _barra;
    // primeira posição, ou o trator "pulou" (recomeçou o talhão): barra alinhada atrás
    if (b == null ||
        math.sqrt(math.pow(pino.e - b.e, 2) + math.pow(pino.n - b.n, 2)) >
            engateABarra * 1.5) {
      b = (
        e: pino.e - math.sin(h) * engateABarra,
        n: pino.n - math.cos(h) * engateABarra,
      );
    }
    // a barra é puxada pelo pino: fica na reta pino-barra, à distância do cabeçalho
    final de = pino.e - b.e, dn = pino.n - b.n;
    final d = math.max(1e-6, math.sqrt(de * de + dn * dn));
    _barra = (
      e: pino.e - de / d * engateABarra,
      n: pino.n - dn / d * engateABarra,
    );
    return (
      e: _barra!.e,
      n: _barra!.n,
      rumo: math.atan2(de, dn) * 180 / math.pi,
    );
  }
}

/// O mapa de aplicação: uma grade sobre o talhão; cada célula guarda a taxa que caiu
/// nela (0 = nada plantado). É a cobertura do TC-SEC, o "as-applied" que vai para o
/// banco e a textura do chão no 3D — tudo o mesmo buffer.
class MapaAplicacao {
  MapaAplicacao._(
    this.origemE,
    this.origemN,
    this.celula,
    this.largura,
    this.altura,
    this.dados,
    Uint8List? sobrepostas,
  ) : sobrepostas = sobrepostas ?? Uint8List(dados.length),
      _quando = Uint32List(dados.length) {
    for (var i = 0; i < dados.length; i++) {
      if (dados[i] == 0) continue;
      plantadas++;
      sementes += taxaDe(dados[i]) * celula * celula / 10000;
      if (this.sobrepostas[i] != 0) {
        sobrepostasN++;
        sementes +=
            taxaDe(dados[i]) * celula * celula / 10000; // semente em dobro
      }
    }
  }

  /// Uma grade vazia cobrindo o talhão (com margem para as manobras).
  factory MapaAplicacao.para(Talhao t, {double margem = 20}) {
    final l = t.limites;
    final w = l.maxE - l.minE + 2 * margem, h = l.maxN - l.minN + 2 * margem;
    // células de 0,5 m; num talhão enorme, maiores, para a grade caber numa textura 4096²
    final celula = math.max(0.5, math.max(w, h) / 4096);
    final largura = (w / celula).ceil(), altura = (h / celula).ceil();
    return MapaAplicacao._(
      l.minE - margem,
      l.minN - margem,
      celula,
      largura,
      altura,
      Uint8List(largura * altura),
      null,
    );
  }

  /// Uma grade guardada (do banco).
  factory MapaAplicacao.de({
    required double origemE,
    required double origemN,
    required double celula,
    required int largura,
    required int altura,
    required Uint8List dados,
    Uint8List? sobrepostas,
  }) => MapaAplicacao._(
    origemE,
    origemN,
    celula,
    largura,
    altura,
    dados,
    sobrepostas,
  );

  final double origemE, origemN, celula;
  final int largura, altura;
  final Uint8List dados; // linha a linha, de sul para norte; valor = taxa / 250

  /// 1 onde a plantadeira passou de novo (semente em dobro).
  final Uint8List sobrepostas;

  // quando (em décimos de segundo do relógio do GPS) cada célula foi plantada: passar
  // de novo na mesma célula logo depois é a mesma passada, não sobreposição.
  // ponytail: 4 bytes por célula; num talhão de 4096² células, 64 MB
  final Uint32List _quando;
  static const _mesmaPassada = 30; // 3 s

  int plantadas = 0, sobrepostasN = 0;
  double sementes = 0;

  static int codigo(int taxa) => (taxa / 250).round().clamp(1, 255);
  static int taxaDe(int codigo) => codigo * 250;

  double get hectares => plantadas * celula * celula / 10000;
  double get hectaresSobrepostos => sobrepostasN * celula * celula / 10000;

  int? indice(double e, double n) {
    final x = ((e - origemE) / celula).floor(),
        y = ((n - origemN) / celula).floor();
    if (x < 0 || y < 0 || x >= largura || y >= altura) return null;
    return y * largura + x;
  }

  /// O centro da célula i, em metros.
  Ponto centro(int i) => (
    e: origemE + (i % largura + 0.5) * celula,
    n: origemN + (i ~/ largura + 0.5) * celula,
  );

  bool coberto(double e, double n) {
    final i = indice(e, n);
    return i != null && dados[i] != 0;
  }

  /// Grava a taxa na célula. Devolve o índice se ela mudou: plantada agora, ou
  /// plantada de novo numa passada posterior ([agora] = décimos de segundo).
  int? marcar(double e, double n, int taxa, {int agora = 0}) {
    final i = indice(e, n);
    if (i == null) return null;
    if (dados[i] != 0) {
      if (sobrepostas[i] != 0 || agora - _quando[i] <= _mesmaPassada)
        return null;
      sobrepostas[i] = 1;
      sobrepostasN++;
      sementes += taxaDe(dados[i]) * celula * celula / 10000;
      return i;
    }
    dados[i] = codigo(taxa);
    _quando[i] = agora;
    plantadas++;
    sementes += taxaDe(dados[i]) * celula * celula / 10000;
    return i;
  }

  void limpar() {
    dados.fillRange(0, dados.length, 0);
    sobrepostas.fillRange(0, sobrepostas.length, 0);
    plantadas = 0;
    sobrepostasN = 0;
    sementes = 0;
  }
}

class TcAutomatico {
  TcAutomatico(this.agiso, {Talhao? talhao})
    : _talhao = talhao ?? Talhao.padrao() {
    mapa = MapaAplicacao.para(_talhao);
    agiso.eventos.listen(_aoEvento);
  }

  final Agiso agiso;
  bool ligado = false;

  Talhao _talhao;
  Talhao get talhao => _talhao;

  /// Troca o talhão (e começa um mapa de aplicação novo, ou o [mapa] dado).
  void trocarTalhao(Talhao t, {MapaAplicacao? mapa}) {
    _talhao = t;
    this.mapa = mapa ?? MapaAplicacao.para(t);
    taxaMandada = null;
    _anterior = null;
    aoTrocar?.call();
    aoMudar?.call();
  }

  late MapaAplicacao mapa;

  /// Para a tela: última posição do trator e da barra, zona e taxa mandada, seções pedidas.
  ({double e, double n, double rumo})? posicao;
  ({double e, double n, double rumo})? barra;
  final _engate = Engate();
  int? taxaMandada;
  int _taxaReal =
      12000; // a que a plantadeira informa (DDI 11): é a que vai para o mapa
  List<bool> pedidas = List.filled(Barra.secoes, false);
  List<bool> _reais = List.filled(Barra.secoes, false);
  ({double e, double n, double rumo})? _anterior; // a barra na posição anterior
  double distancia = 0; // metros andados pelo trator
  int _relogio = 0; // décimos de segundo: o GPS chega 10 vezes por segundo

  void Function()? aoMudar; // a tela se redesenha
  void Function()? aoTrocar; // talhão (ou mapa) novo: a tela refaz tudo

  /// Cada célula nova plantada (índice na grade do [mapa]): o 3D pinta a textura.
  void Function(int indice)? aoPlantar;

  bool coberto(double e, double n) => mapa.coberto(e, n);

  void limpar() {
    mapa.limpar();
    aoTrocar?.call();
    aoMudar?.call();
  }

  void _aoEvento(Evento evento) {
    if (evento is Secoes) _reais = evento.ligadas;
    if (evento is Taxa) _taxaReal = evento.sementesPorHa;
    if (evento is Gps) aoGps(evento);
  }

  /// Uma posição nova do trator. Chega sozinha pela rede; o simulador dirigível, que
  /// é o próprio trator (não recebe o que manda), chama direto.
  void aoGps(Gps gps) {
    _relogio++;
    final p = _talhao.local(gps.lat, gps.lon);
    if (posicao != null) {
      distancia += math.sqrt(
        math.pow(p.e - posicao!.e, 2) + math.pow(p.n - posicao!.n, 2),
      );
    }
    posicao = (e: p.e, n: p.n, rumo: gps.rumo);
    final b = _engate.seguir(p.e, p.n, gps.rumo);
    barra = b;

    // 3. o que as seções ligadas de verdade plantaram desde a última posição
    final antes = _anterior ?? b;
    _anterior = b;
    _marcar(antes, b);

    if (ligado) {
      // 1. TC-GEO: a taxa da zona onde está o centro da barra
      final taxa = _talhao.taxa(b.e, b.n);
      if (taxa != null && taxa != taxaMandada) {
        taxaMandada = taxa;
        agiso.definirNoTc(3, 11, taxa);
      }

      // 2. TC-SEC: cada seção, 1 m adiante, dentro do talhão e sem plantio
      final novas = [
        for (var i = 0; i < Barra.secoes; i++)
          () {
            final s = Barra.secao(b.e, b.n, b.rumo, i, adiante: 1);
            return _talhao.dentro(s.e, s.n) && !coberto(s.e, s.n);
          }(),
      ];
      if (!_iguais(novas, pedidas)) {
        pedidas = novas;
        var setpoint = 0; // 2 bits por seção, 01 = liga
        for (var i = 0; i < novas.length; i++) {
          if (novas[i]) setpoint |= 1 << (2 * i);
        }
        agiso.definirNoTc(2, 160, 1); // automático
        agiso.definirNoTc(2, 290, setpoint);
      }
    }
    aoMudar?.call();
  }

  // Grava as células cobertas pelas seções ligadas no trecho entre duas poses da barra
  void _marcar(
    ({double e, double n, double rumo}) de,
    ({double e, double n, double rumo}) ate,
  ) {
    final rumo = ate.rumo;
    final passoGrade = mapa.celula / 2; // amostra a cada meia célula: sem furos
    final passos = math.max(
      1,
      (math.sqrt(math.pow(ate.e - de.e, 2) + math.pow(ate.n - de.n, 2)) /
              passoGrade)
          .ceil(),
    );
    for (var k = 1; k <= passos; k++) {
      final e = de.e + (ate.e - de.e) * k / passos;
      final n = de.n + (ate.n - de.n) * k / passos;
      for (var i = 0; i < _reais.length && i < Barra.secoes; i++) {
        if (!_reais[i]) continue;
        for (
          var l = -Barra.larguraSecao / 2 + passoGrade / 2;
          l < Barra.larguraSecao / 2;
          l += passoGrade
        ) {
          final s = Barra.ponto(e, n, rumo, lado: Barra.lateral(i) + l);
          if (!_talhao.dentro(s.e, s.n)) continue;
          final novo = mapa.marcar(s.e, s.n, _taxaReal, agora: _relogio);
          if (novo != null) aoPlantar?.call(novo);
        }
      }
    }
  }

  static bool _iguais(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
