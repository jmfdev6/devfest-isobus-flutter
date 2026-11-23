// agiso.h — o contrato entre o C++ e o Dart
#pragma once
#include <stdint.h>

#define AGISO_API __attribute__((visibility("default")))

#ifdef __cplusplus
extern "C" {
#endif

enum { AGISO_ENDERECO = 1, AGISO_RPM = 2 };

typedef void (*agiso_callback)(int32_t evento, double valor);

AGISO_API int32_t agiso_start(const char *interface, agiso_callback callback);
AGISO_API void agiso_stop(void);

// [passo 7]
// Terminal Virtual: o operador apertou uma soft key
AGISO_API int32_t agiso_vt_apertar(uint16_t tecla);
// [/passo 7]
// [passo 8]
// Task Controller: mandar um valor ao implemento
AGISO_API int32_t agiso_tc_definir(uint16_t elemento, uint16_t ddi, int32_t valor);
// [/passo 8]

#ifdef __cplusplus
}
#endif
