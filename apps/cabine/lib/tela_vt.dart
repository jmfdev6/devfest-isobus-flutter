// tela_vt.dart — desenha a tela do Terminal Virtual (passo 10)
//
// O C++ já percorreu o object pool do implemento e entregou uma lista de
// desenho em JSON, com coordenadas absolutas e cores em RGB. Aqui só desenhamos:
//   re = retângulo, el = elipse, ln = linha, tx = texto, pi = figura,
//   me = medidor, bt = área de toque
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:agiso/agiso.dart';

typedef Op = Map<String, dynamic>;

class TelaVT extends StatefulWidget {
  const TelaVT({super.key, required this.agiso});
  final Agiso agiso;

  @override
  State<TelaVT> createState() => _TelaVTState();
}

class _TelaVTState extends State<TelaVT> {
  Timer? _relogio;
  String? _json;
  Map<String, dynamic>? _tela;
  final _figuras = <int, ui.Image>{};
  final _pedidas = <int>{};
  int? _implemento;

  @override
  void initState() {
    super.initState();
    // 10 vezes por segundo: pergunta ao C++ se a tela mudou
    _relogio = Timer.periodic(const Duration(milliseconds: 100), (_) => _ler());
  }

  @override
  void dispose() {
    _relogio?.cancel();
    for (final f in _figuras.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _ler() {
    final json = widget.agiso.telaJson();
    if (json == _json) return;
    final tela = json == null ? null : jsonDecode(json) as Map<String, dynamic>;
    // outro implemento (ou nenhum): as figuras antigas não valem mais
    if (tela?['ws'] != _implemento) {
      _implemento = tela?['ws'] as int?;
      _figuras.clear();
      _pedidas.clear();
    }
    setState(() {
      _json = json;
      _tela = tela;
    });
    if (tela != null) _carregarFiguras(tela);
  }

  // Cada figura vem uma vez só, em RGBA, e vira uma ui.Image
  void _carregarFiguras(Map<String, dynamic> tela) {
    final ops = <Op>[
      ...(tela['ops'] as List).cast<Op>(),
      for (final t in tela['teclas'] as List) ...(t['ops'] as List).cast<Op>(),
    ];
    for (final op in ops) {
      final id = op['id'] as int?;
      if (op['t'] != 'pi' || id == null || !_pedidas.add(id)) continue;
      final f = widget.agiso.figura(id);
      if (f == null) {
        _pedidas.remove(id); // ainda não convertida: tenta no próximo ciclo
        continue;
      }
      ui.decodeImageFromPixels(
        f.rgba,
        f.largura,
        f.altura,
        ui.PixelFormat.rgba8888,
        (imagem) {
          if (mounted) setState(() => _figuras[id] = imagem);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tela = _tela;
    if (tela == null) {
      return const Center(child: Text('Aguardando um implemento na rede…'));
    }
    final lado = (tela['lado'] as int).toDouble();
    final ladoTecla = (tela['tecla'] as int).toDouble();
    final ops = (tela['ops'] as List).cast<Op>();
    final teclas = (tela['teclas'] as List).cast<Map<String, dynamic>>();

    // Tudo em pixels do VT (480 + teclas); o FittedBox escala para a janela
    return FittedBox(
      child: SizedBox(
        width: lado + 8 + ladoTecla,
        height: lado,
        child: Row(
          children: [
            GestureDetector(
              onTapUp: (d) => _tocar(ops, d.localPosition),
              child: CustomPaint(
                size: Size(lado, lado),
                painter: PintorVT(ops, _figuras, _figuras.length, _json),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                for (final t in teclas)
                  GestureDetector(
                    onTap: () => widget.agiso.apertarTecla(t['id'] as int),
                    child: CustomPaint(
                      size: Size(ladoTecla, ladoTecla),
                      painter: PintorVT(
                        (t['ops'] as List).cast<Op>(),
                        _figuras,
                        _figuras.length,
                        _json,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // O último botão desenhado por cima é o que recebe o toque
  void _tocar(List<Op> ops, Offset p) {
    for (final op in ops.reversed) {
      if (op['t'] == 'bt' && _retangulo(op).contains(p)) {
        widget.agiso.apertarTecla(op['id'] as int);
        return;
      }
    }
  }
}

Rect _retangulo(Op op) => Rect.fromLTWH(
  (op['x'] as int).toDouble(),
  (op['y'] as int).toDouble(),
  (op['w'] as int).toDouble(),
  (op['h'] as int).toDouble(),
);

Color _cor(int rgb) => Color(0xFF000000 | rgb);

class PintorVT extends CustomPainter {
  PintorVT(this.ops, this.figuras, this.nFiguras, this.versao);
  final List<Op> ops;
  final Map<int, ui.Image> figuras;
  final int nFiguras; // para redesenhar quando uma figura nova chega
  final String? versao; // o JSON: mudou, redesenha

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final op in ops) {
      switch (op['t']) {
        case 're':
          _pintarRetangulo(canvas, op);
        case 'el':
          _elipse(canvas, op);
        case 'ln':
          _linha(canvas, op);
        case 'tx':
          _texto(canvas, op);
        case 'pi':
          final f = figuras[op['id']];
          if (f != null) {
            canvas.drawImageRect(
              f,
              Rect.fromLTWH(0, 0, f.width.toDouble(), f.height.toDouble()),
              _retangulo(op),
              Paint()..filterQuality = FilterQuality.none, // pixels nítidos
            );
          }
        case 'me':
          _medidor(canvas, op);
      }
    }
  }

  Paint _traco(int cor, num espessura) => Paint()
    ..color = _cor(cor)
    ..style = PaintingStyle.stroke
    ..strokeWidth = espessura.toDouble();

  void _pintarRetangulo(Canvas canvas, Op op) {
    final r = _retangulo(op);
    final int f = op['f'], l = op['l'], lw = op['lw'], ls = op['ls'];
    if (f >= 0) canvas.drawRect(r, Paint()..color = _cor(f));
    if (l < 0 || lw <= 0) return;
    final traco = _traco(l, lw);
    final d = r.deflate(lw / 2);
    if (ls == 0) {
      canvas.drawRect(d, traco);
      return;
    }
    // bits de supressão: 0 = topo, 1 = direita, 2 = base, 3 = esquerda
    if (ls & 1 == 0) canvas.drawLine(d.topLeft, d.topRight, traco);
    if (ls & 2 == 0) canvas.drawLine(d.topRight, d.bottomRight, traco);
    if (ls & 4 == 0) canvas.drawLine(d.bottomLeft, d.bottomRight, traco);
    if (ls & 8 == 0) canvas.drawLine(d.topLeft, d.bottomLeft, traco);
  }

  // Ângulos do VT: graus, 0 = leste (3 horas), crescendo no sentido anti-horário.
  // No Canvas o sentido é horário, por isso o sinal trocado.
  static double _rad(num graus) => -graus * math.pi / 180;
  static double _volta(num graus) {
    final g = graus % 360;
    return g == 0 ? 360 : g.toDouble();
  }

  void _elipse(Canvas canvas, Op op) {
    final r = _retangulo(op);
    final int f = op['f'], l = op['l'], lw = op['lw'], ty = op['ty'];
    final path = Path();
    if (ty == 0) {
      path.addOval(r);
    } else {
      final inicio = _rad(op['a0'] as int);
      final varredura = _rad(_volta((op['a1'] as int) - (op['a0'] as int)));
      if (ty == 3) path.moveTo(r.center.dx, r.center.dy); // fatia de pizza
      path.arcTo(r, inicio, varredura, ty != 3);
      if (ty != 1) path.close(); // 1 = arco aberto
    }
    if (f >= 0 && ty != 1) canvas.drawPath(path, Paint()..color = _cor(f));
    if (l >= 0 && lw > 0) canvas.drawPath(path, _traco(l, lw));
  }

  void _linha(Canvas canvas, Op op) {
    final r = _retangulo(op);
    final int c = op['c'], lw = op['lw'];
    if (c < 0 || lw <= 0) return;
    // direção 0 = de cima-esquerda para baixo-direita; 1 = de baixo-esquerda para cima-direita
    op['d'] == 0
        ? canvas.drawLine(r.topLeft, r.bottomRight, _traco(c, lw))
        : canvas.drawLine(r.bottomLeft, r.topRight, _traco(c, lw));
  }

  void _medidor(Canvas canvas, Op op) {
    final r = _retangulo(op);
    final centro = r.center;
    final raio = r.width / 2;
    final int o = op['o'], a0 = op['a0'], a1 = op['a1'];
    // O arco vai de a0 até a1 no sentido anti-horário. Bit 3 = deflexão horária:
    // aí o mínimo fica em a1 e o ponteiro anda no sentido horário até a0.
    final horario = o & 8 != 0;
    final abertura = _volta(a1 - a0);
    Offset ponto(double fracao, double distancia) {
      final ang = _rad(
        horario ? a1 - fracao * abertura : a0 + fracao * abertura,
      );
      return centro + Offset(math.cos(ang), math.sin(ang)) * distancia;
    }

    if (o & 2 != 0) canvas.drawCircle(centro, raio - 1, _traco(op['bc'], 2));
    if (o & 1 != 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raio * 0.9),
        _rad(a0),
        _rad(abertura),
        false,
        _traco(op['ac'], 2),
      );
    }
    final int ticks = op['ti'];
    if (o & 4 != 0) {
      for (var i = 0; i < ticks; i++) {
        final fr = ticks == 1 ? 0.0 : i / (ticks - 1);
        canvas.drawLine(
          ponto(fr, raio * 0.75),
          ponto(fr, raio * 0.9),
          _traco(op['ac'], 2),
        );
      }
    }
    final int min = op['min'], max = op['max'], v = op['v'];
    final fracao = max == min ? 0.0 : ((v - min) / (max - min)).clamp(0.0, 1.0);
    canvas.drawLine(centro, ponto(fracao, raio * 0.85), _traco(op['nc'], 3));
  }

  // As fontes do VT são bitmaps de largura fixa (ex.: 8x12). Usamos uma fonte
  // monoespaçada com a altura certa e esticamos na horizontal até a largura certa.
  static final _larguraLetra = <String, double>{};

  void _texto(Canvas canvas, Op op) {
    final r = _retangulo(op);
    final int fw = op['fw'], fh = op['fh'], st = op['st'];
    var frente = _cor(op['c'] as int);
    final int bgRgb = op['bg'];
    Color? fundo = bgRgb >= 0 ? _cor(bgRgb) : null;
    if (st & 16 != 0 && fundo != null) {
      (frente, fundo) = (fundo, frente); // invertido
    }
    if (fundo != null) canvas.drawRect(r, Paint()..color = fundo);

    final estilo = TextStyle(
      fontFamily: 'monospace',
      fontSize: fh * 0.85,
      height: 1 / 0.85, // cada linha ocupa exatamente fh pixels
      color: frente,
      fontWeight: st & 1 != 0 ? FontWeight.bold : FontWeight.normal,
      fontStyle: st & 8 != 0 ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (st & 2 != 0) TextDecoration.lineThrough,
        if (st & 4 != 0) TextDecoration.underline,
      ]),
    );
    final chave = '$fh/${st & 1}';
    final larguraLetra = _larguraLetra.putIfAbsent(chave, () {
      final tp = TextPainter(
        text: TextSpan(text: 'M', style: estilo),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp.width;
    });
    final esticar = fw / larguraLetra;

    final int hj = op['hj'], vj = op['vj'];
    final alinhamento = [
      TextAlign.left,
      TextAlign.center,
      TextAlign.right,
    ][hj.clamp(0, 2)];
    final texto = (op['s'] as String)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final tp = TextPainter(
      text: TextSpan(text: texto, style: estilo),
      textAlign: alinhamento,
      textDirection: TextDirection.ltr,
    );
    final larguraCaixa = r.width / esticar;
    // com quebra automática, o texto ocupa a caixa toda; sem ela, corta na borda
    op['wr'] == 1
        ? tp.layout(minWidth: larguraCaixa, maxWidth: larguraCaixa)
        : tp.layout();
    final largura = tp.width * esticar;
    final dx = op['wr'] == 1
        ? 0.0
        : [0.0, (r.width - largura) / 2, r.width - largura][hj.clamp(0, 2)];
    final dy = [
      0.0,
      (r.height - tp.height) / 2,
      r.height - tp.height,
    ][vj.clamp(0, 2)];

    canvas.save();
    canvas.clipRect(r);
    canvas.translate(r.left + dx, r.top + dy);
    canvas.scale(esticar, 1);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
    tp.dispose();
  }

  @override
  bool shouldRepaint(PintorVT antigo) =>
      antigo.versao != versao || antigo.nFiguras != nFiguras;
}
