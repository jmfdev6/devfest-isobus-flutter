// main.dart — o terminal da cabine em texto
//   s        sair
// [passo 9]
//   1..6     aperta a soft key 1..6 da tela atual do VT
//   t 3 11 20000   o TC manda um valor: elemento 3, DDI 11 (taxa alvo da plantadeira), 20000
// [/passo 9]
//   b 6000   aperta um botão da tela pelo ID do objeto
//   g        liga/desliga o TC automático (TC-GEO: taxa pelo mapa; TC-SEC: corte de seções)
//   l        limpa o mapa do que já foi plantado (para replantar o talhão)
import 'dart:convert';
import 'dart:io';

import 'package:agiso/agiso.dart';
import 'package:agiso/geo.dart';

void main(List<String> args) async {
  final agiso = Agiso();
  final tc = TcAutomatico(agiso);
  var gpsVistos = 0;
  int? ultimaTaxa;
  var ultimasSecoes = '';

  agiso.eventos.listen((evento) {
    switch (evento) {
      case Endereco(:final valor):
        print('DART| na rede como 0x${valor.toRadixString(16)}');
      case Rotacao(:final rpm):
        print('DART| motor a ${rpm.toStringAsFixed(0)} rpm');
      case Taxa(:final sementesPorHa):
        print('DART| taxa alvo $sementesPorHa sementes/ha');
      case Deposito(:final sementes):
        print('DART| depósito $sementes sementes');
      case Secoes(:final ligadas):
        print('DART| seções ${ligadas.map((l) => l ? '■' : '□').join()}');
      case Gps(:final lat, :final lon, :final rumo):
        // 10 por segundo: mostra um a cada 5 s
        if (gpsVistos++ % 50 == 0) {
          final p = tc.posicao;
          print(
            'DART| GPS ${lat.toStringAsFixed(7)} ${lon.toStringAsFixed(7)} '
            'rumo ${rumo.toStringAsFixed(0)}°'
            '${p == null ? '' : '  talhão e=${p.e.toStringAsFixed(1)} n=${p.n.toStringAsFixed(1)} m'}',
          );
        }
    }
    // o que o TC automático decidiu
    if (tc.ligado && tc.taxaMandada != ultimaTaxa) {
      ultimaTaxa = tc.taxaMandada;
      print('DART| GEO taxa da zona: $ultimaTaxa sementes/ha');
    }
    final pedidas = tc.pedidas.map((l) => l ? '■' : '□').join();
    if (tc.ligado && pedidas != ultimasSecoes) {
      ultimasSecoes = pedidas;
      print('DART| SEC seções pedidas $pedidas');
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
      // a tecla N é a N-ésima soft key da máscara que está na tela agora
      final teclas = (agiso.tela()?['teclas'] as List?) ?? [];
      if (tecla <= teclas.length) {
        final id = teclas[tecla - 1]['id'] as int;
        print('DART| apertando tecla $id: ${agiso.apertarTecla(id)}');
      } else {
        print('DART| a tela atual não tem a tecla $tecla');
      }
    }
    if (partes.first == 'l') {
      tc.limpar();
      print('DART| cobertura limpa');
    }
    if (partes.first == 'g') {
      tc.ligado = !tc.ligado;
      print('DART| TC automático ${tc.ligado ? 'LIGADO' : 'desligado'}');
    }
    if (partes.first == 'b' && partes.length == 2) {
      // um botão da tela pelo ID do objeto (ex.: b 6000 = switch da seção 1)
      final id = int.parse(partes[1]);
      print('DART| apertando botão $id: ${agiso.apertarTecla(id)}');
    }
    if (partes.first == 't' && partes.length == 4) {
      // elemento e DDI vêm do DDOP que o TC mostrou quando o implemento conectou
      final [elemento, ddi, valor] = partes.skip(1).map(int.parse).toList();
      print(
        'DART| TC: elemento $elemento DDI $ddi = $valor: '
        '${agiso.definirNoTc(elemento, ddi, valor)}',
      );
    }
    // [/passo 9]
  }
  agiso.parar();
}
