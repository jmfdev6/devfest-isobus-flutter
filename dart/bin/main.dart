// main.dart — o terminal da cabine em texto
//   s        sair
// [passo 9]
//   1..6     aperta a soft key 1..6 do VT
//   t 200    o TC manda a taxa 200 L/ha
// [/passo 9]
import 'dart:convert';
import 'dart:io';

import 'package:live_agiso/agiso.dart';

void main(List<String> args) async {
  final agiso = Agiso('../build/libagiso.so');

  agiso.eventos.listen((evento) {
    switch (evento) {
      case Endereco(:final valor):
        print('DART| na rede como 0x${valor.toRadixString(16)}');
      case Rotacao(:final rpm):
        print('DART| motor a ${rpm.toStringAsFixed(0)} rpm');
    }
  });

  agiso.iniciar(args.isEmpty ? 'vcan0' : args.first);

  await for (final linha
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final partes = linha.trim().split(' ');
    if (partes.first == 's') break;
    // [passo 9]
    final tecla = int.tryParse(partes.first);
    if (tecla != null && tecla >= 1 && tecla <= 6) {
      // as teclas do pulverizador têm IDs 5001..5006 no object pool
      print(
        'DART| apertando tecla ${5000 + tecla}: ${agiso.apertarTecla(5000 + tecla)}',
      );
    }
    if (partes.first == 't' && partes.length == 2) {
      final lha = int.parse(partes[1]);
      // elemento 2 (tanque), DDI 1 (taxa alvo) em mm³/m²: 1 L/ha = 100
      print('DART| TC: taxa $lha L/ha: ${agiso.definirNoTc(2, 1, lha * 100)}');
    }
    // [/passo 9]
  }
  agiso.parar();
}
