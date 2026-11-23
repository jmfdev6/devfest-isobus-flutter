# Como contribuir

Obrigado pelo interesse! Este projeto existe para ensinar, então dúvidas também são contribuições.

## Encontrou um problema ou tem uma dúvida?

Abra uma [issue](../../issues) contando:

1. o que você tentou (o comando exato);
2. o que esperava ver;
3. o que apareceu (cole a saída do terminal);
4. sua distro e a saída de `flutter --version`.

## Quer mandar código?

1. Faça um fork e crie um branch: `git checkout -b minha-melhoria`
2. Faça a mudança e confira que tudo ainda funciona:
   ```bash
   cmake -S . -B build -G Ninja && cmake --build build
   (cd dart && dart analyze)
   (cd app && flutter analyze)
   ```
   E rode o [passo 4 do README](README.md#passo-4-testar-a-ponte-sem-dart).
3. Faça commit com uma mensagem clara: `git commit -m "Explica o DDI no tc.cpp"`
4. Abra um Pull Request explicando o que mudou e por quê.

## Estilo

- Código, nomes e comentários em **português**, como no resto do projeto.
- Mudanças pequenas e focadas. Este é um projeto didático: código simples vence código esperto.
- Dart: `dart format .` antes de enviar.
