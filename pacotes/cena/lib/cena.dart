// cena.dart — os modelos 3D da demo (flutter_scene) e a vista da plantadeira da cabine
//
// Os modelos (.glb) estão em assets/. A plantadeira mostra as seções como o VT mostra
// os funis: o pote de cada linha fica verde (plantando) ou vermelho (cortada), e as
// sementes caem só nas linhas das seções ligadas.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:agiso/geo.dart';
import 'package:vector_math/vector_math.dart' as vm;

export 'mapa.dart';
export 'talhao.dart';

final _verde = PhysicallyBasedMaterial()
  ..baseColorFactor = vm.Vector4(0.05, 0.75, 0.1, 1)
  ..roughnessFactor = 0.6;
final _vermelho = PhysicallyBasedMaterial()
  ..baseColorFactor = vm.Vector4(0.85, 0.05, 0.05, 1)
  ..roughnessFactor = 0.6;

final _tampa = PhysicallyBasedMaterial()
  ..baseColorFactor = vm.Vector4(0.12, 0.12, 0.13, 1)
  ..roughnessFactor = 0.5;

Future<void>? _recursos;

/// Os shaders do flutter_scene: uma vez só, antes de montar qualquer cena.
Future<void> prepararCena() => _recursos ??= Scene.initializeStaticResources();

/// O flutter_scene usa mão esquerda (Y para cima) e o glTF, mão direita: o
/// fromGlbAsset põe o modelo debaixo de um espelho em Z, e a frente dos nossos
/// modelos (+Z no glTF) vira -Z. Este nó gira 180° em Y para a frente voltar a +Z
/// (e a esquerda ficar em -X). Não mexa no nó importado: o espelho mora nele.
Node _virado(Node modelo) => Node(name: 'virado')
  ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi)
  ..add(modelo);

void _visitar(Node n, void Function(Node) f) {
  f(n);
  for (final c in n.children) {
    _visitar(c, f);
  }
}

/// A plantadeira: 16 linhas divididas entre as seções. Esticada na largura para ter os 9,144 m da
/// barra do DDOP (16 linhas a ~0,57 m).
class Plantadeira3D {
  Plantadeira3D._(this.no, this._linhas, this.alturaPote, this.zLinhas);

  /// O nó para pôr na cena. Origem: centro da barra, no chão; frente = +Z.
  final Node no;

  /// As linhas, da esquerda para a direita: (x, pote).
  final List<({double x, Node pote})> _linhas;
  final double alturaPote, zLinhas;
  List<bool>? _mostradas;
  late final InstancedMesh _sementes;
  static const _sementesPorLinha = 4;

  static Future<Plantadeira3D> carregar() async {
    await prepararCena();
    final modelo = await Node.fromGlbAsset(
      'packages/cena/assets/plantadeira.glb',
    );
    final b0 = modelo.combinedLocalBounds!;
    // estica na largura e vira de frente (+Z) — veja _virado
    final virado = _virado(modelo)
      ..scale = vm.Vector3(Barra.largura / (b0.max.x - b0.min.x), 1, 1);
    // origem no centro da barra, com as rodas no chão
    final b = virado.combinedWorldBounds!;
    virado.position = vm.Vector3(-(b.min.x + b.max.x) / 2, -b.min.y, 0);

    final raiz = Node(name: 'plantadeira')..add(virado);
    // o .glb tem peças duplicadas, uma sobre a outra (duas linhas com 2 potes e
    // 2 tampas): elas brigam pelo pixel e a tampa pisca. Fica só a primeira.
    final vistas = <String>{};
    _visitar(modelo, (n) {
      final c = n.mesh == null ? null : n.combinedWorldBounds;
      if (c == null) return;
      final chave =
          '${n.name.split('.').first}|${c.min.storage.map((v) => v.toStringAsFixed(2))}|'
          '${c.max.storage.map((v) => v.toStringAsFixed(2))}';
      if (!vistas.add(chave)) n.visible = false;
      // e uma das tampas veio sem material (sairia branca): todas ficam iguais
      if (n.name.startsWith('tampa')) {
        for (final prim in n.mesh!.primitives) {
          prim.material = _tampa;
        }
      }
    });

    final linhas = <({double x, Node pote})>[];
    var somaZ = 0.0, somaY = 0.0;
    _visitar(modelo, (n) {
      if (!n.visible || !n.name.startsWith('corpo pote')) return;
      final c = n.combinedWorldBounds!;
      linhas.add((x: (c.min.x + c.max.x) / 2, pote: n));
      somaZ += (c.min.z + c.max.z) / 2;
      somaY += c.min.y;
    });
    // ISO: a seção 1 fica à esquerda de quem anda para frente (+Z); a esquerda é -X
    linhas.sort((a, b) => a.x.compareTo(b.x));
    final p = Plantadeira3D._(
      raiz,
      linhas,
      somaY / linhas.length,
      somaZ / linhas.length,
    );

    p._sementes = InstancedMesh(
      geometry: SphereGeometry(radius: 0.05, segments: 8, rings: 4),
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = vm.Vector4(0.95, 0.8, 0.2, 1),
    );
    for (var i = 0; i < linhas.length * _sementesPorLinha; i++) {
      p._sementes.addInstance(vm.Matrix4.translationValues(0, -100, 0));
    }
    raiz.add(
      Node(name: 'sementes')..addComponent(InstancedMeshComponent(p._sementes)),
    );
    return p;
  }

  /// A seção da linha l (as 16 linhas divididas entre as seções, da esquerda para a direita).
  int _secao(int l, int secoes) => l * secoes ~/ _linhas.length;

  /// Pinta os potes: verde = seção plantando, vermelho = cortada.
  void mostrarSecoes(List<bool> ligadas) {
    if (ligadas.isEmpty) return;
    for (var l = 0; l < _linhas.length; l++) {
      final s = _secao(l, ligadas.length);
      if (_mostradas != null &&
          _mostradas!.length == ligadas.length &&
          _mostradas![s] == ligadas[s]) {
        continue;
      }
      for (final prim
          in _linhas[l].pote.mesh?.primitives ?? const <MeshPrimitive>[]) {
        prim.material = ligadas[s] ? _verde : _vermelho;
      }
    }
    _mostradas = List.of(ligadas);
  }

  /// As sementes caindo do pote até o chão, nas linhas ligadas. [segundos] = tempo da cena.
  void animar(double segundos) {
    final ligadas = _mostradas;
    _sementes.updateInstanceTransforms((t) {
      for (var l = 0; l < _linhas.length; l++) {
        final cai = ligadas != null && ligadas[_secao(l, ligadas.length)];
        for (var k = 0; k < _sementesPorLinha; k++) {
          // as matrizes se alteram no lugar (a lista não aceita troca)
          final m = t[l * _sementesPorLinha + k]..setIdentity();
          if (!cai) {
            m.setTranslationRaw(0, -100, 0); // escondida debaixo do chão
            continue;
          }
          final fase =
              (segundos * 1.6 + k / _sementesPorLinha + l * 0.13) % 1.0;
          m.setTranslationRaw(_linhas[l].x, alturaPote * (1 - fase), zLinhas);
        }
      }
    });
  }
}

/// O trator: corpo e rodas. Origem: antena do GPS projetada no chão; frente = +Z.
class Trator3D {
  Trator3D._(this.no, this._dianteiras, this._traseiras);

  final Node no;
  final Node? _dianteiras, _traseiras;
  late final vm.Quaternion _baseD =
      _dianteiras?.rotation ?? vm.Quaternion.identity();
  late final vm.Quaternion _baseT =
      _traseiras?.rotation ?? vm.Quaternion.identity();

  /// Distância da antena até a frente do engate (onde a plantadeira se apoia), em metros.
  late final double engate;

  static Future<Trator3D> carregar() async {
    await prepararCena();
    final modelo = await Node.fromGlbAsset('packages/cena/assets/tractor.glb');
    final virado = _virado(modelo);
    final b = virado.combinedWorldBounds!;
    // a antena: no teto, no meio do comprimento
    final antenaZ = (b.min.z + b.max.z) / 2;
    virado.position = vm.Vector3(-(b.min.x + b.max.x) / 2, -b.min.y, -antenaZ);
    final t = Trator3D._(
      Node(name: 'trator')..add(virado),
      modelo.getChildByName('rodas front'),
      modelo.getChildByName('rodas back'),
    );
    t.engate = antenaZ - b.min.z;
    return t;
  }

  /// Gira as rodas pela distância andada (rodas de ~0,6 m e ~0,8 m de raio).
  /// [esterco] em graus (positivo = para a direita): o eixo dianteiro vira junto.
  void rodar(double metros, {double esterco = 0}) {
    // as rodas estão dentro do espelho em Z do glTF (veja _virado): lá dentro a
    // rotação em Y tem o sentido trocado
    final virar = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      -esterco * math.pi / 180,
    );
    _dianteiras?.rotation =
        _baseD *
        virar *
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), metros / 0.58);
    _traseiras?.rotation =
        _baseT * vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), metros / 0.77);
  }
}

/// A plantadeira em 3D ao lado do VT, mostrando ao vivo as seções que o TC informa.
class VistaPlantadeira extends StatefulWidget {
  const VistaPlantadeira({super.key, required this.secoes});

  /// O estado REAL das seções (DDI 161), ou null antes de o implemento conectar.
  final List<bool>? secoes;

  @override
  State<VistaPlantadeira> createState() => _VistaPlantadeiraState();
}

class _VistaPlantadeiraState extends State<VistaPlantadeira> {
  final _cena = Scene();
  Plantadeira3D? _plantadeira;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    Plantadeira3D.carregar().then(
      (p) {
        _cena.add(p.no);
        if (widget.secoes != null) p.mostrarSecoes(widget.secoes!);
        if (mounted) setState(() => _plantadeira = p);
      },
      onError: (Object e) {
        if (mounted) setState(() => _erro = e);
      },
    );
  }

  @override
  void didUpdateWidget(VistaPlantadeira antigo) {
    super.didUpdateWidget(antigo);
    if (widget.secoes != null) _plantadeira?.mostrarSecoes(widget.secoes!);
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) return Center(child: Text('3D indisponível: $_erro'));
    final p = _plantadeira;
    if (p == null) return const SizedBox.expand();
    return SceneView(
      _cena,
      cameraBuilder: (passado) {
        p.animar(passado.inMicroseconds / 1e6);
        // de trás e de cima, girando devagar para a plateia ver as linhas
        final a = math.pi + 0.5 * math.sin(passado.inMilliseconds / 6000);
        return PerspectiveCamera(
          position: vm.Vector3(
            math.sin(a) * 6.5,
            3,
            p.zLinhas + math.cos(a) * 6.5,
          ),
          target: vm.Vector3(0, 0.5, p.zLinhas),
          fovRadiansY: 50 * vm.degrees2Radians,
        );
      },
    );
  }
}
