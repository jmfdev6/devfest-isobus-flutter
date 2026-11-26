// mapa.dart — o talhão visto de cima: aplicado, prescrito x aplicado e prescrição
//
// Usado pela cabine (ao vivo) e pelo simulador (trabalhos guardados). As cores saem das
// grades (mapa de aplicação e prescrição na mesma grade), viram uma imagem refeita no
// máximo uma vez por segundo, e o contorno, o trator e a barra vão por cima.
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:agiso/geo.dart';
import 'package:agiso/relatorio.dart';

enum ModoMapa { aplicado, comparacao, prescricao }

extension NomeModo on ModoMapa {
  String get nome => switch (this) {
    ModoMapa.aplicado => 'aplicado',
    ModoMapa.comparacao => 'prescrito × aplicado',
    ModoMapa.prescricao => 'prescrição',
  };
}

/// A cor de uma taxa: do amarelo (pouca semente) ao verde-escuro (muita).
Color corDaTaxa(int taxa) {
  final t = ((taxa - 10000) / 12000).clamp(0.0, 1.0);
  return Color.lerp(const Color(0xFFF4D03F), const Color(0xFF1E8449), t)!;
}

/// As cores do prescrito x aplicado, por classe.
const coresDaClasse = <Classe, Color>{
  Classe.naoAplicado: Color(0xFFE0E0E0),
  Classe.certo: Color(0xFF2E7D32),
  Classe.abaixo: Color(0xFFFF9800),
  Classe.acima: Color(0xFFD32F2F),
  Classe.sobreposto: Color(0xFF7B1FA2),
};

const nomesDaClasse = <Classe, String>{
  Classe.naoAplicado: 'não aplicado',
  Classe.certo: 'na taxa (±5%)',
  Classe.abaixo: 'abaixo',
  Classe.acima: 'acima',
  Classe.sobreposto: 'sobreposto',
};

/// A prescrição na grade do mapa, calculada fora da tela (um isolate).
Future<Uint8List> prescricaoEmSegundoPlano(Talhao t, MapaAplicacao m) {
  // o isolate recebe uma cópia: um mapa vazio com a mesma grade basta
  final grade = MapaAplicacao.de(
    origemE: m.origemE,
    origemN: m.origemN,
    celula: m.celula,
    largura: m.largura,
    altura: m.altura,
    dados: Uint8List(0),
  );
  return Isolate.run(() => _prescricao(t, grade, m.largura * m.altura));
}

Uint8List _prescricao(Talhao t, MapaAplicacao grade, int celulas) {
  final g = Uint8List(celulas);
  for (var i = 0; i < celulas; i++) {
    final c = grade.centro(i);
    final taxa = t.taxa(c.e, c.n);
    if (taxa != null) g[i] = MapaAplicacao.codigo(taxa);
  }
  return g;
}

class MapaTalhao extends StatefulWidget {
  const MapaTalhao({
    super.key,
    required this.talhao,
    required this.mapa,
    this.modo = ModoMapa.aplicado,
    this.posicao,
    this.barra,
    this.plantando = false,
    this.aoTerPrescricao,
  });

  final Talhao talhao;
  final MapaAplicacao mapa;
  final ModoMapa modo;

  /// O trator (antena) e a barra rebocada, ao vivo; null num trabalho guardado.
  final ({double e, double n, double rumo})? posicao, barra;
  final bool plantando;

  /// Avisa quando a prescrição na grade fica pronta (para o relatório).
  final void Function(Uint8List prescricao)? aoTerPrescricao;

  @override
  State<MapaTalhao> createState() => _MapaTalhaoState();
}

class _MapaTalhaoState extends State<MapaTalhao> {
  Uint8List? _prescricao;
  ui.Image? _imagem;
  ({MapaAplicacao mapa, ModoMapa modo, int plantadas, int sobrepostas})?
  _daImagem;
  Timer? _relogio;
  bool _montando = false;

  @override
  void initState() {
    super.initState();
    _calcularPrescricao();
    // o mapa ao vivo muda sozinho: confere uma vez por segundo
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) => _atualizar());
  }

  @override
  void didUpdateWidget(MapaTalhao antigo) {
    super.didUpdateWidget(antigo);
    if (!identical(antigo.talhao, widget.talhao) ||
        !identical(antigo.mapa, widget.mapa)) {
      _prescricao = null;
      _imagem = null;
      _daImagem = null;
      _calcularPrescricao();
    } else if (antigo.modo != widget.modo) {
      _atualizar();
    }
  }

  @override
  void dispose() {
    _relogio?.cancel();
    super.dispose();
  }

  Future<void> _calcularPrescricao() async {
    final t = widget.talhao, m = widget.mapa;
    final p = await prescricaoEmSegundoPlano(t, m);
    if (!mounted ||
        !identical(t, widget.talhao) ||
        !identical(m, widget.mapa)) {
      return;
    }
    _prescricao = p;
    widget.aoTerPrescricao?.call(p);
    _atualizar();
  }

  void _atualizar() {
    final p = _prescricao, m = widget.mapa;
    if (p == null || _montando) return;
    final estado = (
      mapa: m,
      modo: widget.modo,
      plantadas: m.plantadas,
      sobrepostas: m.sobrepostasN,
    );
    if (estado == _daImagem) return;
    _montando = true;
    final px = Uint8List(m.largura * m.altura * 4);
    final classes = widget.modo == ModoMapa.comparacao
        ? classificar(p, m)
        : null;
    for (var i = 0; i < m.dados.length; i++) {
      Color? cor;
      switch (widget.modo) {
        case ModoMapa.aplicado:
          if (m.dados[i] != 0) {
            cor = m.sobrepostas[i] != 0
                ? coresDaClasse[Classe.sobreposto]
                : corDaTaxa(MapaAplicacao.taxaDe(m.dados[i]));
          }
        case ModoMapa.prescricao:
          if (p[i] != 0) cor = corDaTaxa(MapaAplicacao.taxaDe(p[i]));
        case ModoMapa.comparacao:
          if (p[i] != 0) cor = coresDaClasse[Classe.values[classes![i]]];
      }
      if (cor == null) continue;
      // a linha 0 da grade é o sul; na imagem, a linha 0 é o topo (norte)
      final y = m.altura - 1 - i ~/ m.largura, x = i % m.largura;
      final j = (y * m.largura + x) * 4;
      px[j] = (cor.r * 255).round();
      px[j + 1] = (cor.g * 255).round();
      px[j + 2] = (cor.b * 255).round();
      px[j + 3] = 235;
    }
    ui.decodeImageFromPixels(px, m.largura, m.altura, ui.PixelFormat.rgba8888, (
      imagem,
    ) {
      _montando = false;
      if (!mounted || !identical(m, widget.mapa)) return;
      setState(() {
        _imagem = imagem;
        _daImagem = estado;
      });
    });
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _Pintor(
      widget.talhao,
      widget.mapa,
      _imagem,
      widget.modo,
      widget.posicao,
      widget.barra,
      widget.plantando,
    ),
    child: const SizedBox.expand(),
  );
}

class _Pintor extends CustomPainter {
  _Pintor(
    this.t,
    this.m,
    this.imagem,
    this.modo,
    this.posicao,
    this.barra,
    this.plantando,
  );
  final Talhao t;
  final MapaAplicacao m;
  final ui.Image? imagem;
  final ModoMapa modo;
  final ({double e, double n, double rumo})? posicao, barra;
  final bool plantando;

  @override
  void paint(Canvas canvas, Size size) {
    final l = t.limites;
    // escala que cabe o talhão inteiro, com margem para a cabeceira
    const margem = 8.0;
    final k = math.min(
      size.width / (l.maxE - l.minE + 2 * margem),
      size.height / (l.maxN - l.minN + 2 * margem),
    );
    final ox = (size.width - (l.maxE - l.minE) * k) / 2 - l.minE * k;
    final oy = (size.height + (l.maxN - l.minN) * k) / 2 + l.minN * k;
    Offset tela(double e, double n) => Offset(ox + e * k, oy - n * k);
    Path caminho(Poligono p) {
      final c = Path()..fillType = PathFillType.evenOdd;
      for (final anel in p) {
        c.addPolygon([for (final q in anel) tela(q.e, q.n)], true);
      }
      return c;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF8DB86B),
    );
    for (final p in t.contorno) {
      canvas.drawPath(caminho(p), Paint()..color = const Color(0xFFF3E7CC));
    }
    // no modo aplicado, as zonas da prescrição de leve por baixo
    if (modo == ModoMapa.aplicado) {
      canvas.save();
      for (final p in t.contorno) {
        canvas.clipPath(caminho(p));
      }
      for (final z in t.zonas) {
        canvas.drawPath(
          caminho(z.poligono),
          Paint()..color = corDaTaxa(z.taxa).withValues(alpha: 0.2),
        );
      }
      canvas.restore();
    }
    final img = imagem;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromPoints(
          tela(m.origemE, m.origemN + m.altura * m.celula),
          tela(m.origemE + m.largura * m.celula, m.origemN),
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
    }
    for (final p in t.contorno) {
      canvas.drawPath(
        caminho(p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.black54,
      );
    }

    // o trator: um triângulo na antena, o cabeçalho e a barra rebocada
    final p = posicao;
    if (p == null) return;
    final h = p.rumo * math.pi / 180;
    final frente = Offset(math.sin(h), -math.cos(h)); // na tela, norte = cima
    final lado = Offset(math.cos(h), math.sin(h));
    final a = tela(p.e, p.n);
    final tam = math.max(4.0, 3 * k);
    canvas.drawPath(
      Path()
        ..moveTo((a + frente * tam * 1.6).dx, (a + frente * tam * 1.6).dy)
        ..lineTo(
          (a - frente * tam * 0.7 + lado * tam * 0.7).dx,
          (a - frente * tam * 0.7 + lado * tam * 0.7).dy,
        )
        ..lineTo(
          (a - frente * tam * 0.7 - lado * tam * 0.7).dx,
          (a - frente * tam * 0.7 - lado * tam * 0.7).dy,
        )
        ..close(),
      Paint()..color = const Color(0xFF1B5E20),
    );
    final b = barra;
    if (b == null) return;
    final hb = b.rumo * math.pi / 180;
    final centro = tela(b.e, b.n);
    final meia = Offset(math.cos(hb), math.sin(hb)) * (Barra.largura / 2) * k;
    canvas.drawLine(a, centro, Paint()..color = Colors.black45);
    canvas.drawLine(
      centro - meia,
      centro + meia,
      Paint()
        ..color = plantando ? const Color(0xFF00C853) : const Color(0xFFD50000)
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_Pintor antigo) =>
      antigo.imagem != imagem ||
      antigo.posicao != posicao ||
      antigo.barra != barra ||
      antigo.plantando != plantando ||
      antigo.modo != modo ||
      !identical(antigo.t, t);
}

/// A legenda do modo: as taxas do talhão, ou as classes do prescrito x aplicado.
class LegendaMapa extends StatelessWidget {
  const LegendaMapa({super.key, required this.modo, required this.talhao});
  final ModoMapa modo;
  final Talhao talhao;

  @override
  Widget build(BuildContext context) {
    final itens = <(Color, String)>[
      if (modo == ModoMapa.comparacao)
        for (final c in coresDaClasse.keys)
          (coresDaClasse[c]!, nomesDaClasse[c]!)
      else ...[
        for (final taxa in ({
          ...talhao.zonas.map((z) => z.taxa),
          if (talhao.zonas.isEmpty) talhao.taxaPadrao,
        }.toList()..sort()))
          (
            corDaTaxa(taxa),
            '${(taxa / 1000).toStringAsFixed(taxa % 1000 == 0 ? 0 : 1)} mil/ha',
          ),
        if (modo == ModoMapa.aplicado)
          (coresDaClasse[Classe.sobreposto]!, 'sobreposto'),
      ],
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final (cor, nome) in itens)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: cor,
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(width: 4),
              Text(nome, style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }
}

/// O relatório em tabela: por taxa prescrita e o total.
class TabelaRelatorio extends StatelessWidget {
  const TabelaRelatorio({super.key, required this.relatorio});
  final Relatorio relatorio;

  @override
  Widget build(BuildContext context) {
    String ha(double v) => v.toStringAsFixed(2);
    String mil(double v) => (v / 1000).toStringAsFixed(1);
    DataRow linha(LinhaRelatorio x) => DataRow(
      color: x.taxaPrescrita == null
          ? WidgetStatePropertyAll(Colors.grey.shade200)
          : null,
      cells: [
        DataCell(
          x.taxaPrescrita == null
              ? const Text(
                  'total',
                  style: TextStyle(fontWeight: FontWeight.bold),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: corDaTaxa(x.taxaPrescrita!),
                    ),
                    const SizedBox(width: 6),
                    Text('${x.taxaPrescrita}'),
                  ],
                ),
        ),
        DataCell(Text(ha(x.areaHa))),
        DataCell(
          Text(
            '${ha(x.aplicadaHa)} (${(x.cobertura * 100).toStringAsFixed(0)}%)',
          ),
        ),
        DataCell(Text(ha(x.certaHa))),
        DataCell(Text(ha(x.abaixoHa))),
        DataCell(Text(ha(x.acimaHa))),
        DataCell(Text(ha(x.sobrepostaHa))),
        DataCell(
          Text('${mil(x.sementesPrevistas)} / ${mil(x.sementesAplicadas)}'),
        ),
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowHeight: 40,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columns: const [
          DataColumn(label: Text('prescrita\n(sem/ha)')),
          DataColumn(label: Text('área\n(ha)')),
          DataColumn(label: Text('aplicada\n(ha)')),
          DataColumn(label: Text('na taxa\n(ha)')),
          DataColumn(label: Text('abaixo\n(ha)')),
          DataColumn(label: Text('acima\n(ha)')),
          DataColumn(label: Text('sobreposta\n(ha)')),
          DataColumn(label: Text('sementes, mil\nprevistas / aplicadas')),
        ],
        rows: [
          for (final x in relatorio.porTaxa) linha(x),
          linha(relatorio.total),
        ],
      ),
    );
  }
}
