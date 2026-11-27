// banco.dart — olha o banco local (talhões, trabalhos e mapas de aplicação)
//
//   dart run bin/banco.dart                 lista o que está guardado
//   dart run bin/banco.dart verificar       ida e volta num banco temporário
import 'dart:io';

import 'package:agiso/banco.dart';
import 'package:agiso/geo.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'verificar') return verificar();
  final banco = Banco.abrir();
  print('banco: ${Banco.caminhoPadrao()}');
  for (final t in await banco.listarTalhoes()) {
    print('${t.ativo ? '*' : ' '} talhão ${t.id}: ${t.nome}');
    for (final j in await banco.trabalhosDo(t.id)) {
      print(
        '    trabalho ${j.id}: ${j.inicio.toLocal()}  ${j.hectares.toStringAsFixed(3)} ha  '
        '${j.sementes.toStringAsFixed(0)} sementes  ${j.distanciaM.toStringAsFixed(0)} m'
        '${j.fim == null ? '  (em andamento)' : ''}',
      );
    }
  }
  await banco.close();
}

Future<void> verificar() async {
  final pasta = Directory.systemTemp.createTempSync('banco');
  final banco = Banco.abrir('${pasta.path}/teste.sqlite');
  try {
    final t = Talhao.padrao();
    final id = await banco.salvarTalhao(t);
    final lido = (await banco.talhaoAtivo())!;
    // o talhão volta igual: mesma origem, mesmas zonas, mesma taxa num ponto conhecido
    const meio = (e: 30.0, n: 60.0); // o meio do talhão, na zona de 20 mil
    check(
      lido.id == id && (lido.talhao.lat0 - t.lat0).abs() < 1e-12,
      'talhão ativo',
    );
    check(lido.talhao.zonas.length == 3, 'zonas');
    check(
      lido.talhao.taxa(meio.e, meio.n) == t.taxa(meio.e, meio.n) &&
          t.taxa(meio.e, meio.n) == 20000,
      'taxa no meio do talhão',
    );

    // um trabalho com um pedaço plantado a 20 mil: grava, relê, e as contas batem
    final trabalho = await banco.iniciarTrabalho(id);
    final mapa = MapaAplicacao.para(t);
    for (var e = 10.0; e < 20; e += 0.5) {
      for (var n = 10.0; n < 30; n += 0.5) {
        mapa.marcar(e, n, 20000);
      }
    }
    // e uma faixa plantada de novo 100 s depois: sobreposição
    for (var n = 10.0; n < 30; n += 0.5) {
      mapa.marcar(10.2, n, 20000, agora: 1000);
    }
    await banco.salvarTrabalho(trabalho, mapa, distancia: 123);
    check(
      (await banco.trabalhoAberto(id))?.id == trabalho,
      'trabalho em andamento',
    );
    final relido = (await banco.mapaDoTrabalho(trabalho))!;
    check(
      relido.plantadas == mapa.plantadas && relido.plantadas == 800,
      'células plantadas',
    );
    check((relido.hectares - 0.02).abs() < 1e-9, 'área (20 x 10 m = 0,02 ha)');
    check(
      relido.sobrepostasN == 40 && mapa.sobrepostasN == 40,
      'sobreposição guardada (40 células)',
    );
    // 0,02 ha a 20 mil = 400, mais 40 células de 0,25 m² plantadas de novo = 20
    check((relido.sementes - 420).abs() < 1e-6, 'sementes, com a sobreposição');
    await banco.salvarTrabalho(trabalho, relido, encerrar: true);
    check(await banco.trabalhoAberto(id) == null, 'trabalho encerrado');
    print('banco: ok');
  } finally {
    await banco.close();
    pasta.deleteSync(recursive: true);
  }
}

void check(bool ok, String o) {
  if (ok) return;
  print('banco: FALHOU ($o)');
  exit(1);
}
