# Glossário

| Termo | Definição |
|---|---|
| **Address Claim** | o anúncio, no J1939/ISO 11783-5, do endereço (0–253) que uma ECU vai usar, junto com o NAME dela |
| **AgIsoStack++** | pilha ISOBUS aberta em C++ da Open-Agriculture; faz o trabalho pesado do protocolo |
| **As-applied** | mapa de aplicação: o que de fato foi aplicado, onde |
| **Cabeceira** | a faixa nas bordas do talhão onde o trator manobra; é plantada no fim |
| **CAN** | *Controller Area Network*: barramento serial com mensagens de até 8 bytes e identificadores de 11 ou 29 bits |
| **COG / SOG** | *Course / Speed Over Ground*: rumo e velocidade sobre o solo, medidos pelo GNSS |
| **Condensed Work State** | DDIs 161 e 290: o estado de até 16 seções em 2 bits cada |
| **DDI** | *Data Dictionary Identifier*: o número de uma grandeza no dicionário ISO 11783-11 (taxa, área, estado de seção…) |
| **DDOP** | *Device Descriptor Object Pool*: a descrição que o implemento manda ao TC (elementos, dados, geometria) |
| **DET / DPD** | *Device Element* / *Device Process Data*: objetos do DDOP |
| **ECU** | *Electronic Control Unit*: cada nó da rede |
| **EEC1** | *Electronic Engine Controller 1*, PGN `0xF004`: rotação do motor |
| **Engate** | o pino em que a plantadeira rebocada gira |
| **ETP / TP** | protocolos de transporte (estendido) para mensagens maiores que 8 bytes |
| **FFI** | *Foreign Function Interface*: `dart:ffi`, chamar C a partir do Dart |
| **Flutter GPU** | API de baixo nível do Flutter para desenhar com a GPU; base do flutter_scene |
| **ISOBUS** | ISO 11783: rede de tratores e implementos agrícolas, baseada no J1939 |
| **J1939** | norma SAE de rede para veículos pesados; endereçamento e PGNs |
| **Mapa de prescrição** | as zonas do talhão com a taxa desejada em cada uma |
| **NAME** | identificador único de 64 bits de uma ECU (fabricante, função, instância…) |
| **NMEA 2000** | padrão de mensagens de navegação sobre CAN (PGNs 129025, 129026, 129029, 127250…) |
| **Object pool** | a descrição da interface que o implemento manda ao VT |
| **Passada** | um percurso em linha reta do trator pelo talhão |
| **PGN** | *Parameter Group Number*: o "tipo" de uma mensagem J1939 |
| **Process data** | PGN `0xCB00`: a troca de valores entre TC e implemento |
| **Seção** | parte da barra que liga e desliga separada (aqui, 6 de 1,524 m) |
| **SocketCAN** | a API de CAN do kernel Linux; `vcan` é a interface virtual |
| **Soft key** | tecla programável ao lado da tela do VT |
| **Talhão** | a área de lavoura com contorno definido |
| **Taxa** | sementes por hectare |
| **TC** | *Task Controller*, ISO 11783-10. TC-BAS: totais; TC-GEO: taxa pela posição; TC-SEC: controle de seções |
| **Tractrix** | a curva descrita por um objeto puxado por uma haste de comprimento fixo: a plantadeira rebocada |
| **UTM** | *Universal Transverse Mercator*: projeção em metros, em zonas de 6° de longitude |
| **vcan0** | interface CAN virtual do Linux |
| **VT** | *Virtual Terminal*, ISO 11783-6: a tela universal da cabine |
| **WAL** | *Write-Ahead Logging*: modo do SQLite que deixa ler enquanto outro processo escreve |
