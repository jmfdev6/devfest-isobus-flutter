// ver_trabalho.dart — um trabalho guardado: o mapa (aplicado, prescrito x aplicado,
// prescrição), o relatório por taxa e a exportação do mapa de aplicação em shapefile
import 'dart:typed_data';

import 'package:cena/cena.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:agiso/banco.dart';
import 'package:agiso/geo.dart';
import 'package:agiso/relatorio.dart';

class VerTrabalho extends StatefulWidget {
  const VerTrabalho({
    super.key,
    required this.trabalho,
    required this.talhao,
    required this.mapa,
  });

  final Trabalho trabalho;
  final Talhao talhao;
  final MapaAplicacao mapa;

  @override
  State<VerTrabalho> createState() => _VerTrabalhoState();
}

class _VerTrabalhoState extends State<VerTrabalho> {
  var _modo = ModoMapa.comparacao;
  Uint8List? _prescricao;
  Relatorio? _relatorio;

  Future<void> _exportar() async {
    final p = _prescricao;
    if (p == null) return;
    final nome =
        '${widget.talhao.nome}_trabalho_${widget.trabalho.id}_aplicado';
    final destino = await getSaveLocation(
      suggestedName: '$nome.shp',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Shapefile', extensions: ['shp']),
      ],
    );
    if (destino == null) return;
    final base = destino.path.replaceAll(
      RegExp(r'\.shp$', caseSensitive: false),
      '',
    );
    final n = exportarAplicacao(base, widget.talhao, widget.mapa, p);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exportado: $n polígonos em ${base.split('/').last}.shp (.shx, .dbf, .prj)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.trabalho;
    String dois(int v) => v.toString().padLeft(2, '0');
    final ini = j.inicio.toLocal();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.talhao.nome} · trabalho #${j.id} · ${dois(ini.day)}/${dois(ini.month)} '
          '${dois(ini.hour)}:${dois(ini.minute)}${j.fim == null ? ' (em andamento)' : ''}',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _prescricao == null ? null : _exportar,
              icon: const Icon(Icons.save_alt),
              label: const Text('exportar shapefile'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ModoMapa>(
                    segments: [
                      for (final m in ModoMapa.values)
                        ButtonSegment(value: m, label: Text(m.nome)),
                    ],
                    selected: {_modo},
                    onSelectionChanged: (s) => setState(() => _modo = s.first),
                  ),
                  const SizedBox(height: 8),
                  LegendaMapa(modo: _modo, talhao: widget.talhao),
                  const SizedBox(height: 8),
                  Expanded(
                    child: MapaTalhao(
                      talhao: widget.talhao,
                      mapa: widget.mapa,
                      modo: _modo,
                      aoTerPrescricao: (p) => setState(() {
                        _prescricao = p;
                        _relatorio = Relatorio.de(p, widget.mapa);
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 6,
              child: _relatorio == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Relatório por taxa prescrita',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TabelaRelatorio(relatorio: _relatorio!),
                          const SizedBox(height: 16),
                          Text(
                            'Distância percorrida: ${(j.distanciaM / 1000).toStringAsFixed(2)} km\n'
                            'Na taxa = aplicada a menos de 5% da prescrição. Sobreposta = a plantadeira '
                            'passou duas vezes (semente em dobro). Não aplicada = dentro do talhão e sem semente.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
