// main.dart — o simulador 3D: você dirige o trator que reboca a plantadeira
//
// O simulador É o trator na rede CAN: a cada 100 ms manda o GPS NMEA 2000, a velocidade
// de solo (a plantadeira precisa dela) e a rotação do motor (a cabine mostra). As seções
// vêm do que a plantadeira informa ao TC da cabine. Não rode junto com o ./build/trator.
//
//   flutter run -d linux                                 você dirige
//   flutter run -d linux -a --ouvinte                    só acompanha o ./build/trator
//
// O talhão (o da demo) e cada trabalho, com o mapa de aplicação, ficam no banco local
// (drift): a cabine lê o mesmo talhão e usa o mesmo mapa de prescrição.
//
// Controles: W/↑ acelera, S/↓ freia, A/D ou ←/→ volante, Q/E acelerador de mão,
// R frente/ré, C câmera. Ou o volante na tela, ou um volante USB.
import 'dart:async';
import 'dart:math' as math;

import 'package:cena/cena.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agiso/agiso.dart';
import 'package:agiso/banco.dart';
import 'package:agiso/geo.dart';

import 'controle_usb.dart';
import 'fisica.dart';
import 'painel.dart';

final agiso = Agiso();
final tc = TcAutomatico(agiso); // desligado: aqui só guarda o mapa de aplicação
late final bool ouvinte;
Banco? banco;

void main(List<String> args) {
  ouvinte = args.contains('--ouvinte');
  if (ouvinte) {
    agiso.iniciarOuvinte('vcan0');
  } else {
    agiso.iniciarTrator('vcan0');
    banco = Banco.abrir();
  }
  runApp(
    const MaterialApp(
      title: 'Simulador do trator',
      debugShowCheckedModeBanner: false,
      home: Simulador(),
    ),
  );
}

class Simulador extends StatefulWidget {
  const Simulador({super.key});

  @override
  State<Simulador> createState() => _SimuladorState();
}

class _SimuladorState extends State<Simulador> {
  final _trator = FisicaTrator();
  final _usb = ControleUsb();
  Timer? _envio, _autosalvar;
  List<bool>? _secoes;
  var _camera = Camera3D.atras;

  // o volante: o teclado centraliza sozinho quando você solta; a mão (tela/USB), não
  bool _centralizar = false, _arrastando = false;
  double _usbAnterior = 0, _pedalTeclado = 0, _freioTeclado = 0;

  // o banco: o talhão ativo e o trabalho em andamento
  int? _talhaoId, _trabalhoId;
  int _salvas = -1; // células plantadas no último salvamento
  DateTime? _salvoEm;

  // modo ouvinte: a pose desenhada persegue o GPS (que chega a 10 Hz)
  double _e = 4.6, _n = -14, _rumo = 0;

  @override
  void initState() {
    super.initState();
    agiso.eventos.listen((e) {
      if (e is Secoes) setState(() => _secoes = e.ligadas);
      if (e is Gps && ouvinte) setState(() {});
    });
    if (!ouvinte) {
      _usb
        ..aoApertar = (botao) {
          if (botao == ControleUsb.botaoSentido) _trator.trocarSentido();
          if (botao == ControleUsb.botaoCamera) _proximaCamera();
        }
        ..abrir();
      _envio = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _mandar(),
      );
      _autosalvar = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _salvar(),
      );
      _carregar();
    }
  }

  @override
  void dispose() {
    _envio?.cancel();
    _autosalvar?.cancel();
    _usb.fechar();
    _salvar();
    super.dispose();
  }

  // --- banco: talhão e trabalho ---

  // Ao abrir: o talhão ativo, ou o da demo
  Future<void> _carregar() async {
    final b = banco!;
    var ativo = await b.talhaoAtivo();
    if (ativo == null) {
      final t = Talhao.padrao();
      ativo = (id: await b.salvarTalhao(t), talhao: t);
    }
    await _usarTalhao(ativo.id, ativo.talhao);
  }

  // Põe o talhão em uso: continua o trabalho aberto nele (com o mapa), ou começa um
  Future<void> _usarTalhao(int id, Talhao t) async {
    final b = banco!;
    final aberto = await b.trabalhoAberto(id);
    final mapa = aberto == null ? null : await b.mapaDoTrabalho(aberto.id);
    _talhaoId = id;
    _trabalhoId = aberto?.id ?? await b.iniciarTrabalho(id);
    tc.trocarTalhao(t, mapa: mapa);
    tc.distancia = aberto?.distanciaM ?? 0;
    _salvas = tc.mapa.plantadas;
    _salvoEm = DateTime.now();
    // o trator volta ao começo: ao sul do talhão, meia barra para dentro da borda oeste
    final l = t.limites;
    _trator.reposicionar(l.minE + Barra.largura / 2, l.minN - 14, 0);
    if (mounted) setState(() {});
  }

  Future<void> _salvar({bool encerrar = false, bool forcar = false}) async {
    final b = banco, id = _trabalhoId;
    if (b == null || id == null) return;
    if (!encerrar &&
        !forcar &&
        tc.mapa.plantadas + tc.mapa.sobrepostasN == _salvas) {
      return; // nada novo
    }
    _salvas = tc.mapa.plantadas + tc.mapa.sobrepostasN;
    await b.salvarTrabalho(
      id,
      tc.mapa,
      distancia: tc.distancia,
      encerrar: encerrar,
    );
    _salvoEm = DateTime.now();
    if (encerrar) _trabalhoId = null;
  }

  Future<void> _novoTrabalho() async {
    await _salvar(encerrar: true);
    final ativo = await banco!.talhaoAtivo();
    if (ativo != null) await _usarTalhao(ativo.id, ativo.talhao);
    _aviso('Trabalho novo: o mapa de aplicação começa em branco');
  }

  Future<void> _verTrabalhos() async {
    final b = banco, talhao = _talhaoId;
    if (b == null || talhao == null) return;
    await _salvar();
    final lista = await b.trabalhosDo(talhao);
    if (!mounted) return;
    String data(DateTime d) {
      final l = d.toLocal();
      String dois(int v) => v.toString().padLeft(2, '0');
      return '${dois(l.day)}/${dois(l.month)} ${dois(l.hour)}:${dois(l.minute)}';
    }

    final escolhido = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trabalhos em ${tc.talhao.nome}'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final j in lista)
                ListTile(
                  leading: Icon(
                    j.fim == null
                        ? Icons.play_circle
                        : Icons.check_circle_outline,
                  ),
                  title: Text(
                    '#${j.id}  ${data(j.inicio)}  ·  ${j.hectares.toStringAsFixed(2)} ha',
                  ),
                  subtitle: Text(
                    '${(j.sementes / 1000).toStringAsFixed(1)} mil sementes  ·  '
                    '${(j.distanciaM / 1000).toStringAsFixed(2)} km'
                    '${j.fim == null ? '  ·  em andamento' : ''}',
                  ),
                  trailing: j.id == _trabalhoId
                      ? null
                      : TextButton(
                          onPressed: () => Navigator.pop(context, j.id),
                          child: const Text('continuar'),
                        ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('fechar'),
          ),
        ],
      ),
    );
    if (escolhido == null) return;
    await _salvar(encerrar: true);
    await b.reabrirTrabalho(escolhido);
    final ativo = await b.talhaoAtivo();
    if (ativo != null) await _usarTalhao(ativo.id, ativo.talhao);
  }

  // --- a rede ---

  // 10 vezes por segundo: o trator anuncia na rede onde está
  void _mandar() {
    final t = _trator;
    final g = tc.talhao.graus(t.e, t.n);
    agiso.moverTrator(g.lat, g.lon, t.rumo, t.velocidade, t.rpm);
    // o simulador não recebe o que ele mesmo manda: avisa o próprio "TC" direto
    tc.aoGps(Gps(g.lat, g.lon, t.rumo, t.velocidade.abs()));
    setState(() {});
  }

  // --- comandos ---

  void _proximaCamera() => setState(
    () =>
        _camera = Camera3D.values[(_camera.index + 1) % Camera3D.values.length],
  );

  // Teclas de um toque: a borda "acabou de apertar", lida a cada quadro junto com as de
  // segurar (não depende de qual widget tem o foco). O efeito vem depois do quadro.
  var _antes = <LogicalKeyboardKey>{};
  void _toques(Set<LogicalKeyboardKey> teclas) {
    bool apertou(LogicalKeyboardKey k) =>
        teclas.contains(k) && !_antes.contains(k);
    void depois(void Function() f) =>
        WidgetsBinding.instance.addPostFrameCallback((_) => f());
    if (apertou(LogicalKeyboardKey.keyR)) {
      depois(() {
        if (!_trator.trocarSentido()) {
          _aviso('Pare o trator para trocar frente/ré');
        }
      });
    }
    if (apertou(LogicalKeyboardKey.keyC)) depois(_proximaCamera);
    _antes = Set.of(teclas);
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(texto), duration: const Duration(seconds: 2)),
      );
  }

  // A cada quadro: lê os comandos e a física anda
  PoseTrator? _dirigir(double dt) {
    if (ouvinte) return _seguirGps(dt);
    final t = _trator;
    final teclas = HardwareKeyboard.instance.logicalKeysPressed;
    _toques(teclas);
    bool tem(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        teclas.contains(a) || teclas.contains(b);

    // volante: teclado gira 1,5 volta por segundo; solto, volta ao centro
    final esquerda = tem(LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.keyA);
    final direita = tem(LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.keyD);
    if (esquerda != direita) {
      t.volante += (direita ? 1 : -1) * 540 * dt;
      _centralizar = true;
    } else if (_centralizar && !_arrastando) {
      final volta = 400 * dt;
      t.volante = t.volante.abs() <= volta
          ? 0
          : t.volante - t.volante.sign * volta;
    }
    // volante USB: só manda quando mexe (um gamepad parado não trava o teclado)
    if (_usb.conectado && (_usb.volante - _usbAnterior).abs() > 0.002) {
      _usbAnterior = _usb.volante;
      _centralizar = false;
      t.volante = _usb.volante * 360 * FisicaTrator.voltasDoVolante;
    }
    final limite = 360 * FisicaTrator.voltasDoVolante;
    t.volante = t.volante.clamp(-limite, limite);

    // pedais: o do teclado desce e sobe com rampa, como um pé de verdade
    double rampa(double v, bool pisado) =>
        pisado ? math.min(1, v + dt * 2.5) : math.max(0, v - dt * 4);
    _pedalTeclado = rampa(
      _pedalTeclado,
      tem(LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.keyW),
    );
    _freioTeclado = rampa(
      _freioTeclado,
      tem(LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.keyS) ||
          teclas.contains(LogicalKeyboardKey.space),
    );
    t.pedal = math.max(_pedalTeclado, _usb.acelerador);
    t.freio = math.max(_freioTeclado, _usb.freio);
    // acelerador de mão: Q tira, E põe
    if (teclas.contains(LogicalKeyboardKey.keyE)) {
      t.aceleradorDeMao = math.min(1, t.aceleradorDeMao + dt * 0.5);
    }
    if (teclas.contains(LogicalKeyboardKey.keyQ)) {
      t.aceleradorDeMao = math.max(0, t.aceleradorDeMao - dt * 0.5);
    }

    t.passo(dt);
    return (e: t.e, n: t.n, rumo: t.rumo, esterco: t.esterco);
  }

  PoseTrator? _seguirGps(double dt) {
    final alvo = tc.posicao;
    if (alvo == null) return null;
    final k = 1 - math.exp(-dt * 10);
    _e += (alvo.e - _e) * k;
    _n += (alvo.n - _n) * k;
    var dr = (alvo.rumo - _rumo + 540) % 360 - 180; // o caminho mais curto
    if (dr.abs() > 90) dr = alvo.rumo - _rumo; // primeiro quadro / salto
    _rumo += dr * k;
    return (e: _e, n: _n, rumo: _rumo, esterco: 0.0);
  }

  // --- a tela ---

  @override
  Widget build(BuildContext context) {
    final t = _trator;
    final p = ouvinte ? tc.posicao : (e: t.e, n: t.n, rumo: t.rumo);
    final b = tc.barra;
    final taxa = b == null ? null : tc.talhao.taxa(b.e, b.n);
    final salvo = _salvoEm == null
        ? null
        : DateTime.now().difference(_salvoEm!).inSeconds;
    return Focus(
      autofocus: true,
      // o teclado é do trator: espaço e setas não acionam nem passeiam pelos botões
      onKeyEvent: (_, _) => KeyEventResult.handled,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: CenaTalhao(
                pose: _dirigir,
                tc: tc,
                secoes: _secoes,
                camera: _camera,
              ),
            ),
            Positioned(
              left: 16,
              top: 16,
              child: _Caixa(
                linhas: [
                  tc.talhao.nome,
                  if (p == null)
                    'GPS: aguardando o trator (./build/trator)'
                  else
                    'e=${p.e.toStringAsFixed(1)}  n=${p.n.toStringAsFixed(1)} m   rumo ${p.rumo.toStringAsFixed(0)}°',
                  taxa == null
                      ? 'barra fora do talhão'
                      : 'prescrição: $taxa sementes/ha',
                  'plantado: ${tc.mapa.hectares.toStringAsFixed(3)} ha  ·  '
                      '${(tc.mapa.sementes / 1000).toStringAsFixed(1)} mil sementes',
                  if (_secoes != null)
                    'seções  ${_secoes!.map((l) => l ? '■' : '□').join(' ')}',
                  if (_trabalhoId != null)
                    'trabalho #$_trabalhoId  ·  salvo há ${salvo ?? 0} s',
                  if (!ouvinte && _usb.conectado) 'controle USB conectado',
                ],
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SegmentedButton<Camera3D>(
                    segments: const [
                      ButtonSegment(
                        value: Camera3D.cabine,
                        label: Text('cabine'),
                      ),
                      ButtonSegment(
                        value: Camera3D.atras,
                        label: Text('atrás'),
                      ),
                      ButtonSegment(
                        value: Camera3D.cima,
                        label: Text('de cima'),
                      ),
                    ],
                    selected: {_camera},
                    onSelectionChanged: (s) =>
                        setState(() => _camera = s.first),
                  ),
                  if (!ouvinte) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        FilledButton.tonal(
                          onPressed: _novoTrabalho,
                          child: const Text('novo trabalho'),
                        ),
                        FilledButton.tonal(
                          onPressed: _verTrabalhos,
                          child: const Text('trabalhos'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!ouvinte) ..._controles(),
          ],
        ),
      ),
    );
  }

  List<Widget> _controles() {
    final t = _trator;
    return [
      Positioned(
        left: 16,
        bottom: 16,
        child: Instrumentos(kmh: t.velocidade * 3.6, rpm: t.rpm, re: t.re),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: Volante(
          angulo: t.volante,
          aoGirar: (graus, {required soltou}) {
            _arrastando = !soltou;
            if (graus != 0) _centralizar = false;
            t.volante = (t.volante + graus).clamp(
              -360 * FisicaTrator.voltasDoVolante,
              360 * FisicaTrator.voltasDoVolante,
            );
          },
        ),
      ),
      // o acelerador de mão (a alavanca do trator) e o câmbio frente/ré
      Positioned(
        right: 270,
        bottom: 24,
        child: _Caixa(
          filhos: [
            const Text(
              'acelerador',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            SizedBox(
              height: 150,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: t.aceleradorDeMao,
                  onChanged: (v) => setState(() => t.aceleradorDeMao = v),
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: () {
                if (!t.trocarSentido()) {
                  _aviso('Pare o trator para trocar frente/ré');
                }
              },
              child: Text(t.re ? 'R → F' : 'F → R'),
            ),
          ],
        ),
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 4,
        child: Center(
          child: Text(
            'W/↑ acelera · S/↓ freia · A/D ←/→ volante · Q/E acelerador de mão · R frente/ré · C câmera',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              shadows: [Shadow(blurRadius: 4)],
            ),
          ),
        ),
      ),
    ];
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({this.linhas = const [], this.filhos = const []});
  final List<String> linhas;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in linhas)
              Text(
                l,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'monospace',
                ),
              ),
            ...filhos,
          ],
        ),
      ),
    );
  }
}
