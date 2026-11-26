// importar.dart — a janela de importar talhão: contorno, prescrição, campo e unidade
//
// O contorno e a prescrição podem vir no mesmo shapefile (cada polígono uma zona, com o
// campo da taxa) ou em dois (o contorno do talhão e o mapa de prescrição da empresa,
// que pode passar da divisa). Graus ou UTM: o leitor converte.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:agiso/geo.dart';
import 'package:agiso/shapefile.dart';

/// As unidades de taxa mais comuns nos mapas de prescrição, e quanto vale cada uma
/// em sementes por hectare.
const unidades = <(String, double)>[
  ('sementes/ha', 1),
  ('mil sementes/ha', 1000),
  ('sementes/m²', 10000),
];

/// Abre a janela; devolve o talhão pronto (ou null, se cancelar).
Future<Talhao?> importarTalhao(
  BuildContext context, {
  String? contornoInicial,
}) => showDialog<Talhao>(
  context: context,
  builder: (_) => _Importar(contornoInicial),
);

class _Importar extends StatefulWidget {
  const _Importar(this.contornoInicial);
  final String? contornoInicial;

  @override
  State<_Importar> createState() => _ImportarState();
}

class _ImportarState extends State<_Importar> {
  String? _caminhoContorno, _caminhoPrescricao;
  Shapefile? _contorno, _prescricao;
  String? _campo;
  var _unidade = unidades.first;
  final _nome = TextEditingController();
  final _taxaPadrao = TextEditingController(text: '16000');
  String? _erro;

  @override
  void initState() {
    super.initState();
    if (widget.contornoInicial != null) {
      _abrir(widget.contornoInicial!, contorno: true);
    }
  }

  Shapefile? get _fonteDaTaxa => _prescricao ?? _contorno;

  void _abrir(String caminho, {required bool contorno}) {
    try {
      final shp = Shapefile.ler(caminho);
      if (!shp.feicoes.any((f) => f.poligono)) {
        throw const FormatException('não tem polígonos');
      }
      setState(() {
        _erro = null;
        if (contorno) {
          _caminhoContorno = caminho;
          _contorno = shp;
          if (_nome.text.isEmpty) {
            _nome.text = caminho
                .split('/')
                .last
                .replaceAll(RegExp(r'\.shp$', caseSensitive: false), '');
          }
        } else {
          _caminhoPrescricao = caminho;
          _prescricao = shp;
        }
        // pré-seleciona o campo que o nome sugere (TAXA, RATE, DOSE...)
        final fonte = _fonteDaTaxa!;
        _campo =
            Talhao.campoDeTaxaProvavel(fonte) ??
            (fonte.camposNumericos.isEmpty
                ? null
                : fonte.camposNumericos.first.nome);
        _adivinharUnidade();
      });
    } on Exception catch (e) {
      setState(
        () => _erro =
            'Não deu para ler ${caminho.split('/').last}: ${e is FormatException ? e.message : e}',
      );
    }
  }

  // valores pequenos (12, 20) são quase sempre mil sementes/ha
  void _adivinharUnidade() {
    final fonte = _fonteDaTaxa, campo = _campo;
    if (fonte == null || campo == null) return;
    final valores = fonte.feicoes
        .map((f) => f.atributos[campo])
        .whereType<num>()
        .where((v) => v > 0);
    if (valores.isEmpty) return;
    final media = valores.reduce((a, b) => a + b) / valores.length;
    _unidade = media < 200
        ? unidades[1]
        : media < 1000
        ? unidades[2]
        : unidades[0];
  }

  Future<void> _escolher({required bool contorno}) async {
    final arquivo = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Shapefile', extensions: ['shp', 'SHP']),
      ],
    );
    if (arquivo != null) _abrir(arquivo.path, contorno: contorno);
  }

  Talhao? _montar() {
    final contorno = _contorno;
    if (contorno == null) return null;
    try {
      return Talhao.deShapefiles(
        nome: _nome.text.trim().isEmpty ? 'talhão' : _nome.text.trim(),
        contorno: contorno,
        prescricao: _prescricao,
        campoTaxa: _campo,
        fator: _unidade.$2,
        taxaPadrao: int.tryParse(_taxaPadrao.text) ?? 16000,
      );
    } on FormatException catch (e) {
      _erro = e.message;
      return null;
    }
  }

  Widget _arquivo(
    String titulo,
    String? caminho,
    Shapefile? shp, {
    required bool contorno,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(contorno ? Icons.crop_square : Icons.grid_on),
    title: Text(caminho == null ? titulo : caminho.split('/').last),
    subtitle: Text(
      shp == null
          ? (contorno
                ? 'obrigatório'
                : 'opcional: sem ela, as zonas vêm do próprio contorno')
          : '${shp.feicoes.where((f) => f.poligono).length} polígonos · ${shp.sistema}',
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!contorno && shp != null)
          IconButton(
            tooltip: 'tirar',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _prescricao = null;
              _caminhoPrescricao = null;
              _campo = _contorno == null
                  ? null
                  : Talhao.campoDeTaxaProvavel(_contorno!);
            }),
          ),
        FilledButton.tonal(
          onPressed: () => _escolher(contorno: contorno),
          child: const Text('escolher'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final fonte = _fonteDaTaxa;
    final talhao = _montar();
    final taxas = talhao?.zonas.map((z) => z.taxa).toSet().toList()?..sort();
    return AlertDialog(
      title: const Text('Importar talhão (shapefile)'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _arquivo(
                'contorno do talhão',
                _caminhoContorno,
                _contorno,
                contorno: true,
              ),
              _arquivo(
                'mapa de prescrição',
                _caminhoPrescricao,
                _prescricao,
                contorno: false,
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _campo,
                      decoration: InputDecoration(
                        labelText:
                            'campo da taxa${_prescricao == null ? '' : ' (na prescrição)'}',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('nenhum: taxa única'),
                        ),
                        for (final c
                            in fonte?.camposNumericos ?? const <Campo>[])
                          DropdownMenuItem(value: c.nome, child: Text(c.nome)),
                      ],
                      onChanged: (v) => setState(() {
                        _campo = v;
                        _adivinharUnidade();
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<(String, double)>(
                      initialValue: _unidade,
                      decoration: const InputDecoration(
                        labelText: 'unidade do campo',
                      ),
                      items: [
                        for (final u in unidades)
                          DropdownMenuItem(value: u, child: Text(u.$1)),
                      ],
                      onChanged: _campo == null
                          ? null
                          : (v) => setState(() => _unidade = v!),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nome,
                      decoration: const InputDecoration(
                        labelText: 'nome do talhão',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _taxaPadrao,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'taxa padrão (sementes/ha)',
                        helperText: 'onde nenhuma zona cobre',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_erro != null)
                Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (talhao != null)
                Text(
                  taxas!.isEmpty
                      ? 'Taxa única: ${talhao.taxaPadrao} sementes/ha'
                      : '${talhao.zonas.length} zonas: ${taxas.map((t) => '$t').join(', ')} sementes/ha',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('cancelar'),
        ),
        FilledButton(
          onPressed: talhao == null
              ? null
              : () => Navigator.pop(context, talhao),
          child: const Text('importar'),
        ),
      ],
    );
  }
}
