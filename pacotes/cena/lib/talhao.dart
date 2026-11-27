// talhao.dart — o simulador 3D: o trator rebocando a plantadeira no talhão
//
// Mundo: X = leste, Y = cima, Z = norte (o flutter_scene é mão esquerda), em metros a
// partir da origem do talhão. O chão do talhão é UM plano com UMA textura do tamanho do
// mapa de aplicação: plantar é pintar pixels (nada de uma peça 3D por célula). A cor de
// base sai do contorno e das zonas do talhão, calculada num isolate.
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:agiso/geo.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'cena.dart';

vm.Vector3 _mundo(double e, double n, [double y = 0]) => vm.Vector3(e, y, n);

/// Onde o trator está neste quadro: metros (leste, norte), rumo e esterço em graus.
typedef PoseTrator = ({double e, double n, double rumo, double esterco});

enum Camera3D { cabine, atras, cima }

/// A prescrição na grade do mapa (o código da taxa por célula; 0 = fora do talhão),
/// calculada fora da tela (um isolate): dá a cor de base do chão.
Future<Uint8List> prescricaoEmSegundoPlano(Talhao t, MapaAplicacao m) {
  // o isolate recebe uma cópia: um mapa vazio com a mesma grade basta
  final grade = MapaAplicacao.de(
    origemE: m.origemE,
    origemN: m.origemN,
    celula: m.celula,
    largura: m.largura,
    altura: m.altura,
    dados: Uint8List(0),
  );
  final celulas = m.largura * m.altura;
  return Isolate.run(() {
    final g = Uint8List(celulas);
    for (var i = 0; i < celulas; i++) {
      final c = grade.centro(i);
      final taxa = t.taxa(c.e, c.n);
      if (taxa != null) g[i] = MapaAplicacao.codigo(taxa);
    }
    return g;
  });
}

class CenaTalhao extends StatefulWidget {
  const CenaTalhao({
    super.key,
    required this.pose,
    required this.tc,
    required this.secoes,
    this.camera = Camera3D.atras,
  });

  /// Chamada a cada quadro com o tempo passado (s): a física do simulador, ou o GPS.
  final PoseTrator? Function(double dt) pose;

  /// O talhão e o mapa de aplicação (a cena só desenha).
  final TcAutomatico tc;

  /// O estado real das seções, como a plantadeira informa ao TC.
  final List<bool>? secoes;

  final Camera3D camera;

  @override
  State<CenaTalhao> createState() => _CenaTalhaoState();
}

// Um ruído barato e determinístico (hash), de 0 a 1
double _ruido(int x, int y) {
  var h = x * 374761393 + y * 668265263;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) & 0xFFFF) / 0xFFFF;
}

// Ruído suave: o hash interpolado numa grade de [passo] pixels (manchas no solo).
// [periodo] (em células da grade) faz o padrão se repetir sem emenda.
double _manchas(int x, int y, int passo, {int periodo = 1 << 30}) {
  final gx = x ~/ passo, gy = y ~/ passo;
  final fx = (x % passo) / passo, fy = (y % passo) / passo;
  double r(int a, int b) => _ruido(a % periodo, b % periodo);
  final a = r(gx, gy), b = r(gx + 1, gy);
  final c = r(gx, gy + 1), d = r(gx + 1, gy + 1);
  final sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
  return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy;
}

/// A cor de base de cada célula do mapa (RGBA): terra dentro do talhão (um pouco mais
/// escura onde a prescrição é maior), carreador fora. [prescricao]: a da mesma grade.
Uint8List _corDeBase(Uint8List prescricao, int largura) {
  final px = Uint8List(prescricao.length * 4);
  for (var i = 0; i < prescricao.length; i++) {
    final x = i % largura, y = i ~/ largura;
    final v = 0.82 + 0.18 * _manchas(x, y, 24) + 0.08 * (_ruido(x, y) - 0.5);
    double r, g, b;
    if (prescricao[i] == 0) {
      (r, g, b) = (0.56, 0.47, 0.34); // carreador: terra batida
    } else {
      final t = ((MapaAplicacao.taxaDe(prescricao[i]) - 10000) / 12000).clamp(
        0.0,
        1.0,
      );
      (r, g, b) = (0.66 - 0.12 * t, 0.47 - 0.09 * t, 0.3 - 0.06 * t);
    }
    px[i * 4] = (r * v * 255).round().clamp(0, 255);
    px[i * 4 + 1] = (g * v * 255).round().clamp(0, 255);
    px[i * 4 + 2] = (b * v * 255).round().clamp(0, 255);
    px[i * 4 + 3] = 255;
  }
  return px;
}

class _CenaTalhaoState extends State<CenaTalhao> {
  final _cena = Scene();
  final _engate = Engate();
  Trator3D? _trator;
  Plantadeira3D? _plantadeira;
  Object? _erro;

  // o chão do talhão: textura = cor de base + o que foi plantado
  Node? _campo, _pastoNo;
  Texture2D? _textura;
  Uint8List? _pixels, _base;
  MapaAplicacao? _mapaDaTextura;
  bool _sujo = false;
  Duration _ultimoEnvio = Duration.zero;
  int _geracao =
      0; // descarta uma cor de base que chegou atrasada (talhão trocado)

  double _andado = 0, _velocidade = 0;
  ({double e, double n})? _ultima;
  Duration? _ultimo;
  vm.Vector3? _olho; // a câmera persegue suave

  @override
  void initState() {
    super.initState();
    _montar().catchError((Object e) {
      if (mounted) setState(() => _erro = e);
    });
  }

  Future<void> _montar() async {
    await prepararCena();
    // céu de verdade, com sol, sombras e neblina que puxa a cor do céu
    final ceu = PhysicalSkySource(sunDirection: vm.Vector3(0.5, 0.7, 0.35));
    _cena.skybox = Skybox(ceu);
    _cena.skyEnvironment = SkyEnvironment(ceu);
    _cena.sunLight = SunLight(ceu, castsShadow: true);
    _cena.fog
      ..enabled = true
      ..density = 0.003
      ..start = 60
      ..skyColorInfluence = 0.85;

    final trator = await Trator3D.carregar();
    final plantadeira = await Plantadeira3D.carregar();
    _cena
      ..add(trator.no)
      ..add(plantadeira.no);
    if (widget.secoes != null) plantadeira.mostrarSecoes(widget.secoes!);
    _trator = trator;
    _plantadeira = plantadeira;

    widget.tc.aoPlantar = _aoPlantar;
    widget.tc.aoTrocar = _montarCampo;
    await _montarCampo();
    if (mounted) setState(() {});
  }

  // O pasto em volta: textura de ruído verde, repetida a cada 8 m
  Node _pasto(({double minE, double minN, double maxE, double maxN}) l) {
    const lado = 256, passo = 32;
    final px = Uint8List(lado * lado * 4);
    for (var y = 0; y < lado; y++) {
      for (var x = 0; x < lado; x++) {
        // o período das manchas fecha com a borda: a repetição não deixa emenda
        final v =
            0.7 +
            0.25 * _manchas(x, y, passo, periodo: lado ~/ passo) +
            0.15 * (_ruido(x, y) - 0.5);
        final i = (y * lado + x) * 4;
        px[i] = (0.24 * v * 255).round();
        px[i + 1] = (0.4 * v * 255).round();
        px[i + 2] = (0.13 * v * 255).round();
        px[i + 3] = 255;
      }
    }
    const tamanho = 3000.0;
    final material =
        PhysicallyBasedMaterial(
            baseColorTexture: Texture2D.fromPixels(px, lado, lado),
          )
          ..roughnessFactor = 0.95
          ..baseColorTextureTransform = TextureTransform(
            scale: vm.Vector2.all(tamanho / 8),
          );
    return Node(
      name: 'pasto',
      mesh: Mesh(PlaneGeometry(width: tamanho, depth: tamanho), material),
      localTransform: vm.Matrix4.translation(
        _mundo((l.minE + l.maxE) / 2, (l.minN + l.maxN) / 2, -0.06),
      ),
    );
  }

  // O chão do talhão: um plano do tamanho do mapa de aplicação, com a textura dele.
  // Chamado de novo quando o talhão (ou o mapa) é trocado.
  Future<void> _montarCampo() async {
    final geracao = ++_geracao;
    final m = widget.tc.mapa, t = widget.tc.talhao;
    final prescricao = await prescricaoEmSegundoPlano(t, m);
    if (!mounted || geracao != _geracao) return;
    _base = _corDeBase(prescricao, m.largura);
    final base = Uint8List.fromList(_base!);
    // o que já foi plantado (mapa de um trabalho que continua) entra por cima
    for (var i = 0; i < m.dados.length; i++) {
      if (m.dados[i] != 0) _pintarPlantado(base, i, m);
    }
    final textura = Texture2D.fromPixels(
      base,
      m.largura,
      m.altura,
      sampling: const TextureSampling(mipmaps: false),
    );
    final material = PhysicallyBasedMaterial(baseColorTexture: textura)
      ..roughnessFactor = 0.97;
    final w = m.largura * m.celula, h = m.altura * m.celula;
    final campo = Node(
      name: 'campo',
      mesh: Mesh(PlaneGeometry(width: w, depth: h), material),
      localTransform: vm.Matrix4.translation(
        _mundo(m.origemE + w / 2, m.origemN + h / 2, 0),
      ),
    );
    if (_campo != null) _cena.remove(_campo!);
    if (_pastoNo != null) _cena.remove(_pastoNo!);
    _pastoNo = _pasto(t.limites);
    _cena
      ..add(_pastoNo!)
      ..add(campo);
    _campo = campo;
    _textura = textura;
    _pixels = base;
    _mapaDaTextura = m;
    _sujo = false;
    if (mounted) setState(() {});
  }

  // A cor de uma célula plantada: terra revolvida (escura, com variação); um pouco
  // arroxeada onde a plantadeira passou duas vezes (sobreposição)
  void _pintarPlantado(Uint8List px, int i, MapaAplicacao m) {
    final v = 0.85 + 0.3 * _ruido(i, 7);
    final (r, g, b) = m.sobrepostas[i] != 0
        ? (0.24 * v, 0.11 * v, 0.16 * v)
        : (0.22 * v, 0.15 * v, 0.09 * v);
    px[i * 4] = (r * 255).round().clamp(0, 255);
    px[i * 4 + 1] = (g * 255).round().clamp(0, 255);
    px[i * 4 + 2] = (b * 255).round().clamp(0, 255);
  }

  void _aoPlantar(int indice) {
    final px = _pixels;
    final m = widget.tc.mapa;
    if (px == null || !identical(_mapaDaTextura, m)) return;
    _pintarPlantado(px, indice, m);
    _sujo = true;
  }

  @override
  void didUpdateWidget(CenaTalhao antigo) {
    super.didUpdateWidget(antigo);
    if (widget.secoes != null) _plantadeira?.mostrarSecoes(widget.secoes!);
  }

  @override
  void dispose() {
    widget.tc.aoPlantar = null;
    widget.tc.aoTrocar = null;
    super.dispose();
  }

  static vm.Quaternion _giro(double rumoGraus) =>
      vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), rumoGraus * math.pi / 180);

  // A cada quadro: pede a pose, move o trator e a plantadeira rebocada, posiciona a câmera
  Camera _quadro(Duration agora) {
    final dt = _ultimo == null ? 0.0 : (agora - _ultimo!).inMicroseconds / 1e6;
    _ultimo = agora;
    final l = widget.tc.talhao.limites;
    final p =
        widget.pose(dt) ??
        (e: l.minE + 5, n: l.minN - 14, rumo: 0.0, esterco: 0.0);

    final antes = _ultima ?? (e: p.e, n: p.n);
    final de = p.e - antes.e, dn = p.n - antes.n;
    final h = p.rumo * math.pi / 180;
    // para frente soma, de ré desconta (as rodas giram ao contrário)
    final passo = de * math.sin(h) + dn * math.cos(h);
    _andado += passo;
    if (dt > 0) {
      _velocidade += (passo / dt - _velocidade) * (1 - math.exp(-dt * 4));
    }
    _ultima = (e: p.e, n: p.n);

    // o solo não é liso: o trator joga um pouco, mais quanto mais rápido
    final forca = (_velocidade.abs() / 4).clamp(0.0, 1.0);
    final arfagem =
        forca *
        (0.012 * math.sin(_andado * 1.7) + 0.006 * math.sin(_andado * 4.3));
    final rolagem =
        forca *
        (0.015 * math.sin(_andado * 1.1 + 1) + 0.005 * math.sin(_andado * 5.1));

    final trator = _trator!, plantadeira = _plantadeira!;
    trator.no
      ..position = _mundo(p.e, p.n)
      ..rotation =
          _giro(p.rumo) *
          vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), arfagem) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), rolagem);
    trator.rodar(_andado, esterco: p.esterco);

    // a plantadeira: o centro das linhas onde o engate puxou
    final b = _engate.seguir(p.e, p.n, p.rumo);
    final hb = b.rumo * math.pi / 180;
    plantadeira.no
      ..position = _mundo(
        b.e - math.sin(hb) * plantadeira.zLinhas,
        b.n - math.cos(hb) * plantadeira.zLinhas,
      )
      ..rotation =
          _giro(b.rumo) *
          vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), rolagem * 0.6);
    plantadeira.animar(agora.inMicroseconds / 1e6);

    // a textura do chão vai para a GPU no máximo a cada ~150 ms, e só se mudou
    if (_sujo && (agora - _ultimoEnvio).inMilliseconds > 150) {
      _textura?.gpuTexture.overwrite(ByteData.sublistView(_pixels!));
      _sujo = false;
      _ultimoEnvio = agora;
    }
    // de cima (centenas de metros): a neblina do horizonte cobriria tudo
    _cena.fog.enabled = widget.camera != Camera3D.cima;

    final frente = vm.Vector3(math.sin(h), 0, math.cos(h));
    final direita = vm.Vector3(math.cos(h), 0, -math.sin(h));
    final aqui = _mundo(p.e, p.n);
    switch (widget.camera) {
      case Camera3D.cabine:
        // na frente do para-brisa, acima do capô (o modelo não tem o interior da
        // cabine: com o olho lá dentro, só se veria o vidro por dentro)
        final olho = aqui + frente * 0.6 + vm.Vector3(0, 2.3 + arfagem * 3, 0);
        _olho = null;
        return PerspectiveCamera(
          position: olho,
          target: olho + frente * 10 - vm.Vector3(0, 1.6, 0),
          fovRadiansY: 70 * vm.degrees2Radians,
          fovNear: 0.05,
        );
      case Camera3D.atras:
        final alvo = aqui - frente * 17 - direita * 5 + vm.Vector3(0, 9, 0);
        // a câmera persegue com atraso, como um cinegrafista
        final k = 1 - math.exp(-dt * 3);
        _olho = _olho == null ? alvo : _olho! + (alvo - _olho!) * k;
        return PerspectiveCamera(position: _olho!, target: aqui + frente * 4);
      case Camera3D.cima:
        _olho = null;
        // alto o bastante para caber o talhão inteiro
        final tamanho = math.max(l.maxE - l.minE, l.maxN - l.minN);
        final centro = _mundo((l.minE + l.maxE) / 2, (l.minN + l.maxN) / 2);
        return PerspectiveCamera(
          position: centro + vm.Vector3(0, tamanho * 1.25, -tamanho * 0.35),
          target: centro,
          fovFar: tamanho * 4 + 500,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) return Center(child: Text('3D indisponível: $_erro'));
    if (_trator == null || _campo == null) {
      return const Center(child: Text('Carregando o talhão…'));
    }
    return SceneView(_cena, cameraBuilder: _quadro);
  }
}
