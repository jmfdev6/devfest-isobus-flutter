// relatorio.dart — o mapa de aplicação comparado com a prescrição: relatório e exportação
//
// A prescrição vai para a MESMA grade do mapa de aplicação (uma vez por talhão); daí
// comparar, classificar e somar é só percorrer as duas grades juntas.
import 'dart:typed_data';

import 'geo.dart';
import 'shapefile.dart';

/// A prescrição na grade do mapa: o código (taxa / 250) em cada célula; 0 = fora do talhão.
Uint8List gradeDePrescricao(Talhao t, MapaAplicacao m) {
  final g = Uint8List(m.largura * m.altura);
  for (var i = 0; i < g.length; i++) {
    final c = m.centro(i);
    final taxa = t.taxa(c.e, c.n);
    if (taxa != null) g[i] = MapaAplicacao.codigo(taxa);
  }
  return g;
}

/// O que aconteceu em cada célula, comparando o aplicado com o prescrito.
enum Classe { fora, naoAplicado, certo, abaixo, acima, sobreposto }

/// A classe de cada célula ([Classe.index]). [tolerancia]: 0,05 = ±5% da prescrição.
Uint8List classificar(
  Uint8List prescricao,
  MapaAplicacao m, {
  double tolerancia = 0.05,
}) {
  final saida = Uint8List(prescricao.length);
  for (var i = 0; i < saida.length; i++) {
    saida[i] = _classe(
      prescricao[i],
      m.dados[i],
      m.sobrepostas[i],
      tolerancia,
    ).index;
  }
  return saida;
}

Classe _classe(int prescrito, int aplicado, int sobreposto, double tolerancia) {
  if (prescrito == 0) return Classe.fora;
  if (aplicado == 0) return Classe.naoAplicado;
  if (sobreposto != 0) return Classe.sobreposto;
  final dif = (aplicado - prescrito) / prescrito;
  if (dif < -tolerancia) return Classe.abaixo;
  if (dif > tolerancia) return Classe.acima;
  return Classe.certo;
}

/// Uma linha do relatório: uma taxa prescrita (todas as zonas com ela) ou o total.
class LinhaRelatorio {
  LinhaRelatorio(this.taxaPrescrita);
  final int? taxaPrescrita; // null = total
  double areaHa = 0,
      aplicadaHa = 0,
      certaHa = 0,
      abaixoHa = 0,
      acimaHa = 0,
      sobrepostaHa = 0;
  double sementesPrevistas = 0, sementesAplicadas = 0;

  double get naoAplicadaHa => areaHa - aplicadaHa;
  double get cobertura => areaHa == 0 ? 0 : aplicadaHa / areaHa;
}

class Relatorio {
  Relatorio._(this.porTaxa, this.total, this.tolerancia);

  final List<LinhaRelatorio> porTaxa;
  final LinhaRelatorio total;
  final double tolerancia;

  /// Soma, por taxa prescrita: área, área aplicada (certa, abaixo, acima, sobreposta)
  /// e sementes previstas x aplicadas. Só conta o que está dentro do talhão.
  factory Relatorio.de(
    Uint8List prescricao,
    MapaAplicacao m, {
    double tolerancia = 0.05,
  }) {
    final ha = m.celula * m.celula / 10000;
    final linhas = <int, LinhaRelatorio>{};
    final total = LinhaRelatorio(null);
    for (var i = 0; i < prescricao.length; i++) {
      final p = prescricao[i];
      if (p == 0) continue;
      final taxa = MapaAplicacao.taxaDe(p);
      final l = linhas.putIfAbsent(taxa, () => LinhaRelatorio(taxa));
      for (final x in [l, total]) {
        x.areaHa += ha;
        x.sementesPrevistas += taxa * ha;
        final a = m.dados[i];
        if (a == 0) continue;
        final aplicada = MapaAplicacao.taxaDe(a);
        x.aplicadaHa += ha;
        x.sementesAplicadas += aplicada * ha * (m.sobrepostas[i] != 0 ? 2 : 1);
        switch (_classe(p, a, m.sobrepostas[i], tolerancia)) {
          case Classe.certo:
            x.certaHa += ha;
          case Classe.abaixo:
            x.abaixoHa += ha;
          case Classe.acima:
            x.acimaHa += ha;
          case Classe.sobreposto:
            x.sobrepostaHa += ha;
          default:
        }
      }
    }
    return Relatorio._(
      linhas.values.toList()
        ..sort((a, b) => a.taxaPrescrita!.compareTo(b.taxaPrescrita!)),
      total,
      tolerancia,
    );
  }

  /// Uma tabela em texto (para o terminal).
  String emTexto() {
    String l(LinhaRelatorio x) {
      String ha(double v) => v.toStringAsFixed(2).padLeft(6);
      final nome = x.taxaPrescrita == null ? 'total' : '${x.taxaPrescrita}';
      return '${nome.padLeft(7)}  ${ha(x.areaHa)}  ${ha(x.aplicadaHa)} (${(x.cobertura * 100).toStringAsFixed(0).padLeft(3)}%)'
          '  ${ha(x.certaHa)}  ${ha(x.abaixoHa)}  ${ha(x.acimaHa)}  ${ha(x.sobrepostaHa)}'
          '  ${(x.sementesPrevistas / 1000).toStringAsFixed(1).padLeft(8)}  ${(x.sementesAplicadas / 1000).toStringAsFixed(1).padLeft(8)}';
    }

    return [
      'prescrita    área  aplicada        certa  abaixo   acima  sobrep.  previstas aplicadas',
      '  (sem/ha)   (ha)      (ha)         (ha)    (ha)    (ha)     (ha)   (mil sem.) (mil sem.)',
      for (final x in porTaxa) l(x),
      l(total),
      'certa = a menos de ${(tolerancia * 100).toStringAsFixed(0)}% da prescrição',
    ].join('\n');
  }
}

/// Grava o mapa de aplicação como shapefile de polígonos (em graus, WGS84), para abrir
/// no QGIS ou num software agrícola. Cada polígono é um trecho de uma linha da grade
/// com a mesma taxa aplicada, a mesma prescrita e a mesma sobreposição.
// ponytail: um retângulo por trecho de linha (não junta linhas vizinhas iguais); num
// talhão grande sai um arquivo de dezenas de milhares de polígonos, o que o QGIS abre bem
int exportarAplicacao(
  String base,
  Talhao t,
  MapaAplicacao m,
  Uint8List prescricao,
) {
  final poligonos = <List<List<XY>>>[];
  final registros = <List<Object?>>[];
  XY g(double e, double n) {
    final p = t.graus(e, n);
    return (x: p.lon, y: p.lat);
  }

  for (var y = 0; y < m.altura; y++) {
    var x = 0;
    while (x < m.largura) {
      final i = y * m.largura + x;
      final chave = (m.dados[i], prescricao[i], m.sobrepostas[i]);
      if (m.dados[i] == 0) {
        x++;
        continue;
      }
      var fim = x + 1;
      while (fim < m.largura &&
          (
                m.dados[y * m.largura + fim],
                prescricao[y * m.largura + fim],
                m.sobrepostas[y * m.largura + fim],
              ) ==
              chave) {
        fim++;
      }
      final e0 = m.origemE + x * m.celula, e1 = m.origemE + fim * m.celula;
      final n0 = m.origemN + y * m.celula, n1 = n0 + m.celula;
      // sentido horário: sobe pela borda oeste, vai a leste por cima, desce, volta
      poligonos.add([
        [g(e0, n0), g(e0, n1), g(e1, n1), g(e1, n0), g(e0, n0)],
      ]);
      final aplicada = MapaAplicacao.taxaDe(chave.$1);
      final prescrita = chave.$2 == 0 ? null : MapaAplicacao.taxaDe(chave.$2);
      registros.add([
        aplicada,
        prescrita,
        prescrita == null ? null : (aplicada - prescrita) * 100 / prescrita,
        chave.$3,
        (fim - x) * m.celula * m.celula,
      ]);
      x = fim;
    }
  }
  Shapefile.gravarPoligonos(base, poligonos, const [
    (
      nome: 'TAXA_APL',
      tipo: 'N',
      tamanho: 8,
      decimais: 0,
    ), // aplicada (sementes/ha)
    (
      nome: 'TAXA_PRE',
      tipo: 'N',
      tamanho: 8,
      decimais: 0,
    ), // prescrita (vazio: fora)
    (
      nome: 'DIF_PCT',
      tipo: 'N',
      tamanho: 8,
      decimais: 1,
    ), // aplicada - prescrita, em %
    (
      nome: 'SOBREP',
      tipo: 'N',
      tamanho: 1,
      decimais: 0,
    ), // 1 = passou duas vezes
    (nome: 'AREA_M2', tipo: 'N', tamanho: 10, decimais: 2),
  ], registros);
  return poligonos.length;
}
