// agiso.dart — o Dart conversando com a ponte C
import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

// 1. Os tipos: cada função C ganha a visão do C e a visão do Dart
typedef CallbackC = Void Function(Int32 evento, Double valor);

typedef StartC =
    Int32 Function(
      Pointer<Utf8> interface,
      Pointer<NativeFunction<CallbackC>> cb,
    );
typedef StartDart =
    int Function(
      Pointer<Utf8> interface,
      Pointer<NativeFunction<CallbackC>> cb,
    );
typedef StopC = Void Function();
typedef StopDart = void Function();
// [passo 9]
typedef ApertarC = Int32 Function(Uint16 tecla);
typedef ApertarDart = int Function(int tecla);
typedef DefinirC = Int32 Function(Uint16 elemento, Uint16 ddi, Int32 valor);
typedef DefinirDart = int Function(int elemento, int ddi, int valor);
// [/passo 9]

// 2. Os eventos que o resto do app vai ver
sealed class Evento {}

class Endereco extends Evento {
  Endereco(this.valor);
  final int valor;
}

class Rotacao extends Evento {
  Rotacao(this.rpm);
  final double rpm;
}

// 3. A classe que esconde o FFI
class Agiso {
  Agiso(String caminhoDaSo) {
    final lib = DynamicLibrary.open(caminhoDaSo);
    _start = lib.lookupFunction<StartC, StartDart>('agiso_start');
    _stop = lib.lookupFunction<StopC, StopDart>('agiso_stop');
    // [passo 9]
    apertarTecla = lib.lookupFunction<ApertarC, ApertarDart>(
      'agiso_vt_apertar',
    );
    definirNoTc = lib.lookupFunction<DefinirC, DefinirDart>('agiso_tc_definir');
    // [/passo 9]
  }

  late final StartDart _start;
  late final StopDart _stop;
  // [passo 9]
  late final ApertarDart apertarTecla;
  late final DefinirDart definirNoTc;
  // [/passo 9]

  final _eventos = StreamController<Evento>.broadcast();
  Stream<Evento> get eventos => _eventos.stream;

  NativeCallable<CallbackC>? _callback;

  void iniciar(String interface) {
    // .listener: o C pode chamar de QUALQUER thread; a chamada entra na fila do Dart
    _callback = NativeCallable<CallbackC>.listener(_aoEvento);
    final nome = interface.toNativeUtf8();
    final rc = _start(nome, _callback!.nativeFunction);
    malloc.free(nome); // memória nativa: o GC não libera
    if (rc != 0) throw StateError('agiso_start falhou: $rc');
  }

  void _aoEvento(int evento, double valor) {
    if (evento == 1) _eventos.add(Endereco(valor.toInt()));
    if (evento == 2) _eventos.add(Rotacao(valor));
  }

  void parar() {
    _stop(); // primeiro o C para de chamar...
    _callback?.close(); // ...depois fechamos o callback
    _eventos.close();
  }
}
