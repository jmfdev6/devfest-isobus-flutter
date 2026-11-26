// rota.dart — o caminho do piloto automático: cobre o talhão sem sair dele
//
// Como as "curvas automáticas" dos pilotos de verdade:
//   1. uma CABECEIRA em volta do talhão (2 passadas de largura): é onde se manobra;
//   2. as PASSADAS internas, paralelas à AB, cortadas pelo talhão menos a cabeceira.
//      Cada uma vai até a PLANTADEIRA (que vem atrás) chegar na cabeceira;
//   3. uma CURVA em U entre passadas vizinhas, conferida para ficar dentro do contorno;
//   4. no fim, as VOLTAS de cabeceira, por dentro da divisa, para plantar a faixa
//      onde se manobrou (as seções cortam sozinhas o que já estiver plantado: TC-SEC).
import 'dart:math' as math;

import 'geo.dart';

/// Um ponto do caminho: onde o meio do eixo traseiro deve passar.
typedef PontoRota = ({double e, double n, bool curva, int trecho});

class Rota {
  Rota._(this.pontos, this.trechos, this.passadas);

  final List<PontoRota> pontos;

  /// O nome de cada trecho, para a tela: "passada 3 de 7", "curva", "cabeceira 1 de 2".
  final List<String> trechos;
  final int passadas;

  double get comprimento {
    var s = 0.0;
    for (var i = 1; i < pontos.length; i++) {
      final a = pontos[i - 1], b = pontos[i];
      s += math.sqrt(math.pow(b.e - a.e, 2) + math.pow(b.n - a.n, 2));
    }
    return s;
  }

  /// Planeja o caminho no talhão [t], com passadas paralelas a A->B.
  static Rota planejar(
    Talhao t, {
    required Ponto a,
    required Ponto b,
    double largura = Barra.largura,
    int voltasCabeceira = 2,
    double recuo = Barra.recuo,
    double folga = 0.3,
  }) {
    final borda = bordaExterna(t);
    final cabeceira = largura * voltasCabeceira;
    final miolo = recuar(borda, cabeceira - 0.05); // o talhão menos a cabeceira
    final dAB = math.max(1e-9, _dist(a, b));
    final d = (
      e: (b.e - a.e) / dAB,
      n: (b.n - a.n) / dAB,
    ); // ao longo das passadas
    final normal = (e: d.n, n: -d.e); // à direita de A->B
    Ponto em(double ao, double lado) => (
      e: a.e + d.e * ao + normal.e * lado,
      n: a.n + d.n * ao + normal.n * lado,
    );
    double aoLado(Ponto p) => (p.e - a.e) * normal.e + (p.n - a.n) * normal.n;

    // 2. as passadas: cada linha k (a k larguras da AB) cortada pelo miolo
    final lados = borda.map(aoLado);
    final kDe = (lados.reduce(math.min) / largura).floor(),
        kAte = (lados.reduce(math.max) / largura).ceil();
    final passadas = <({double lado, double t0, double t1})>[];
    for (var k = kDe; k <= kAte; k++) {
      final corte = _cortar(miolo, em(0, k * largura), d);
      if (corte != null && corte.t1 - corte.t0 > 2)
        passadas.add((lado: k * largura, t0: corte.t0, t1: corte.t1));
    }

    // o trecho do TRATOR em cada passada: a plantadeira vem [recuo] m atrás, então o
    // trator começa e termina [recuo] m adiante; as passadas alternam de sentido
    final ini = <double>[], fim = <double>[];
    for (var i = 0; i < passadas.length; i++) {
      final p = passadas[i];
      if (i.isEven) {
        ini.add(p.t0 + recuo);
        fim.add(p.t1 + recuo);
      } else {
        ini.add(p.t1 - recuo);
        fim.add(p.t0 - recuo);
      }
    }

    // 3. as curvas: o ápice no mais longe dos dois fins; se a curva sair do talhão,
    // no mais perto (encurta a passada mais comprida)
    final r = largura / 2;
    final curvas = <List<Ponto>>[];
    for (var i = 0; i + 1 < passadas.length; i++) {
      final s = i.isEven ? 1.0 : -1.0; // o sentido da passada i
      final ladoI = passadas[i].lado, ladoJ = passadas[i + 1].lado;
      List<Ponto> curva(double apice) {
        final pts = <Ponto>[];
        // estica a passada que acabou antes até o ápice, faz o U, volta até o início da outra
        for (var f = 0; f <= 24; f++) {
          final phi = math.pi * f / 24;
          final lado = ladoI + (ladoJ - ladoI) * (1 - math.cos(phi)) / 2;
          pts.add(em(apice + s * r * math.sin(phi), lado));
        }
        return pts;
      }

      bool cabe(double apice) {
        // o trator tem corpo: confere também um U 1,5 m mais aberto
        for (var f = 0; f <= 24; f++) {
          final phi = math.pi * f / 24;
          final lado = ladoI + (ladoJ - ladoI) * (1 - math.cos(phi)) / 2;
          if (!t.dentro(
            em(apice + s * (r + 1.5) * math.sin(phi), lado).e,
            em(apice + s * (r + 1.5) * math.sin(phi), lado).n,
          )) {
            return false;
          }
        }
        return t.dentro(em(apice, ladoI).e, em(apice, ladoI).n) &&
            t.dentro(em(apice, ladoJ).e, em(apice, ladoJ).n);
      }

      final longe = s > 0
          ? math.max(fim[i], ini[i + 1])
          : math.min(fim[i], ini[i + 1]);
      final perto = s > 0
          ? math.min(fim[i], ini[i + 1])
          : math.max(fim[i], ini[i + 1]);
      final apice = cabe(longe) ? longe : perto;
      fim[i] = apice;
      ini[i + 1] = apice;
      curvas.add(curva(apice));
    }

    // monta o caminho: passada, curva, passada, curva...
    final pontos = <PontoRota>[];
    final trechos = <String>[];
    void novoTrecho(String nome) => trechos.add(nome);
    void ponto(Ponto p, bool curva) =>
        pontos.add((e: p.e, n: p.n, curva: curva, trecho: trechos.length - 1));
    for (var i = 0; i < passadas.length; i++) {
      novoTrecho('passada ${i + 1} de ${passadas.length}');
      // em reta, um ponto a cada 5 m (o piloto mede o desvio contra o segmento)
      final n = math.max(1, ((fim[i] - ini[i]).abs() / 5).ceil());
      for (var j = 0; j <= n; j++) {
        ponto(em(ini[i] + (fim[i] - ini[i]) * j / n, passadas[i].lado), false);
      }
      if (i < curvas.length) {
        novoTrecho('curva');
        for (final p in curvas[i].skip(1).take(curvas[i].length - 2)) {
          ponto(p, true);
        }
      }
    }

    // 4. as voltas de cabeceira: de dentro para fora, cada uma meia largura mais perto da divisa
    for (var v = voltasCabeceira - 1; v >= 0; v--) {
      // a volta de fora deixa a borda da plantadeira [folga] m antes da divisa: o
      // erro de condução não a leva para fora do talhão
      final anel = _arredondar(recuar(borda, largura * (v + 0.5) + folga));
      if (anel.length < 3) continue;
      final Ponto atual = pontos.isEmpty
          ? anel.first.p
          : (e: pontos.last.e, n: pontos.last.n);
      // entra pelo ponto mais perto, no sentido que pede a menor virada
      var i0 = 0;
      for (var i = 1; i < anel.length; i++) {
        if (_dist(anel[i].p, atual) < _dist(anel[i0].p, atual)) i0 = i;
      }
      var sentido = 1;
      if (pontos.length >= 2) {
        final u = pontos[pontos.length - 1], w = pontos[pontos.length - 2];
        final h = (e: u.e - w.e, n: u.n - w.n);
        final prox = anel[(i0 + 1) % anel.length];
        final ant = anel[(i0 - 1 + anel.length) % anel.length];
        final adiante =
            (prox.p.e - anel[i0].p.e) * h.e + (prox.p.n - anel[i0].p.n) * h.n;
        final atras =
            (ant.p.e - anel[i0].p.e) * h.e + (ant.p.n - anel[i0].p.n) * h.n;
        if (atras > adiante) sentido = -1;
      }
      // não entra pelo ponto mais perto (seria um S apertado de uma passada para o
      // lado): mira 18 m adiante no anel e entra em diagonal suave. O trecho pulado
      // é plantado no fim da volta, que fecha no ponto de entrada.
      if (pontos.isNotEmpty)
        i0 = (i0 + sentido * 9 + anel.length * 4) % anel.length;
      novoTrecho('cabeceira ${voltasCabeceira - v} de $voltasCabeceira');
      for (var j = 0; j <= anel.length; j++) {
        // os primeiros metros saindo da passada são curva (velocidade de manobra)
        final q = anel[(i0 + sentido * j + anel.length * 4) % anel.length];
        ponto(q.p, q.curva || j < 4);
      }
    }
    return Rota._(pontos, trechos, passadas.length);
  }

  static double _dist(({double e, double n}) a, ({double e, double n}) b) =>
      math.sqrt(math.pow(a.e - b.e, 2) + math.pow(a.n - b.n, 2));

  // Onde a reta base + dir*t cruza o polígono: o maior trecho de dentro (t0 < t1)
  static ({double t0, double t1})? _cortar(
    List<Ponto> anel,
    Ponto base,
    Ponto dir,
  ) {
    final ts = <double>[];
    for (var i = 0; i < anel.length; i++) {
      final p = anel[i], q = anel[(i + 1) % anel.length];
      final ex = q.e - p.e, ey = q.n - p.n;
      final den = dir.e * ey - dir.n * ex;
      if (den.abs() < 1e-12) continue;
      final wx = p.e - base.e, wy = p.n - base.n;
      final t = (wx * ey - wy * ex) / den;
      final s = (wx * dir.n - wy * dir.e) / den;
      if (s >= 0 && s < 1) ts.add(t);
    }
    ts.sort();
    ({double t0, double t1})? melhor;
    for (var i = 0; i + 1 < ts.length; i += 2) {
      if (melhor == null || ts[i + 1] - ts[i] > melhor.t1 - melhor.t0)
        melhor = (t0: ts[i], t1: ts[i + 1]);
    }
    return melhor;
  }

  // O anel (fechado) como caminho: pontos a cada [passo] m nas retas e, em cada canto,
  // um arco tangente às duas bordas (raio [raio], menor se a borda for curta). Um canto
  // vivo o trator não faz: o volante leva quase 2 s de batente a batente e ele passaria
  // do ponto. O arco fica do lado de dentro do canto: só se afasta da divisa.
  static List<({Ponto p, bool curva})> _arredondar(
    List<Ponto> anel, {
    double passo = 2,
    double raio = 6,
  }) {
    final n = anel.length;
    final arcos = <List<Ponto>>[];
    for (var i = 0; i < n; i++) {
      final p = anel[(i - 1 + n) % n], q = anel[i], r = anel[(i + 1) % n];
      final l1 = _dist(p, q), l2 = _dist(q, r);
      final u1 = (e: (q.e - p.e) / l1, n: (q.n - p.n) / l1);
      final u2 = (e: (r.e - q.e) / l2, n: (r.n - q.n) / l2);
      final cosT = (u1.e * u2.e + u1.n * u2.n).clamp(-1.0, 1.0);
      final teta = math.acos(cosT); // quanto o caminho vira neste canto
      if (teta < 0.05) {
        arcos.add([q]);
        continue;
      }
      // o recuo do arco em cada borda: no máximo metade dela (sobra reta entre cantos)
      final corte = math.min(raio * math.tan(teta / 2), math.min(l1, l2) / 2);
      final rr = corte / math.tan(teta / 2);
      final t1 = (e: q.e - u1.e * corte, n: q.n - u1.n * corte);
      final esquerda = u1.e * u2.n - u1.n * u2.e > 0; // vira para a esquerda?
      final normal = esquerda ? (e: -u1.n, n: u1.e) : (e: u1.n, n: -u1.e);
      final c = (e: t1.e + normal.e * rr, n: t1.n + normal.n * rr);
      final a0 = math.atan2(t1.n - c.n, t1.e - c.e);
      final passos = math.max(
        2,
        (rr * teta / 1.0).ceil(),
      ); // um ponto por metro de arco
      final sinal = esquerda ? 1.0 : -1.0;
      arcos.add([
        for (var k = 0; k <= passos; k++)
          (
            e: c.e + rr * math.cos(a0 + sinal * teta * k / passos),
            n: c.n + rr * math.sin(a0 + sinal * teta * k / passos),
          ),
      ]);
    }
    final saida = <({Ponto p, bool curva})>[];
    for (var i = 0; i < n; i++) {
      final arco = arcos[i];
      for (final p in arco) {
        saida.add((p: p, curva: arco.length > 1));
      }
      // a reta até o começo do próximo canto
      final de = arco.last, ate = arcos[(i + 1) % n].first;
      final m = (_dist(de, ate) / passo).ceil();
      for (var j = 1; j < m; j++) {
        saida.add((
          p: (
            e: de.e + (ate.e - de.e) * j / m,
            n: de.n + (ate.n - de.n) * j / m,
          ),
          curva: false,
        ));
      }
    }
    return saida;
  }
}

/// A divisa do talhão como um anel só (anti-horário), mesmo quando ele vem em zonas:
/// junta as bordas que têm talhão de um lado só, ponta com ponta.
// ponytail: só o anel externo; buracos (uma mata no meio do talhão) não entram na rota
List<Ponto> bordaExterna(Talhao t) {
  final arestas = <(Ponto, Ponto)>[];
  for (final p in t.contorno) {
    for (final anel in p) {
      for (var i = 0; i < anel.length; i++) {
        final u = anel[i], v = anel[(i + 1) % anel.length];
        final d = math.sqrt(math.pow(v.e - u.e, 2) + math.pow(v.n - u.n, 2));
        if (d < 0.05) continue;
        final me = (u.e + v.e) / 2, mn = (u.n + v.n) / 2;
        final ne = (v.n - u.n) / d * 0.5, nn = -(v.e - u.e) / d * 0.5;
        if (t.dentro(me + ne, mn + nn) && t.dentro(me - ne, mn - nn))
          continue; // interna
        arestas.add((u, v));
      }
    }
  }
  if (arestas.isEmpty) return const [];
  bool perto(Ponto a, Ponto b) =>
      (a.e - b.e).abs() < 0.3 && (a.n - b.n).abs() < 0.3;
  final usadas = List.filled(arestas.length, false);
  final anel = <Ponto>[arestas.first.$1, arestas.first.$2];
  usadas[0] = true;
  for (var passos = 0; passos < arestas.length; passos++) {
    var achou = false;
    for (var i = 0; i < arestas.length; i++) {
      if (usadas[i]) continue;
      final (u, v) = arestas[i];
      if (perto(u, anel.last) || perto(v, anel.last)) {
        anel.add(perto(u, anel.last) ? v : u);
        usadas[i] = true;
        achou = true;
        break;
      }
    }
    if (!achou) break;
  }
  if (anel.length > 1 && perto(anel.first, anel.last)) anel.removeLast();
  // tira os pontos no meio de uma reta (onde as zonas cortavam a borda)
  final limpo = <Ponto>[];
  for (var i = 0; i < anel.length; i++) {
    final p = anel[(i - 1 + anel.length) % anel.length],
        q = anel[i],
        r = anel[(i + 1) % anel.length];
    final cruz = (q.e - p.e) * (r.n - q.n) - (q.n - p.n) * (r.e - q.e);
    final tam =
        math.sqrt(math.pow(q.e - p.e, 2) + math.pow(q.n - p.n, 2)) *
        math.sqrt(math.pow(r.e - q.e, 2) + math.pow(r.n - q.n, 2));
    if (tam > 1e-9 && (cruz / tam).abs() > 0.01) limpo.add(q);
  }
  // anti-horário (área positiva)
  var area = 0.0;
  for (var i = 0; i < limpo.length; i++) {
    final p = limpo[i], q = limpo[(i + 1) % limpo.length];
    area += p.e * q.n - q.e * p.n;
  }
  return area < 0 ? limpo.reversed.toList() : limpo;
}

/// O anel anti-horário [anel] recuado [d] metros para dentro (cada borda anda d para o
/// lado de dentro; os cantos são onde as bordas novas se cruzam).
// ponytail: num talhão muito recortado, recuar demais pode cruzar o próprio anel
List<Ponto> recuar(List<Ponto> anel, double d) {
  final n = anel.length;
  if (n < 3) return const [];
  ({Ponto p, Ponto u}) linha(int i) {
    final p = anel[i], q = anel[(i + 1) % n];
    final l = math.max(
      1e-9,
      math.sqrt(math.pow(q.e - p.e, 2) + math.pow(q.n - p.n, 2)),
    );
    final u = (e: (q.e - p.e) / l, n: (q.n - p.n) / l);
    return (
      p: (e: p.e - u.n * d, n: p.n + u.e * d),
      u: u,
    ); // a esquerda é o lado de dentro
  }

  final saida = <Ponto>[];
  for (var i = 0; i < n; i++) {
    final a = linha((i - 1 + n) % n), b = linha(i);
    final den = a.u.e * b.u.n - a.u.n * b.u.e;
    if (den.abs() < 1e-9) {
      saida.add(b.p);
      continue;
    }
    final t = ((b.p.e - a.p.e) * b.u.n - (b.p.n - a.p.n) * b.u.e) / den;
    saida.add((e: a.p.e + a.u.e * t, n: a.p.n + a.u.n * t));
  }
  return saida;
}
