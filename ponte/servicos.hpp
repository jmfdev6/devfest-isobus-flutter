// servicos.hpp — os serviços da cabine: Terminal Virtual e Task Controller
#pragma once

void vt_iniciar();
void vt_ciclo();
void vt_parar();

// [passo 8]
void tc_iniciar();
void tc_ciclo();
void tc_parar();
// [/passo 8]

inline void servicos_iniciar()
{
	vt_iniciar();
	// [passo 8]
	tc_iniciar();
	// [/passo 8]
}

inline void servicos_ciclo()
{
	vt_ciclo();
	// [passo 8]
	tc_ciclo();
	// [/passo 8]
}

inline void servicos_parar()
{
	vt_parar();
	// [passo 8]
	tc_parar();
	// [/passo 8]
}
