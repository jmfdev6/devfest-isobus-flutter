// teste.c — usa a ponte sem Dart: se funciona aqui, funciona em qualquer FFI
#include "agiso.h"
#include <stdio.h>
#include <unistd.h>

static void ao_evento(int32_t evento, double valor)
{
  if (evento == AGISO_ENDERECO)
    printf("endereço 0x%02X\n", (unsigned)valor);
  if (evento == AGISO_RPM)
    printf("rotação %.1f rpm\n", valor);
  fflush(stdout);
}

int main(int argc, char **argv)
{
  const char *interface = argc > 1 ? argv[1] : "vcan0";
  if (agiso_start(interface, ao_evento) != 0)
  {
    printf("não consegui abrir %s\n", interface);
    return 1;
  }
  sleep(argc > 2 ? 30 : 10);
  agiso_stop();
  return 0;
}
