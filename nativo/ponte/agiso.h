// agiso.h — o contrato entre o C++ e o Dart
#pragma once
#include <stdint.h>

#define AGISO_API __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif

// AGISO_TAXA: o implemento informou a taxa alvo (DDI 11) ao Task Controller
// AGISO_SECOES: o estado real das seções 1-16 (DDI 161), 2 bits por seção: 00 desligada, 01 ligada, 11 não existe
// AGISO_DEPOSITO: sementes que restam no depósito (DDI 78)
// AGISO_LAT / AGISO_LON: posição do GPS (NMEA 2000 129025), em graus
// AGISO_RUMO: rumo sobre o solo em graus (0 = norte, sentido horário); AGISO_VELOCIDADE: m/s (129026)
enum
{
	AGISO_ENDERECO = 1,
	AGISO_RPM = 2,
	AGISO_TAXA = 3,
	AGISO_SECOES = 4,
	AGISO_DEPOSITO = 5,
	AGISO_LAT = 6,
	AGISO_LON = 7,
	AGISO_RUMO = 8,
	AGISO_VELOCIDADE = 9
};

typedef void (*agiso_callback)(int32_t evento, double valor);

// A cabine: entra na rede com VT e TC
AGISO_API int32_t agiso_start(const char *interface, agiso_callback callback);
// Só escuta: GPS, rotação e as seções que o implemento informa ao TC. Sem VT nem TC
// (é o que o simulador 3D usa, ao lado da cabine, sem brigar com ela).
AGISO_API int32_t agiso_start_ouvinte(const char *interface, agiso_callback callback);
// O trator dirigível (simulador): como o ouvinte, e além disso É o trator na rede.
// Manda, no ritmo da norma, o GPS NMEA 2000 (129025, 129029, 129026, 127250), a
// velocidade de solo (0xFE49) e a rotação do motor (EEC1, 0xF004) que agiso_trator_mover definir.
AGISO_API int32_t agiso_start_trator(const char *interface, agiso_callback callback);
// Onde o trator está: graus, rumo em graus (0 = norte, horário), m/s (negativo = ré), rpm
AGISO_API void agiso_trator_mover(double lat, double lon, double rumo, double velocidade, double rpm);
AGISO_API void agiso_stop(void);

// [passo 7]
// Terminal Virtual: o operador tocou numa soft key, botão ou caixa de seleção (pelo ID do objeto)
AGISO_API int32_t agiso_vt_apertar(uint16_t tecla);
// [/passo 7]
// [passo 10]
// A tela do VT como lista de desenho em JSON. Retorna o tamanho; se for maior
// que o buffer, nada é copiado e o chamador tenta de novo com um buffer maior.
// -1 = nenhum implemento mostrando tela.
AGISO_API int32_t agiso_vt_tela(char *destino, int32_t tamanho);
// Uma figura da tela em RGBA (4 bytes por pixel). Mesmo protocolo de tamanho.
AGISO_API int32_t agiso_vt_figura(uint16_t id, uint8_t *rgba, int32_t tamanho, int32_t *largura, int32_t *altura);
// [/passo 10]
// [passo 8]
// Task Controller: mandar um valor ao implemento
AGISO_API int32_t agiso_tc_definir(uint16_t elemento, uint16_t ddi, int32_t valor);
// [/passo 8]

#ifdef __cplusplus
}
#endif
