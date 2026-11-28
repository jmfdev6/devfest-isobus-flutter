// agiso.dart — o Dart conversando com a ponte C
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

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
typedef MoverC =
    Void Function(Double lat, Double lon, Double rumo, Double vel, Double rpm);
typedef MoverDart =
    void Function(double lat, double lon, double rumo, double vel, double rpm);
typedef StopC = Void Function();
typedef StopDart = void Function();
// [passo 9]
typedef ApertarC = Int32 Function(Uint16 tecla);
typedef ApertarDart = int Function(int tecla);
typedef DefinirC = Int32 Function(Uint16 elemento, Uint16 ddi, Int32 valor);
typedef DefinirDart = int Function(int elemento, int ddi, int valor);
// [/passo 9]
// [passo 10]
typedef TelaC = Int32 Function(Pointer<Uint8> destino, Int32 tamanho);
typedef TelaDart = int Function(Pointer<Uint8> destino, int tamanho);
typedef FiguraC =
    Int32 Function(
      Uint16 id,
      Pointer<Uint8> rgba,
      Int32 tamanho,
      Pointer<Int32> largura,
      Pointer<Int32> altura,
    );
typedef FiguraDart =
    int Function(
      int id,
      Pointer<Uint8> rgba,
      int tamanho,
      Pointer<Int32> largura,
      Pointer<Int32> altura,
    );
// [/passo 10]

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

class Taxa extends Evento {
  Taxa(this.sementesPorHa);
  final int sementesPorHa;
}

class Deposito extends Evento {
  Deposito(this.sementes);
  final int sementes;
}

/// Posição do GPS (NMEA 2000): graus, rumo em graus (0 = norte, horário), velocidade em m/s.
class Gps extends Evento {
  Gps(this.lat, this.lon, this.rumo, this.velocidade);
  final double lat, lon, rumo, velocidade;
}

class Secoes extends Evento {
  Secoes(this.bits);
  final int bits; // 2 bits por seção: 00 desligada, 01 ligada, 11 não existe

  /// Uma entrada por seção que existe: true = ligada.
  List<bool> get ligadas => [
    for (var i = 0; i < 16 && ((bits >> 2 * i) & 3) != 3; i++)
      ((bits >> 2 * i) & 3) == 1,
  ];
}

/// Onde está a libagiso.so: a variável AGISO_LIB, ou a pasta build/ do projeto, que se
/// acha subindo a partir da pasta atual ou do executável. Assim os apps rodam de
/// qualquer pasta (com `flutter run`, pelo executável compilado ou pelo demo.sh).
String acharPonte() {
  final variavel = Platform.environment['AGISO_LIB'];
  if (variavel != null && File(variavel).existsSync()) return variavel;
  for (final inicio in [
    Directory.current.path,
    File(Platform.resolvedExecutable).parent.path,
  ]) {
    var pasta = Directory(inicio).absolute;
    for (var i = 0; i < 10; i++) {
      final candidata = File('${pasta.path}/build/libagiso.so');
      if (candidata.existsSync()) return candidata.path;
      if (pasta.parent.path == pasta.path) break;
      pasta = pasta.parent;
    }
  }
  throw StateError(
    'não achei a libagiso.so: compile a ponte (./demo.sh preparar, ou cmake --build build) '
    'ou aponte AGISO_LIB para ela',
  );
}

// 3. A classe que esconde o FFI
class Agiso {
  /// [caminhoDaSo]: a ponte compilada. Sem ele, procura sozinha (veja [acharPonte]).
  Agiso([String? caminhoDaSo]) {
    final lib = DynamicLibrary.open(caminhoDaSo ?? acharPonte());
    _start = lib.lookupFunction<StartC, StartDart>('agiso_start');
    _startOuvinte = lib.lookupFunction<StartC, StartDart>(
      'agiso_start_ouvinte',
    );
    _startTrator = lib.lookupFunction<StartC, StartDart>('agiso_start_trator');
    moverTrator = lib.lookupFunction<MoverC, MoverDart>('agiso_trator_mover');
    _stop = lib.lookupFunction<StopC, StopDart>('agiso_stop');
    // [passo 9]
    apertarTecla = lib.lookupFunction<ApertarC, ApertarDart>(
      'agiso_vt_apertar',
    );
    definirNoTc = lib.lookupFunction<DefinirC, DefinirDart>('agiso_tc_definir');
    // [/passo 9]
    // [passo 10]
    _tela = lib.lookupFunction<TelaC, TelaDart>('agiso_vt_tela');
    _figura = lib.lookupFunction<FiguraC, FiguraDart>('agiso_vt_figura');
    // [/passo 10]
  }

  late final StartDart _start;
  late final StartDart _startOuvinte;
  late final StartDart _startTrator;

  /// Modo trator: onde o trator está (graus, rumo em graus, m/s com ré negativa, rpm).
  /// A ponte manda o GPS NMEA 2000, a velocidade de solo e a rotação do motor.
  late final MoverDart moverTrator;
  late final StopDart _stop;
  // [passo 9]
  late final ApertarDart apertarTecla;
  late final DefinirDart definirNoTc;
  // [/passo 9]
  // [passo 10]
  late final TelaDart _tela;
  late final FiguraDart _figura;
  var _capacidade = 64 * 1024;
  var _buffer = malloc<Uint8>(64 * 1024);

  // Chama a função C; se o buffer for pequeno, aumenta e chama de novo
  int _copiar(int Function(Pointer<Uint8> destino, int tamanho) funcao) {
    var n = funcao(_buffer, _capacidade);
    if (n > _capacidade) {
      malloc.free(_buffer);
      _capacidade = n * 2;
      _buffer = malloc<Uint8>(_capacidade);
      n = funcao(_buffer, _capacidade);
    }
    return n > _capacidade ? -1 : n;
  }

  /// A tela do VT em JSON (lista de desenho), ou null sem implemento.
  String? telaJson() {
    final n = _copiar(_tela);
    return n < 0 ? null : utf8.decode(_buffer.asTypedList(n));
  }

  Map<String, dynamic>? tela() {
    final json = telaJson();
    return json == null ? null : jsonDecode(json) as Map<String, dynamic>;
  }

  /// Uma figura da tela: largura, altura e os pixels em RGBA.
  ({int largura, int altura, Uint8List rgba})? figura(int id) {
    final medidas = malloc<Int32>(2);
    try {
      final n = _copiar((p, t) => _figura(id, p, t, medidas, medidas + 1));
      if (n < 0) return null;
      return (
        largura: medidas[0],
        altura: medidas[1],
        rgba: Uint8List.fromList(_buffer.asTypedList(n)),
      );
    } finally {
      malloc.free(medidas);
    }
  }
  // [/passo 10]

  final _eventos = StreamController<Evento>.broadcast();
  Stream<Evento> get eventos => _eventos.stream;

  NativeCallable<CallbackC>? _callback;

  /// A cabine: entra na rede com VT e TC.
  void iniciar(String interface) => _iniciar(interface, _start, 'agiso_start');

  /// Só escuta (GPS, rotação, seções), sem VT nem TC: para rodar ao lado da cabine.
  void iniciarOuvinte(String interface) =>
      _iniciar(interface, _startOuvinte, 'agiso_start_ouvinte');

  /// O simulador dirigível: escuta como o ouvinte e é o trator na rede.
  void iniciarTrator(String interface) =>
      _iniciar(interface, _startTrator, 'agiso_start_trator');

  void _iniciar(String interface, StartDart funcao, String nomeC) {
    // .listener: o C pode chamar de QUALQUER thread; a chamada entra na fila do Dart
    _callback = NativeCallable<CallbackC>.listener(_aoEvento);
    final nome = interface.toNativeUtf8();
    final rc = funcao(nome, _callback!.nativeFunction);
    malloc.free(nome); // memória nativa: o GC não libera
    if (rc != 0) throw StateError('$nomeC falhou: $rc');
  }

  // o GPS chega em pedaços (lat, lon, rumo, velocidade); juntamos num evento só
  var _lat = 0.0, _rumo = 0.0, _velocidade = 0.0;

  void _aoEvento(int evento, double valor) {
    if (evento == 1) _eventos.add(Endereco(valor.toInt()));
    if (evento == 2) _eventos.add(Rotacao(valor));
    if (evento == 3) _eventos.add(Taxa(valor.toInt()));
    if (evento == 4) _eventos.add(Secoes(valor.toInt()));
    if (evento == 5) _eventos.add(Deposito(valor.toInt()));
    if (evento == 6) _lat = valor;
    if (evento == 7) _eventos.add(Gps(_lat, valor, _rumo, _velocidade));
    if (evento == 8) _rumo = valor;
    if (evento == 9) _velocidade = valor;
  }

  void parar() {
    _stop(); // primeiro o C para de chamar...
    _callback?.close(); // ...depois fechamos o callback
    _eventos.close();
    malloc.free(_buffer);
  }
}
