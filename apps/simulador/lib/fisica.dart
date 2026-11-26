// fisica.dart — o trator dirigível: motor, câmbio, freio e direção
//
// Modelo de bicicleta pelo eixo traseiro (o que um trator é, na prática): o rumo muda
// com velocidade / entre-eixos × tan(esterço). A antena do GPS fica no meio do trator.
import 'dart:math' as math;

class FisicaTrator {
  // ponytail: valores de um trator médio (~150 cv); ajuste aqui se quiser outro trator
  static const entreEixos = 2.3; // m
  static const antenaAFrenteDoEixo = 0.8; // m, do eixo traseiro até a antena
  static const estercoMaximo = 38.0; // graus nas rodas
  static const voltasDoVolante =
      1.5; // para cada lado (batente a batente = 3 voltas)
  static const velocidadeMaximaFrente = 18 / 3.6; // m/s
  static const velocidadeMaximaRe = 7 / 3.6;
  static const aceleracaoMaxima = 1.2; // m/s², com o motor no máximo
  static const desaceleracaoFreio = 4.0; // m/s²
  static const rpmMarchaLenta = 850.0, rpmMaxima = 2200.0;

  // a pose: a antena (leste, norte, em metros) e o rumo em graus (0 = norte, horário)
  double e, n, rumo;
  FisicaTrator({this.e = 4.6, this.n = -14, this.rumo = 0});

  double velocidade = 0; // m/s, negativa de ré
  double rpm = rpmMarchaLenta;

  // os comandos
  double volante =
      0; // graus no volante: -540 (tudo à esquerda) a 540 (tudo à direita)
  double aceleradorDeMao =
      0; // 0 a 1: a alavanca do trator, fica onde você deixou
  double pedal = 0; // 0 a 1: o pedal, volta sozinho
  double freio = 0; // 0 a 1
  bool re = false;

  /// O esterço das rodas dianteiras, em graus (positivo = direita).
  double get esterco =>
      volante.clamp(-360 * voltasDoVolante, 360 * voltasDoVolante) /
      (360 * voltasDoVolante) *
      estercoMaximo;

  /// Leva o trator (parado) para outro lugar: a entrada de um talhão novo.
  void reposicionar(double e, double n, double rumo) {
    this.e = e;
    this.n = n;
    this.rumo = rumo % 360;
    velocidade = 0;
    volante = 0;
  }

  /// Troca frente/ré: o câmbio só engata com o trator (quase) parado.
  bool trocarSentido() {
    if (velocidade.abs() > 0.3) return false;
    re = !re;
    return true;
  }

  void passo(double dt) {
    if (dt <= 0) return;
    dt = math.min(dt, 0.05); // um quadro travado não vira um salto

    // o motor: o acelerador pede rotação, o motor sobe e desce com inércia
    final acelerador = math.max(aceleradorDeMao, pedal);
    final rpmAlvo = rpmMarchaLenta + (rpmMaxima - rpmMarchaLenta) * acelerador;
    rpm += (rpmAlvo - rpm) * (1 - math.exp(-dt * 2.5));

    // a tração: proporcional ao quanto o motor passou da lenta, até a velocidade máxima
    final maxima = re ? velocidadeMaximaRe : velocidadeMaximaFrente;
    var carga = (rpm - rpmMarchaLenta) / (rpmMaxima - rpmMarchaLenta);
    if (carga < 0.02) carga = 0; // na lenta, o trator não puxa
    final sentido = re ? -1.0 : 1.0;
    final alvo = sentido * maxima * carga;
    var tracao = 0.0;
    if ((alvo - velocidade) * sentido > 0) {
      // pisar no freio também tira a tração (como a embreagem)
      tracao = sentido * aceleracaoMaxima * (0.3 + 0.7 * carga) * (1 - freio);
    }
    // resistência do solo (terra solta segura bastante) e o freio, sempre contra o movimento
    final contra =
        0.35 + 0.01 * velocidade * velocidade + desaceleracaoFreio * freio;
    final antes = velocidade;
    velocidade += (tracao - velocidade.sign * contra) * dt;
    // sem tração, a resistência PARA o trator; não o põe andando para o outro lado
    if (tracao == 0 &&
        (velocidade.sign != antes.sign || velocidade.abs() < 0.05)) {
      velocidade = 0;
    }
    velocidade = velocidade.clamp(-velocidadeMaximaRe, velocidadeMaximaFrente);

    // a direção: modelo de bicicleta pelo eixo traseiro
    final h = rumo * math.pi / 180;
    var eixoE = e - math.sin(h) * antenaAFrenteDoEixo;
    var eixoN = n - math.cos(h) * antenaAFrenteDoEixo;
    final giro =
        velocidade / entreEixos * math.tan(esterco * math.pi / 180); // rad/s
    final novoH = h + giro * dt;
    eixoE += math.sin(novoH) * velocidade * dt;
    eixoN += math.cos(novoH) * velocidade * dt;
    rumo = (novoH * 180 / math.pi) % 360;
    e = eixoE + math.sin(novoH) * antenaAFrenteDoEixo;
    n = eixoN + math.cos(novoH) * antenaAFrenteDoEixo;
  }
}

/// Autoteste: `dart run lib/fisica.dart` (de dentro de simulador/).
void main() {
  // acelerador cheio e volante reto: anda para o norte e chega perto dos 18 km/h
  final t = FisicaTrator(e: 0, n: 0)..aceleradorDeMao = 1;
  for (var i = 0; i < 30 * 60; i++) {
    t.passo(1 / 60);
  }
  assert(
    (t.velocidade * 3.6 - 18).abs() < 1,
    'velocidade ${t.velocidade * 3.6}',
  );
  assert(t.e.abs() < 1e-6 && t.n > 50, 'andou reto para o norte');

  // volante todo à direita: gira no sentido horário (rumo cresce)
  t.volante = 540;
  for (var i = 0; i < 60; i++) {
    t.passo(1 / 60);
  }
  assert(t.rumo > 5 && t.rumo < 180, 'virou à direita: ${t.rumo}');

  // solta tudo e freia: para, e não sai andando de ré
  t
    ..aceleradorDeMao = 0
    ..freio = 1;
  for (var i = 0; i < 10 * 60; i++) {
    t.passo(1 / 60);
  }
  assert(t.velocidade == 0, 'parou: ${t.velocidade}');

  // de ré: velocidade negativa, limitada a 7 km/h
  t
    ..freio = 0
    ..trocarSentido()
    ..aceleradorDeMao = 1;
  for (var i = 0; i < 20 * 60; i++) {
    t.passo(1 / 60);
  }
  assert(
    t.velocidade < 0 && t.velocidade * 3.6 > -7.1,
    'ré: ${t.velocidade * 3.6}',
  );
  // ignore: avoid_print
  print(
    'física ok: ${(t.velocidade * 3.6).toStringAsFixed(1)} km/h de ré, rumo ${t.rumo.toStringAsFixed(0)}°',
  );
}
