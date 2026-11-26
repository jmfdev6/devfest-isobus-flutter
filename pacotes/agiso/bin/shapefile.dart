// shapefile.dart — mostra o que um shapefile vira na cabine: talhão, zonas e linha AB
//
//   dart run bin/shapefile.dart ../../exemplos/talhao_sinop.shp
//   dart run bin/shapefile.dart contorno.shp prescricao.shp CAMPO [fator]
//
// Sem argumentos, confere tudo contra os exemplos de exemplos/gerar_talhao.py: a UTM, o
// contorno e a prescrição separados e a exportação do mapa de aplicação.
import 'dart:io';
import 'dart:math' as math;

import 'package:agiso/geo.dart';
import 'package:agiso/relatorio.dart';
import 'package:agiso/shapefile.dart';

double area(Poligono p) {
  var a = 0.0;
  for (final anel in p) {
    for (var i = 0; i < anel.length; i++) {
      final u = anel[i], v = anel[(i + 1) % anel.length];
      a += u.e * v.n - v.e * u.n;
    }
  }
  return a.abs() / 2;
}

double areaTotal(Talhao t) => t.contorno.map(area).fold(0.0, (s, a) => s + a);

void mostrar(Talhao t, Shapefile shp) {
  final ab = t.linhaAB;
  final comprimentoAB = math.sqrt(
    math.pow(ab.b.e - ab.a.e, 2) + math.pow(ab.b.n - ab.a.n, 2),
  );
  final rumoAB =
      (math.atan2(ab.b.e - ab.a.e, ab.b.n - ab.a.n) * 180 / math.pi) % 360;
  print(
    '${t.nome}: ${shp.feicoes.length} polígonos em ${shp.sistema}, ${(areaTotal(t) / 10000).toStringAsFixed(2)} ha',
  );
  print(
    '  campos: ${shp.campos.map((c) => '${c.nome} (${c.tipo})').join(', ')}',
  );
  for (final z in t.zonas) {
    print('  zona ${z.taxa} sementes/ha');
  }
  print(
    '  linha AB: ${comprimentoAB.toStringAsFixed(1)} m, rumo ${rumoAB.toStringAsFixed(1)}°',
  );
}

var falhas = 0;
void confere(bool ok, String o) {
  print('  ${ok ? 'ok    ' : 'FALHOU'} $o');
  if (!ok) falhas++;
}

void main(List<String> args) {
  if (args.isNotEmpty) {
    final contorno = Shapefile.ler(args[0]);
    final prescricao = args.length > 1 ? Shapefile.ler(args[1]) : null;
    final t = Talhao.deShapefiles(
      nome: args[0].split('/').last,
      contorno: contorno,
      prescricao: prescricao,
      campoTaxa: args.length > 2
          ? args[2]
          : Talhao.campoDeTaxaProvavel(prescricao ?? contorno),
      fator: args.length > 3 ? double.parse(args[3]) : 1,
    );
    mostrar(t, contorno);
    return;
  }

  const ex = '../../exemplos';
  final graus = Shapefile.ler('$ex/talhao_sinop.shp');
  final t = Talhao.deShapefile(graus, nome: 'talhao_sinop');
  mostrar(t, graus);
  print('conferindo contra exemplos/gerar_talhao.py:');

  // 1. o leitor, contra o que o gerador gravou: pentágono de 46500 m², AB de 250,2 m
  final ab = t.linhaAB;
  final comprimentoAB = math.sqrt(
    math.pow(ab.b.e - ab.a.e, 2) + math.pow(ab.b.n - ab.a.n, 2),
  );
  confere((areaTotal(t) - 46500).abs() < 50, 'área do talhão (46500 m²)');
  confere(
    t.zonas.map((z) => z.taxa).join(',') == '12000,20000,16000',
    'zonas e taxas',
  );
  confere(
    (comprimentoAB - 250.2).abs() < 0.5,
    'linha AB pela maior borda (250,2 m)',
  );

  // 2. a UTM: o exemplo numérico de Snyder (Clarke 1866), e o talhão em UTM 21S
  final snyder = TransversaDeMercator(
    a: 6378206.4,
    f: 1 - math.sqrt(1 - 0.00676866),
    meridianoCentral: -75,
    falsoNorte: 0,
  ).paraGraus((x: 500000 + 127106.5, y: 4484124.4));
  confere(
    (snyder.x + 73.5).abs() < 2e-6 && (snyder.y - 40.5).abs() < 2e-6,
    'UTM inversa no exemplo de Snyder',
  );
  final utm = Shapefile.ler('$ex/talhao_sinop_utm.shp');
  var pior = 0.0;
  for (var f = 0; f < graus.feicoes.length; f++) {
    for (var k = 0; k < graus.feicoes[f].aneis[0].length; k++) {
      final a = graus.feicoes[f].aneis[0][k], b = utm.feicoes[f].aneis[0][k];
      // a diferença em metros (graus x 111 km)
      pior = math.max(
        pior,
        math.sqrt(
          math.pow((a.x - b.x) * 109000, 2) + math.pow((a.y - b.y) * 111320, 2),
        ),
      );
    }
  }
  confere(utm.sistema.contains('UTM'), 'reconheceu ${utm.sistema}');
  confere(
    pior < 0.01,
    'UTM 21S -> graus: vértices a ${(pior * 1000).toStringAsFixed(1)} mm do original',
  );

  // 3. contorno (UTM) e prescrição (graus, DOSE_MIL em mil/ha, passando da divisa) separados
  final contorno = Shapefile.ler('$ex/contorno_sinop_utm.shp');
  final prescricao = Shapefile.ler('$ex/prescricao_sinop.shp');
  final separado = Talhao.deShapefiles(
    nome: 'separado',
    contorno: contorno,
    prescricao: prescricao,
    campoTaxa: 'DOSE_MIL',
    fator: 1000,
  );
  confere(
    (areaTotal(separado) - 46500).abs() < 50,
    'contorno separado: mesma área',
  );
  var iguais = 0, testes = 0;
  final l = t.limites;
  for (var e = l.minE; e < l.maxE; e += 7) {
    for (var n = l.minN; n < l.maxN; n += 7) {
      final te = t.local(t.graus(e, n).lat, t.graus(e, n).lon); // o mesmo ponto
      final g = t.graus(te.e, te.n);
      final ps = separado.local(g.lat, g.lon);
      testes++;
      if (t.taxa(te.e, te.n) == separado.taxa(ps.e, ps.n)) iguais++;
    }
  }
  confere(
    iguais / testes > 0.995,
    'prescrição separada: mesma taxa em $iguais de $testes pontos (bordas à parte)',
  );

  // 4. a exportação: um mapa com 3 faixas plantadas (uma abaixo da prescrição e um
  // trecho plantado duas vezes), gravado e relido
  final m = MapaAplicacao.para(t);
  for (var i = 0; i < m.dados.length; i++) {
    final c = m.centro(i);
    final taxa = t.taxa(c.e, c.n);
    if (taxa == null || c.e > 60) continue;
    m.marcar(c.e, c.n, c.e < 30 ? taxa : (taxa * 0.8).round(), agora: 0);
    if (c.e < 10)
      m.marcar(c.e, c.n, taxa, agora: 1000); // passou de novo, 100 s depois
  }
  final prescrito = gradeDePrescricao(t, m);
  final rel = Relatorio.de(prescrito, m);
  print(rel.emTexto());
  final pasta = Directory.systemTemp.createTempSync('exporta');
  final n = exportarAplicacao('${pasta.path}/aplicado', t, m, prescrito);
  final relido = Shapefile.ler('${pasta.path}/aplicado.shp');
  final areaLida = relido.feicoes.fold(
    0.0,
    (s, f) => s + (f.atributos['AREA_M2'] as num),
  );
  final sobrepLida = relido.feicoes
      .where((f) => f.atributos['SOBREP'] == 1)
      .fold(0.0, (s, f) => s + (f.atributos['AREA_M2'] as num));
  confere(relido.feicoes.length == n && n > 0, 'exportou e releu $n polígonos');
  confere(
    (areaLida / 10000 - m.hectares).abs() < 1e-6,
    'área exportada = área plantada (${m.hectares.toStringAsFixed(3)} ha)',
  );
  confere(
    (sobrepLida / 10000 - m.hectaresSobrepostos).abs() < 1e-6 &&
        m.sobrepostasN > 0,
    'sobreposição exportada',
  );
  confere(
    relido.feicoes.every(
      (f) =>
          f.atributos['TAXA_PRE'] == null ||
          (f.atributos['TAXA_APL'] as num) <= (f.atributos['TAXA_PRE'] as num),
    ),
    'taxas aplicadas e prescritas',
  );
  // o relatório, contra a contagem direta das células: e < 30 m na taxa certa (ou
  // sobreposta, e < 10 m), de 30 a 60 m a 80% (abaixo da prescrição)
  var certas = 0, abaixo = 0;
  for (var i = 0; i < m.dados.length; i++) {
    final c = m.centro(i);
    if (prescrito[i] == 0 || c.e > 60) continue;
    if (c.e < 30) {
      certas++;
    } else {
      abaixo++;
    }
  }
  final ha = m.celula * m.celula / 10000;
  confere(
    (rel.total.certaHa + rel.total.sobrepostaHa - certas * ha).abs() < 1e-9 &&
        (rel.total.abaixoHa - abaixo * ha).abs() < 1e-9,
    'relatório: certa ${rel.total.certaHa.toStringAsFixed(3)} ha + sobreposta, abaixo ${rel.total.abaixoHa.toStringAsFixed(3)} ha',
  );
  pasta.deleteSync(recursive: true);

  print(falhas == 0 ? 'confere com o gerador: ok' : 'FALHOU ($falhas)');
  if (falhas > 0) exit(1);
}
