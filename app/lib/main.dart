// main.dart — a cabine em Flutter: a rotação (passo 6), teclas do VT e taxa do TC (passo 9)
import 'package:flutter/material.dart';
import 'package:live_agiso/agiso.dart';

final agiso = Agiso('../build/libagiso.so');

void main() {
  agiso.iniciar('vcan0');
  runApp(const MaterialApp(home: Cabine()));
}

class Cabine extends StatelessWidget {
  const Cabine({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cabine ISOBUS')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A rede CAN vira um Stream; o StreamBuilder redesenha a cada evento
            StreamBuilder<Evento>(
              stream: agiso.eventos.where((e) => e is Rotacao),
              builder: (context, snapshot) {
                final evento = snapshot.data;
                final rpm = evento is Rotacao
                    ? evento.rpm.toStringAsFixed(0)
                    : '—';
                return Text('$rpm rpm', style: const TextStyle(fontSize: 64));
              },
            ),
            // [passo 9]
            const SizedBox(height: 24),
            // As 6 soft keys do VT: o VT só avisa o implemento
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 6; i++)
                  FilledButton(
                    onPressed: () => agiso.apertarTecla(5000 + i),
                    child: Text('Tecla $i'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // O TC manda a taxa: elemento 2, DDI 1, em mm³/m²
            OutlinedButton(
              onPressed: () => agiso.definirNoTc(2, 1, 200 * 100),
              child: const Text('TC: taxa 200 L/ha'),
            ),
            // [/passo 9]
          ],
        ),
      ),
    );
  }
}
