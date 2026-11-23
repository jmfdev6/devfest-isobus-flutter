// agiso.cpp — a ponte: funções C por fora, AgIsoStack++ por dentro
#include "agiso.h"
// [passo 7]
#include "servicos.hpp"
// [/passo 7]

#include "isobus/hardware_integration/can_hardware_interface.hpp"
#include "isobus/hardware_integration/socket_can_interface.hpp"
#include "isobus/isobus/can_network_manager.hpp"

#include <atomic>
#include <memory>

namespace
{
	std::atomic<agiso_callback> callback{ nullptr };
	std::shared_ptr<isobus::InternalControlFunction> ecu;
	std::atomic<int> ultimoEndereco{ -1 };
	isobus::EventCallbackHandle relogio = 0;

	void avisar(int32_t evento, double valor)
	{
		agiso_callback cb = callback.load();
		if (cb != nullptr)
			cb(evento, valor);
	}

	// PGN 0xF004 (EEC1): bytes 4 e 5 = rotação, 0,125 rpm por bit
	void ao_receber_eec1(const isobus::CANMessage &mensagem, void *)
	{
		if (mensagem.get_data_length() < 5)
			return;
		const uint16_t bruto = mensagem.get_uint16_at(3);
		if (bruto != 0xFFFF)
			avisar(AGISO_RPM, bruto * 0.125);
	}

	// Chamada a cada ciclo da pilha (~4 ms), na thread da pilha
	void a_cada_ciclo()
	{
		if (ecu && ecu->get_address_valid())
		{
			const int endereco = ecu->get_address();
			if (ultimoEndereco.exchange(endereco) != endereco)
				avisar(AGISO_ENDERECO, endereco);
		}
		// [passo 7]
		servicos_ciclo(); // VT e TC também trabalham a cada ciclo
		// [/passo 7]
	}

	isobus::NAME meu_nome()
	{
		isobus::NAME nome(0);
		nome.set_arbitrary_address_capable(true);
		nome.set_industry_group(2); // agricultura
		nome.set_function_code(static_cast<uint8_t>(isobus::NAME::Function::RateControl));
		nome.set_identity_number(2026);
		nome.set_manufacturer_code(1407);
		return nome;
	}
} // namespace

extern "C" int32_t agiso_start(const char *interface, agiso_callback cb)
{
	try
	{
		callback = cb;
		auto driver = std::make_shared<isobus::SocketCANInterface>(interface);
		isobus::CANHardwareInterface::set_number_of_can_channels(1);
		isobus::CANHardwareInterface::assign_can_channel_frame_handler(0, driver);
		if (!isobus::CANHardwareInterface::start() || !driver->get_is_valid())
		{
			isobus::CANHardwareInterface::stop();
			return -1;
		}

		auto &rede = isobus::CANNetworkManager::CANNetwork;
		rede.add_any_control_function_parameter_group_number_callback(0xF004, ao_receber_eec1, nullptr);
		ecu = rede.create_internal_control_function(meu_nome(), 0, 0x81);
		// [passo 7]
		servicos_iniciar(); // liga o VT e o TC
		// [/passo 7]

		// por último: o relógio lê ecu e os serviços, que já existem
		relogio = isobus::CANHardwareInterface::get_periodic_update_event_dispatcher().add_listener(a_cada_ciclo);
		return 0;
	}
	catch (...)
	{
		return -99;
	}
}

extern "C" void agiso_stop(void)
{
	try
	{
		callback = nullptr;
		isobus::CANHardwareInterface::get_periodic_update_event_dispatcher().remove_listener(relogio);
		isobus::CANNetworkManager::CANNetwork.remove_any_control_function_parameter_group_number_callback(0xF004, ao_receber_eec1, nullptr);
		isobus::CANHardwareInterface::stop();
		// [passo 7]
		servicos_parar();
		// [/passo 7]
	}
	catch (...)
	{
	}
}
