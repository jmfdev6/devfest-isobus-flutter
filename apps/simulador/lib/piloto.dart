// piloto.dart — o piloto automático elétrico: um motor no volante que segue a rota
//
// A rota (pacotes/agiso/lib/rota.dart) cobre o talhão: passadas paralelas à AB, curvas em U
// dentro da cabeceira e as voltas de cabeceira no fim. O piloto segue com "pure
// pursuit" pelo eixo traseiro: mira um ponto da rota um pouco à frente e esterça o que
// a geometria de bicicleta pede para passar por ele. Nas curvas, reduz a velocidade.
// Mexeu no volante ou deu ré: desengata (como o sensor de torque de verdade).
import 'dart:io';
import 'dart:math' as math;

import 'package:agiso/geo.dart';
import 'package:agiso/rota.dart';
import 'package:agiso/shapefile.dart';

import 'fisica.dart';

class PilotoAutomatico {
  PilotoAutomatico(this.rota);

  final Rota rota;
  bool ligado = false;
  bool concluido = false;
  int indice =
      0; // o segmento da rota em que o trator está (pontos[i] -> pontos[i+1])
  double erro = 0; // desvio lateral (m): positivo = trator à direita da rota

  // ponytail: o motor de um kit comum de volante elétrico; ajuste se o seu for mais lento
  static const velocidadeMotor = 300.0; // graus de volante por segundo
  static const velocidadeNaCurva = 6 / 3.6; // m/s
  static const distanciaParaEngatar = 15.0; // m

  String get trecho => rota.trechos[rota.pontos[indice].trecho];

  /// O meio do eixo traseiro: é por ele que o piloto guia.
  static Ponto eixo(FisicaTrator t) {
    final h = t.rumo * math.pi / 180;
    return (
      e: t.e - math.sin(h) * FisicaTrator.antenaAFrenteDoEixo,
      n: t.n - math.cos(h) * FisicaTrator.antenaAFrenteDoEixo,
    );
  }

  static double _rumo(PontoRota a, PontoRota b) =>
      math.atan2(b.e - a.e, b.n - a.n) * 180 / math.pi;
  static double _difRumo(double a, double b) =>
      ((a - b + 540) % 360 - 180).abs();

  /// Engata no ponto da rota mais perto que aponte para onde o trator anda.
  String? engatar(FisicaTrator t) {
    if (t.velocidade < -0.1) return 'o piloto não guia de ré';
    final p = rota.pontos;
    if (p.length < 2) return 'o talhão não tem rota';
    final r = eixo(t);
    var melhor = -1;
    var menor = double.infinity;
    for (var i = 0; i + 1 < p.length; i++) {
      if (_difRumo(_rumo(p[i], p[i + 1]), t.rumo) > 45) continue;
      final d = _distanciaAoSegmento(r, i).abs();
      if (d < menor) {
        menor = d;
        melhor = i;
      }
    }
    if (melhor < 0 || menor > distanciaParaEngatar) {
      return 'chegue perto da rota (laranja), alinhado com ela';
    }
    indice = melhor;
    ligado = true;
    concluido = false;
    return null;
  }

  void desligar() => ligado = false;

  // distância com sinal do ponto ao segmento i (positivo = à direita do sentido da rota)
  double _distanciaAoSegmento(Ponto r, int i) {
    final a = rota.pontos[i], b = rota.pontos[i + 1];
    final l = math.max(
      1e-9,
      math.sqrt(math.pow(b.e - a.e, 2) + math.pow(b.n - a.n, 2)),
    );
    final u = (e: (b.e - a.e) / l, n: (b.n - a.n) / l);
    final t = ((r.e - a.e) * u.e + (r.n - a.n) * u.n).clamp(0.0, l);
    final pe = (e: a.e + u.e * t, n: a.n + u.n * t);
    final dist = math.sqrt(math.pow(r.e - pe.e, 2) + math.pow(r.n - pe.n, 2));
    final lado = (r.e - a.e) * u.n - (r.n - a.n) * u.e; // > 0: à direita
    return lado >= 0 ? dist : -dist;
  }

  // quanto do segmento i o ponto já passou (0 a 1, pode passar de 1)
  double _avanco(Ponto r, int i) {
    final a = rota.pontos[i], b = rota.pontos[i + 1];
    final l2 = math.max(
      1e-9,
      math.pow(b.e - a.e, 2) + math.pow(b.n - a.n, 2).toDouble(),
    );
    return ((r.e - a.e) * (b.e - a.e) + (r.n - a.n) * (b.n - a.n)) / l2;
  }

  /// Até onde o trator pode ir agora: devagar nas curvas, e já freando antes delas.
  double? get limiteDeVelocidade {
    if (!ligado) return null;
    final p = rota.pontos;
    var s = 0.0;
    for (var i = indice; i + 1 < p.length && s < 12; i++) {
      if (p[i].curva || p[i + 1].curva) return velocidadeNaCurva;
      s += math.sqrt(
        math.pow(p[i + 1].e - p[i].e, 2) + math.pow(p[i + 1].n - p[i].n, 2),
      );
    }
    return null;
  }

  /// A cada quadro: o motor gira o volante na direção da rota.
  void conduzir(FisicaTrator t, double dt) {
    if (!ligado) return;
    if (t.velocidade < -0.1) {
      ligado = false;
      return;
    }
    final p = rota.pontos;
    final r = eixo(t);
    // avança pelos segmentos já vencidos (nunca volta: a rota cruza a si mesma nas voltas)
    while (indice + 2 < p.length && _avanco(r, indice) > 1) {
      indice++;
    }
    if (indice + 2 >= p.length && _avanco(r, indice) > 1) {
      ligado = false;
      concluido = true;
      return;
    }
    erro = _distanciaAoSegmento(r, indice);

    // o alvo: [olhar] metros adiante, medidos ao longo da rota
    final olhar = p[indice].curva || p[indice + 1].curva
        ? 3.0
        : math.max(3.5, 1.6 * t.velocidade.abs() + 2);
    final a = p[indice], b = p[indice + 1];
    final lAB = math.max(
      1e-9,
      math.sqrt(math.pow(b.e - a.e, 2) + math.pow(b.n - a.n, 2)),
    );
    var resta = olhar + _avanco(r, indice).clamp(0.0, 1.0) * lAB;
    var i = indice;
    Ponto alvo = (e: b.e, n: b.n);
    while (i + 1 < p.length) {
      final u = p[i], v = p[i + 1];
      final l = math.sqrt(math.pow(v.e - u.e, 2) + math.pow(v.n - u.n, 2));
      if (resta <= l) {
        alvo = (
          e: u.e + (v.e - u.e) * resta / l,
          n: u.n + (v.n - u.n) * resta / l,
        );
        break;
      }
      resta -= l;
      alvo = (e: v.e, n: v.n);
      i++;
    }

    // o ângulo até o alvo, no referencial do trator (positivo = alvo à direita)
    final h = t.rumo * math.pi / 180;
    final ve = alvo.e - r.e, vn = alvo.n - r.n;
    final adiante = ve * math.sin(h) + vn * math.cos(h);
    final aDireita = ve * math.cos(h) - vn * math.sin(h);
    final alfa = math.atan2(aDireita, adiante);
    final dist = math.max(1e-6, math.sqrt(ve * ve + vn * vn));
    final esterco =
        (math.atan(2 * FisicaTrator.entreEixos * math.sin(alfa) / dist) *
                180 /
                math.pi)
            .clamp(-FisicaTrator.estercoMaximo, FisicaTrator.estercoMaximo);

    // o motor elétrico: leva o volante até lá, com velocidade limitada
    final alvoVolante =
        esterco /
        FisicaTrator.estercoMaximo *
        360 *
        FisicaTrator.voltasDoVolante;
    final passo = velocidadeMotor * dt;
    t.volante += (alvoVolante - t.volante).clamp(-passo, passo);
  }
}

/// Autoteste: `dart --enable-asserts lib/piloto.dart` (de dentro de simulador/).
/// Dirige a rota inteira com a física e a plantadeira rebocada, nos dois talhões, e
/// confere que o trator e a plantadeira não saem do contorno e que o talhão fica coberto.
void main() {
  final talhoes = [
    Talhao.padrao(),
    if (File('../../exemplos/talhao_sinop.shp').existsSync())
      Talhao.deShapefile(
        Shapefile.ler('../../exemplos/talhao_sinop.shp'),
        nome: 'talhao_sinop',
      ),
  ];
  for (final talhao in talhoes) {
    final ab = talhao.linhaAB;
    final rota = Rota.planejar(talhao, a: ab.a, b: ab.b);
    final piloto = PilotoAutomatico(rota);
    // o trator no começo da rota, alinhado com ela
    final p0 = rota.pontos[0], p1 = rota.pontos[1];
    final rumo = math.atan2(p1.e - p0.e, p1.n - p0.n) * 180 / math.pi;
    final t = FisicaTrator()
      ..reposicionar(
        p0.e +
            math.sin(rumo * math.pi / 180) * FisicaTrator.antenaAFrenteDoEixo,
        p0.n +
            math.cos(rumo * math.pi / 180) * FisicaTrator.antenaAFrenteDoEixo,
        rumo,
      )
      ..aceleradorDeMao = 0.55; // ~10 km/h nas retas
    final motivo = piloto.engatar(t);
    assert(motivo == null, motivo);

    final engate = Engate();
    final mapa = MapaAplicacao.para(talhao);
    var fora = 0,
        piorNaReta = 0.0,
        segundos = 0.0,
        maiorVelCurva = 0.0,
        desdeCurva = 0.0;
    ({double e, double n, double rumo})? barraAntes;
    const dt = 1 / 30;
    while (piloto.ligado && segundos < 3600) {
      piloto.conduzir(t, dt);
      final limite = piloto.limiteDeVelocidade;
      t.freio = limite != null && t.velocidade > limite
          ? ((t.velocidade - limite) * 2).clamp(0.0, 1.0)
          : 0;
      t.passo(dt);
      segundos += dt;
      if (rota.pontos[piloto.indice].curva) {
        maiorVelCurva = math.max(maiorVelCurva, t.velocidade);
      }
      // o trator (antena) e a plantadeira (as duas pontas da barra) dentro do talhão
      final b = engate.seguir(t.e, t.n, t.rumo);
      final esq = Barra.ponto(b.e, b.n, b.rumo, lado: -Barra.largura / 2);
      final dir = Barra.ponto(b.e, b.n, b.rumo, lado: Barra.largura / 2);
      if (!talhao.dentro(t.e, t.n) ||
          !talhao.dentro(esq.e, esq.n) ||
          !talhao.dentro(dir.e, dir.n)) {
        fora++;
      }
      // planta com a barra inteira (sem TC-SEC aqui: só a cobertura da rota)
      if (barraAntes != null) {
        for (var l = -Barra.largura / 2; l <= Barra.largura / 2; l += 0.25) {
          final s = Barra.ponto(b.e, b.n, b.rumo, lado: l);
          if (talhao.dentro(s.e, s.n)) mapa.marcar(s.e, s.n, 16000);
        }
      }
      barraAntes = b;
      // o desvio na reta: depois de 15 m saindo da curva (antes, ainda está entrando na linha)
      final r = rota.pontos[piloto.indice];
      desdeCurva = r.curva || !piloto.trecho.startsWith('passada')
          ? 0
          : desdeCurva + t.velocidade.abs() * dt;
      if (desdeCurva > 15 && piloto.limiteDeVelocidade == null) {
        piorNaReta = math.max(piorNaReta, piloto.erro.abs());
      }
    }

    // a cobertura: as células de dentro do talhão que a barra cobriu
    var dentro = 0, cobertas = 0;
    for (var y = 0; y < mapa.altura; y++) {
      for (var x = 0; x < mapa.largura; x++) {
        final e = mapa.origemE + (x + 0.5) * mapa.celula,
            n = mapa.origemN + (y + 0.5) * mapa.celula;
        if (!talhao.dentro(e, n)) continue;
        dentro++;
        if (mapa.dados[y * mapa.largura + x] != 0) cobertas++;
      }
    }
    final cobertura = cobertas / dentro;
    // ignore: avoid_print
    print(
      '${talhao.nome}: ${rota.passadas} passadas, ${(rota.comprimento / 1000).toStringAsFixed(2)} km em '
      '${(segundos / 60).toStringAsFixed(1)} min; fora do talhão: $fora quadros; '
      'desvio na reta até ${(piorNaReta * 100).toStringAsFixed(1)} cm; '
      'curvas a até ${(maiorVelCurva * 3.6).toStringAsFixed(1)} km/h; cobertura ${(cobertura * 100).toStringAsFixed(1)}%',
    );
    assert(piloto.concluido, 'terminou a rota');
    assert(
      fora == 0,
      'trator e plantadeira sempre dentro do talhão ($fora quadros fora)',
    );
    assert(piorNaReta < 0.10, 'na reta, a menos de 10 cm');
    assert(
      maiorVelCurva < PilotoAutomatico.velocidadeNaCurva + 0.3,
      'devagar nas curvas',
    );
    assert(
      cobertura > 0.95,
      'cobriu o talhão (${(cobertura * 100).toStringAsFixed(1)}%)',
    );
  }
}
