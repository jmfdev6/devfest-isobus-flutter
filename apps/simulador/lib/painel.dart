// painel.dart — o volante e os instrumentos do simulador
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// O volante: arraste girando em volta do centro. Acumula voltas (o de um trator dá
/// 1,5 volta para cada lado) e tem o pomo de manobra, para girar com uma mão só.
class Volante extends StatefulWidget {
  const Volante({
    super.key,
    required this.angulo,
    required this.aoGirar,
    this.tamanho = 230,
  });

  /// Graus no volante (positivo = direita).
  final double angulo;

  /// Recebe quantos graus o operador girou desde o último toque.
  final void Function(double graus, {required bool soltou}) aoGirar;
  final double tamanho;

  @override
  State<Volante> createState() => _VolanteState();
}

class _VolanteState extends State<Volante> {
  double? _ultimo;

  double _anguloDoToque(Offset p) {
    final c = Offset(widget.tamanho / 2, widget.tamanho / 2);
    return math.atan2(p.dy - c.dy, p.dx - c.dx) * 180 / math.pi;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _ultimo = _anguloDoToque(d.localPosition),
      onPanUpdate: (d) {
        final agora = _anguloDoToque(d.localPosition);
        // a menor diferença entre os dois ângulos (passar por ±180° não pula)
        final delta = (agora - _ultimo! + 540) % 360 - 180;
        _ultimo = agora;
        widget.aoGirar(delta, soltou: false);
      },
      onPanEnd: (_) => widget.aoGirar(0, soltou: true),
      child: CustomPaint(
        size: Size.square(widget.tamanho),
        painter: _PintorVolante(widget.angulo),
      ),
    );
  }
}

class _PintorVolante extends CustomPainter {
  _PintorVolante(this.angulo);
  final double angulo;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 10;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angulo * math.pi / 180);
    final aro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..color = const Color(0xFF1E1E1E);
    canvas.drawCircle(Offset.zero, r, aro);
    canvas.drawCircle(
      Offset.zero,
      r,
      aro
        ..strokeWidth = 2
        ..color = const Color(0xFF555555),
    );
    // três raios e o cubo
    final raio = Paint()
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2B2B2B);
    for (final a in [90.0, 210.0, 330.0]) {
      final ang = a * math.pi / 180;
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(ang), math.sin(ang)) * r,
        raio,
      );
    }
    canvas.drawCircle(
      Offset.zero,
      r * 0.28,
      Paint()..color = const Color(0xFF2E7D32),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF1B5E20),
    );
    // a marca do centro (12 h) e o pomo de manobra
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, -r), width: 8, height: 18),
      Paint()..color = const Color(0xFFFFC107),
    );
    final pomo = Offset(math.cos(-0.5), math.sin(-0.5)) * r;
    canvas.drawCircle(pomo, 13, Paint()..color = const Color(0xFF111111));
    canvas.drawCircle(pomo, 7, Paint()..color = const Color(0xFF444444));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorVolante antigo) => antigo.angulo != angulo;
}

/// Velocímetro, conta-giros e marcha, como no painel de um trator.
class Instrumentos extends StatelessWidget {
  const Instrumentos({
    super.key,
    required this.kmh,
    required this.rpm,
    required this.re,
  });
  final double kmh, rpm;
  final bool re;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE0101418),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A4048), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(150),
              painter: _Mostrador(
                valor: kmh.abs(),
                maximo: 20,
                marcas: 4,
                unidade: 'km/h',
                texto: kmh.abs().toStringAsFixed(1),
              ),
            ),
            const SizedBox(width: 6),
            CustomPaint(
              size: const Size.square(150),
              painter: _Mostrador(
                valor: rpm / 100,
                maximo: 25,
                marcas: 5,
                unidade: 'rpm x100',
                texto: rpm.toStringAsFixed(0),
                vermelhoDe: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Marcha('F', ativa: !re),
                const SizedBox(height: 6),
                _Marcha('R', ativa: re),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Marcha extends StatelessWidget {
  const _Marcha(this.letra, {required this.ativa});
  final String letra;
  final bool ativa;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: ativa
          ? (letra == 'R' ? const Color(0xFFFF6F00) : const Color(0xFF2E7D32))
          : const Color(0xFF263238),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      letra,
      style: TextStyle(
        color: ativa ? Colors.white : Colors.white38,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _Mostrador extends CustomPainter {
  _Mostrador({
    required this.valor,
    required this.maximo,
    required this.marcas,
    required this.unidade,
    required this.texto,
    this.vermelhoDe,
  });
  final double valor, maximo;
  final int marcas;
  final String unidade, texto;
  final double? vermelhoDe;

  static const _inicio = 135.0,
      _arco = 270.0; // graus, como um mostrador de carro

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    double angulo(double v) =>
        (_inicio + _arco * (v / maximo).clamp(0, 1)) * math.pi / 180;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      angulo(0),
      _arco * math.pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white24,
    );
    if (vermelhoDe != null) {
      canvas.drawArc(
        rect,
        angulo(vermelhoDe!),
        angulo(maximo) - angulo(vermelhoDe!),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = const Color(0xFFD32F2F),
      );
    }
    final passo = maximo / marcas;
    for (var v = 0.0; v <= maximo + 1e-9; v += passo) {
      final a = angulo(v);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + dir * (r - 10),
        c + dir * r,
        Paint()
          ..strokeWidth = 2
          ..color = Colors.white70,
      );
      final rotulo = TextPainter(
        text: TextSpan(
          text: v.toStringAsFixed(0),
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rotulo.paint(
        canvas,
        c + dir * (r - 22) - Offset(rotulo.width / 2, rotulo.height / 2),
      );
    }
    // o ponteiro
    final a = angulo(valor);
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * (r - 6),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFF7043),
    );
    canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFFF7043));
    for (final (t, dy, tam) in [(texto, 26.0, 20.0), (unidade, 48.0, 10.0)]) {
      final p = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(
            color: Colors.white,
            fontSize: tam,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, c + Offset(-p.width / 2, dy - p.height / 2));
    }
  }

  @override
  bool shouldRepaint(_Mostrador antigo) =>
      antigo.valor != valor || antigo.texto != texto;
}

/// A barra de luz do piloto: os LEDs acendem para o lado em que o trator está fora da
/// linha (5 cm por LED); verde no meio, âmbar e vermelho nas pontas.
class BarraDeLuz extends StatelessWidget {
  const BarraDeLuz({super.key, required this.estado, this.erro, this.linha});

  /// O que mostrar embaixo: engatado, pronto, desengatado...
  final String estado;

  /// Desvio em metros (positivo = trator à direita da linha), ou null sem piloto.
  final double? erro;
  final int? linha;

  static const _leds = 15, _cmPorLed = 5.0;

  @override
  Widget build(BuildContext context) {
    final centro = _leds ~/ 2;
    final aceso = erro == null
        ? null
        : centro + (erro! * 100 / _cmPorLed).round().clamp(-centro, centro);
    Color cor(int i) {
      final distancia = (i - centro).abs();
      if (distancia == 0) return const Color(0xFF00E676);
      if (distancia <= 3) return const Color(0xFFFFC400);
      return const Color(0xFFFF1744);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE0101418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A4048), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _leds; i++)
                  Container(
                    width: i == centro ? 22 : 16,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == aceso
                          ? cor(i)
                          : cor(i).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: i == aceso
                          ? [BoxShadow(color: cor(i), blurRadius: 10)]
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                estado,
                if (linha != null) 'linha $linha',
                if (erro != null)
                  '${(erro!.abs() * 100).toStringAsFixed(1)} cm ${erro! >= 0 ? 'à direita' : 'à esquerda'}',
              ].join('  ·  '),
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
