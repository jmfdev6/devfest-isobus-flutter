// controle_usb.dart — volante ou gamepad USB, lido direto da API de joystick do Linux
//
// /dev/input/js0 manda eventos de 8 bytes: tempo (u32), valor (s16), tipo (u8), número (u8).
// Tipo 1 = botão, 2 = eixo (de -32767 a 32767); o bit 0x80 marca o estado inicial.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class ControleUsb {
  // ponytail: o mapa de um gamepad comum (Xbox/PS no driver xpad/hid). Para um volante
  // com pedais (ex.: Logitech G29): volante 0, acelerador 2, freio 3, e pedalInvertido = true.
  static const eixoVolante = 0;
  static const eixoAcelerador = 5; // gatilho direito
  static const eixoFreio = 2; // gatilho esquerdo
  static const botaoSentido = 0; // A / X: troca frente e ré
  static const botaoCamera = 3; // Y / triângulo: troca a câmera
  static const pedalInvertido =
      false; // pedais que mandam 32767 soltos e -32767 no fundo

  /// O volante de -1 (esquerda) a 1 (direita); acelerador e freio de 0 a 1.
  double volante = 0, acelerador = 0, freio = 0;
  bool conectado = false;
  void Function(int botao)? aoApertar;

  StreamSubscription<List<int>>? _leitura;
  final _resto = <int>[];

  /// Procura o primeiro joystick; sem um (ou sem permissão de leitura), segue sem ele.
  void abrir([String caminho = '/dev/input/js0']) {
    final arquivo = File(caminho);
    if (!arquivo.existsSync()) return;
    _leitura = arquivo.openRead().listen(
      _bytes,
      onError: (_) => conectado = false,
      onDone: () => conectado = false,
      cancelOnError: true,
    );
    conectado = true;
  }

  void _bytes(List<int> pedaco) {
    _resto.addAll(pedaco);
    while (_resto.length >= 8) {
      final ev = ByteData.sublistView(Uint8List.fromList(_resto.sublist(0, 8)));
      _resto.removeRange(0, 8);
      final valor = ev.getInt16(4, Endian.little);
      final tipo = ev.getUint8(6) & 0x7F;
      final numero = ev.getUint8(7);
      if (tipo == 2) _eixo(numero, valor / 32767);
      if (tipo == 1 && valor == 1 && (ev.getUint8(6) & 0x80) == 0) {
        aoApertar?.call(numero);
      }
    }
  }

  // gatilhos vão de -1 (solto) a 1 (no fundo); pedais invertidos, ao contrário
  static double _pedal(double v) => ((pedalInvertido ? -v : v) + 1) / 2;

  void _eixo(int numero, double v) {
    if (numero == eixoVolante) volante = v;
    if (numero == eixoAcelerador) acelerador = _pedal(v);
    if (numero == eixoFreio) freio = _pedal(v);
  }

  void fechar() => _leitura?.cancel();
}
