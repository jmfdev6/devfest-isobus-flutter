# Contribuir

Contribuições são bem-vindas, principalmente de quem está começando. As regras estão no [CONTRIBUTING.md](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/CONTRIBUTING.md) e no [Código de Conduta](https://github.com/jmfdev6/devfest-isobus-flutter/blob/main/CODE_OF_CONDUCT.md).

## Antes do pull request

```bash
./demo.sh testar
```

Precisa terminar com `tudo certo`. O CI roda a análise e os autotestes que não dependem da rede CAN.

## Onde mexer

| Quero… | Arquivo |
|---|---|
| uma função nova na ponte | `nativo/ponte/agiso.h` (contrato) + `agiso.cpp` + `pacotes/agiso/lib/agiso.dart` |
| desenhar um objeto VT novo | `nativo/ponte/vt.cpp` (`Pintor::objeto`) + `apps/cabine/lib/tela_vt.dart` |
| outro DDI no TC | `nativo/ponte/tc.cpp` (`on_value_command` → `avisar`) + um evento novo |
| outra regra de corte de seção | `TcAutomatico.aoGps` em `pacotes/agiso/lib/geo.dart` |

## Convenções

- O código e os comentários são em **português**, como a palestra.
- Comentários explicam o **porquê**; os `// [passo N]` marcam as etapas da palestra.
- Cada módulo com lógica tem um **autoteste** executável (`dart --enable-asserts arquivo.dart` ou `bin/*.dart verificar`). Mudou a lógica? Atualize o autoteste.
- Commits pequenos, com mensagem dizendo o que mudou e por quê.

## Esta documentação

Os arquivos estão em [`docs/`](https://github.com/jmfdev6/devfest-isobus-flutter/tree/main/docs) e a navegação no `mkdocs.yml`. Para ver localmente:

```bash
pip install mkdocs-material
mkdocs serve
```

Um push na `main` que mexa em `docs/` ou no `mkdocs.yml` publica o site.
