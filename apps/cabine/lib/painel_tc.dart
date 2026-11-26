// painel_tc.dart — ao lado do VT: a plantadeira em 3D e o mapa do talhão (TC-GEO e TC-SEC)
//
// A plantadeira 3D (flutter_scene) mostra as seções que a plantadeira informa ao TC.
// O mapa mostra o que um terminal de verdade mostra: o aplicado (pela taxa real), o
// prescrito x aplicado e a prescrição, com legenda e relatório, e onde o trator está.
// O talhão vem do banco local: o que o simulador importou (shapefile) e marcou como ativo.
import 'dart:async';
import 'dart:typed_data';

import 'package:cena/cena.dart';
import 'package:flutter/material.dart';
import 'package:agiso/agiso.dart';
import 'package:agiso/banco.dart';
import 'package:agiso/geo.dart';
import 'package:agiso/relatorio.dart';

class PainelTc extends StatefulWidget {
  const PainelTc({
    super.key,
    required this.agiso,
    required this.tc,
    this.usarBanco = true,
  });

  /// false: fica no talhão da demo (o que o ./build/trator percorre), sem olhar o banco.
  final bool usarBanco;
  final Agiso agiso;
  final TcAutomatico tc;

  @override
  State<PainelTc> createState() => _PainelTcState();
}

class _PainelTcState extends State<PainelTc> {
  List<bool>? _secoes;
  late final _banco = Banco.abrir();
  Timer? _vigia, _redesenho;
  int? _talhaoId;
  bool _mudou = false;
  var _modo = ModoMapa.aplicado;
  Uint8List? _prescricao; // a prescrição na grade do mapa (para o relatório)

  @override
  void initState() {
    super.initState();
    widget.agiso.eventos.listen((e) {
      if (e is Secoes && mounted) setState(() => _secoes = e.ligadas);
    });
    // a tela redesenha em 4 Hz, não a cada GPS (10 Hz)
    widget.tc.aoMudar = () => _mudou = true;
    _redesenho = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_mudou && mounted) {
        _mudou = false;
        setState(() {});
      }
    });
    if (widget.usarBanco) {
      _vigiarTalhao();
      _vigia = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _vigiarTalhao(),
      );
    }
  }

  @override
  void dispose() {
    _vigia?.cancel();
    _redesenho?.cancel();
    if (widget.usarBanco) _banco.close();
    super.dispose();
  }

  // Outro programa (o simulador) pode ter importado um talhão: pergunta qual é o ativo
  Future<void> _vigiarTalhao() async {
    final id = await _banco.idTalhaoAtivo();
    if (id == null || id == _talhaoId) return;
    final ativo = await _banco.talhaoAtivo();
    if (ativo == null || !mounted) return;
    _talhaoId = ativo.id;
    _prescricao = null;
    widget.tc.trocarTalhao(ativo.talhao);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Talhão "${ativo.talhao.nome}" carregado do banco'),
        ),
      );
    }
  }

  void _relatorio() {
    final p = _prescricao;
    if (p == null) return;
    final r = Relatorio.de(p, widget.tc.mapa);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Relatório — ${widget.tc.talhao.nome}'),
        content: SizedBox(width: 820, child: TabelaRelatorio(relatorio: r)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.tc;
    final p = tc.posicao;
    return Column(
      children: [
        Expanded(child: VistaPlantadeira(secoes: _secoes)),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    SegmentedButton<ModoMapa>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: [
                        for (final m in ModoMapa.values)
                          ButtonSegment(value: m, label: Text(m.nome)),
                      ],
                      selected: {_modo},
                      onSelectionChanged: (s) =>
                          setState(() => _modo = s.first),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: MapaTalhao(
                        talhao: tc.talhao,
                        mapa: tc.mapa,
                        modo: _modo,
                        posicao: p,
                        barra: tc.barra,
                        plantando: _secoes?.contains(true) ?? false,
                        aoTerPrescricao: (g) => _prescricao = g,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LegendaMapa(modo: _modo, talhao: tc.talhao),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 210,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterChip(
                      label: const Text('TC automático (GEO + SEC)'),
                      selected: tc.ligado,
                      onSelected: (v) => setState(() => tc.ligado = v),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('relatório'),
                          onPressed: _relatorio,
                        ),
                        ActionChip(
                          label: const Text('limpar mapa'),
                          onPressed: tc.limpar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tc.talhao.nome,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      p == null
                          ? 'GPS: aguardando o trator'
                          : 'GPS e=${p.e.toStringAsFixed(1)} n=${p.n.toStringAsFixed(1)} m\n'
                                'rumo ${p.rumo.toStringAsFixed(0)}°',
                    ),
                    if (tc.ligado && tc.taxaMandada != null)
                      Text('zona: ${tc.taxaMandada} sementes/ha'),
                    Text(
                      'aplicado: ${tc.mapa.hectares.toStringAsFixed(3)} ha'
                      '${tc.mapa.sobrepostasN > 0 ? '\nsobreposto: ${tc.mapa.hectaresSobrepostos.toStringAsFixed(3)} ha' : ''}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
