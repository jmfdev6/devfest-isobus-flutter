// main.dart — a cabine em Flutter: a rotação (passo 6), a tela do VT e a taxa do TC (passos 9 e 10)
//
// O TC automático (TC-GEO e TC-SEC) trabalha por trás, sempre ligado: a taxa pela zona e
// o corte das seções, no talhão da demo (Talhao.padrao, o mesmo do simulador).
import 'package:flutter/material.dart';
import 'package:agiso/agiso.dart';
import 'package:agiso/geo.dart';

import 'tela_vt.dart';

final agiso = Agiso();
// GEO + SEC sempre ligados. Criado em main(): uma variável global do Dart só nasce no
// primeiro uso, e sem nada na tela usando o TC ele nunca ouviria o GPS.
late final TcAutomatico tc;

void main() {
  tc = TcAutomatico(agiso)..ligado = true;
  agiso.iniciar('vcan0');
  runApp(const MaterialApp(home: Cabine()));
}

class Cabine extends StatelessWidget {
  const Cabine({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cabine ISOBUS'),
        actions: [
          // A rede CAN vira um Stream; o StreamBuilder redesenha a cada evento
          StreamBuilder<Evento>(
            stream: agiso.eventos.where((e) => e is Rotacao),
            builder: (context, snapshot) {
              final evento = snapshot.data;
              final rpm = evento is Rotacao
                  ? evento.rpm.toStringAsFixed(0)
                  : '—';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$rpm rpm', style: const TextStyle(fontSize: 28)),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              // [passo 10]
              // A tela que o implemento mandou, desenhada como num terminal de verdade
              child: TelaVT(agiso: agiso),
              // [/passo 10]
            ),
          ),
          // [passo 9]
          // O TC manda a taxa alvo da plantadeira: elemento 3, DDI 11, em sementes/ha
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    if (agiso.definirNoTc(3, 11, 20000) != 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('TC: implemento ainda não conectou'),
                        ),
                      );
                    }
                  },
                  child: const Text('TC: 20 mil sementes/ha'),
                ),
                const SizedBox(width: 16),
                // o valor que o implemento devolveu: a prova de que a ordem chegou
                StreamBuilder<Evento>(
                  stream: agiso.eventos.where((e) => e is Taxa),
                  builder: (context, snapshot) {
                    final evento = snapshot.data;
                    final taxa = evento is Taxa
                        ? '${evento.sementesPorHa}'
                        : '—';
                    return Text(
                      'taxa alvo: $taxa sementes/ha',
                      style: const TextStyle(fontSize: 20),
                    );
                  },
                ),
                const SizedBox(width: 24),
                // o depósito desce enquanto as seções plantam
                StreamBuilder<Evento>(
                  stream: agiso.eventos.where((e) => e is Deposito),
                  builder: (context, snapshot) {
                    final evento = snapshot.data;
                    final n = evento is Deposito ? '${evento.sementes}' : '—';
                    return Text(
                      'depósito: $n sementes',
                      style: const TextStyle(fontSize: 20),
                    );
                  },
                ),
              ],
            ),
          ),
          // [/passo 9]
          // O TC corta e liga as seções da barra (elemento 2). Os chips mostram o estado
          // REAL que a plantadeira devolve, não o que pedimos.
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: StreamBuilder<Evento>(
              stream: agiso.eventos.where((e) => e is Secoes),
              builder: (context, snapshot) {
                final evento = snapshot.data;
                if (evento is! Secoes) {
                  return const Text('seções: aguardando o implemento');
                }
                final ligadas = evento.ligadas;
                void pedir(List<bool> desejo) {
                  var setpoint = 0; // 2 bits por seção, 01 = liga
                  for (var i = 0; i < desejo.length; i++) {
                    if (desejo[i]) setpoint |= 1 << (2 * i);
                  }
                  agiso.definirNoTc(
                    2,
                    160,
                    1,
                  ); // automático: quem manda nas seções é o TC
                  agiso.definirNoTc(2, 290, setpoint);
                }

                return Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Seções pelo TC:',
                      style: TextStyle(fontSize: 20),
                    ),
                    for (var i = 0; i < ligadas.length; i++)
                      FilterChip(
                        label: Text('S${i + 1}'),
                        selected: ligadas[i],
                        onSelected: (liga) => pedir([
                          for (var j = 0; j < ligadas.length; j++)
                            j == i ? liga : ligadas[j],
                        ]),
                      ),
                    ActionChip(
                      label: const Text('liga todas'),
                      onPressed: () => pedir(List.filled(ligadas.length, true)),
                    ),
                    ActionChip(
                      label: const Text('corta todas'),
                      onPressed: () =>
                          pedir(List.filled(ligadas.length, false)),
                    ),
                    ActionChip(
                      label: const Text('devolver ao VT (manual)'),
                      onPressed: () => agiso.definirNoTc(2, 160, 0),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
