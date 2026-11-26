// agiso.cpp — a ponte: funções C por fora, AgIsoStack++ por dentro
#include "agiso.h"
// [passo 7]
#include "servicos.hpp"
// [/passo 7]

#include "isobus/hardware_integration/can_hardware_interface.hpp"
#include "isobus/hardware_integration/socket_can_interface.hpp"
#include "isobus/isobus/can_network_manager.hpp"
#include "isobus/isobus/nmea2000_message_interface.hpp"

#include "isobus/utility/system_timing.hpp"

#include <atomic>
#include <cmath>
#include <cstdio>
#include <memory>
#include <mutex>

namespace
{
	std::atomic<agiso_callback> callback{ nullptr };
	std::shared_ptr<isobus::InternalControlFunction> ecu;
	std::unique_ptr<isobus::NMEA2000MessageInterface> gps;
	std::atomic<int> ultimoEndereco{ -1 };
	isobus::EventCallbackHandle relogio = 0, quadros = 0;
	enum class Modo
	{
		cabine, // VT e TC
		ouvinte, // só escuta
		trator // escuta e é o trator: manda GPS, velocidade e rotação
	};
	Modo modo = Modo::cabine;

	// O estado do trator que o Dart (o simulador) define; a pilha manda no seu ritmo
	struct EstadoTrator
	{
		double lat = 0, lon = 0, rumo = 0, velocidade = 0, rpm = 0;
		bool valido = false;
	};
	std::mutex mutexTrator;
	EstadoTrator trator;
	double distanciaMm = 0;
	std::uint32_t ultimoEnvio = 0;
} // namespace

void avisar(int32_t evento, double valor)
{
	agiso_callback cb = callback.load();
	if (cb != nullptr)
		cb(evento, valor);
}

namespace
{
	constexpr double PI = 3.14159265358979323846;

	// PGN 0xF004 (EEC1): bytes 4 e 5 = rotação, 0,125 rpm por bit
	void ao_receber_eec1(const isobus::CANMessage &mensagem, void *)
	{
		if (mensagem.get_data_length() < 5)
			return;
		const uint16_t bruto = mensagem.get_uint16_at(3);
		if (bruto != 0xFFFF)
			avisar(AGISO_RPM, bruto * 0.125);
	}

	// NMEA 2000: a AgIsoStack++ decodifica, aqui só repassamos ao Dart
	void ao_receber_posicao(const std::shared_ptr<isobus::NMEA2000Messages::PositionRapidUpdate> m, bool)
	{
		if (m->get_raw_latitude() == isobus::NMEA2000Messages::PositionRapidUpdate::NOT_AVAILABLE)
			return;
		avisar(AGISO_LAT, m->get_latitude());
		avisar(AGISO_LON, m->get_longitude());
	}

	void ao_receber_rumo(const std::shared_ptr<isobus::NMEA2000Messages::CourseOverGroundSpeedOverGroundRapidUpdate> m, bool)
	{
		avisar(AGISO_RUMO, m->get_course_over_ground() * 180 / PI);
		avisar(AGISO_VELOCIDADE, m->get_speed_over_ground());
	}

	// Modo ouvinte: sem TC próprio, as seções vêm escutando o que o implemento manda ao TC.
	// Dados de processo (PGN 0xCB00), 8 bytes: comando (4 bits) | elemento (12 bits) | DDI (16) | valor (32)
	void ao_receber_quadro(const isobus::CANMessageFrame &q)
	{
		if (((q.identifier >> 16) & 0xFF) != 0xCB || q.dataLength != 8)
			return;
		const int comando = q.data[0] & 0x0F;
		const int elemento = (q.data[0] >> 4) | (q.data[1] << 4);
		const int ddi = q.data[2] | (q.data[3] << 8);
		const int32_t valor = static_cast<int32_t>(q.data[4] | (q.data[5] << 8) | (q.data[6] << 16) | (static_cast<uint32_t>(q.data[7]) << 24));
		if (comando != 0x03) // 0x03 = valor
			return;
		if (elemento == 2 && ddi == 161) // o estado real das seções
			avisar(AGISO_SECOES, valor);
		if (elemento == 3 && ddi == 11) // a taxa que a plantadeira está aplicando
			avisar(AGISO_TAXA, valor);
	}

	// Modo trator: põe o estado atual nas mensagens NMEA 2000 (a interface manda no ritmo
	// da norma) e, a cada 100 ms, manda a velocidade de solo e a rotação do motor
	void mandar_trator()
	{
		EstadoTrator t;
		{
			std::lock_guard<std::mutex> trava(mutexTrator);
			t = trator;
		}
		if (!t.valido || !ecu || !ecu->get_address_valid())
			return;
		const auto rumo = static_cast<std::uint16_t>(std::lround(std::fmod(t.rumo + 360, 360) * PI / 180 / 0.0001));
		gps->get_position_rapid_update_transmit_message().set_latitude(static_cast<std::int32_t>(std::lround(t.lat / 1e-7)));
		gps->get_position_rapid_update_transmit_message().set_longitude(static_cast<std::int32_t>(std::lround(t.lon / 1e-7)));
		auto &completa = gps->get_gnss_position_data_transmit_message();
		completa.set_latitude(static_cast<std::int64_t>(t.lat / 1e-16));
		completa.set_longitude(static_cast<std::int64_t>(t.lon / 1e-16));
		completa.set_gnss_method(isobus::NMEA2000Messages::GNSSPositionData::GNSSMethod::RTKFixedInteger);
		completa.set_number_of_space_vehicles(14);
		auto &cogSog = gps->get_cog_sog_transmit_message();
		cogSog.set_course_over_ground_reference(isobus::NMEA2000Messages::CourseOverGroundSpeedOverGroundRapidUpdate::CourseOverGroundReference::True);
		cogSog.set_course_over_ground(rumo);
		cogSog.set_speed_over_ground(static_cast<std::uint16_t>(std::lround(std::fabs(t.velocidade) / 0.01)));
		gps->get_vessel_heading_transmit_message().set_heading(rumo);

		if (!isobus::SystemTiming::time_expired_ms(ultimoEnvio, 100))
			return;
		ultimoEnvio = isobus::SystemTiming::get_timestamp_ms();
		auto &rede = isobus::CANNetworkManager::CANNetwork;
		// 0xFE49: velocidade (mm/s), distância (mm), byte 7 = sentido (01 frente, 00 ré)
		distanciaMm += std::fabs(t.velocidade) * 100;
		const auto mms = static_cast<std::uint16_t>(std::lround(std::fabs(t.velocidade) * 1000));
		const auto dist = static_cast<std::uint32_t>(distanciaMm);
		const std::uint8_t solo[8] = { static_cast<std::uint8_t>(mms), static_cast<std::uint8_t>(mms >> 8),
			                             static_cast<std::uint8_t>(dist), static_cast<std::uint8_t>(dist >> 8),
			                             static_cast<std::uint8_t>(dist >> 16), static_cast<std::uint8_t>(dist >> 24),
			                             0xFF, static_cast<std::uint8_t>(t.velocidade < 0 ? 0x00 : 0x01) };
		rede.send_can_message(0xFE49, solo, sizeof(solo), ecu);
		// EEC1 (0xF004): bytes 4 e 5 = rotação, 0,125 rpm por bit
		const auto bruto = static_cast<std::uint16_t>(std::lround(t.rpm / 0.125));
		const std::uint8_t motor[8] = { 0xFF, 0xFF, 0xFF, static_cast<std::uint8_t>(bruto), static_cast<std::uint8_t>(bruto >> 8), 0xFF, 0xFF, 0xFF };
		rede.send_can_message(0xF004, motor, sizeof(motor), ecu);
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
		if (modo == Modo::trator)
			mandar_trator();
		if (gps)
			gps->update();
		// [passo 7]
		if (modo == Modo::cabine)
			servicos_ciclo(); // VT e TC também trabalham a cada ciclo
		// [/passo 7]
	}

	isobus::NAME meu_nome(Modo m)
	{
		isobus::NAME nome(0);
		nome.set_arbitrary_address_capable(true);
		nome.set_industry_group(2); // agricultura
		if (m == Modo::trator)
			nome.set_function_code(134); // trator
		else
			nome.set_function_code(static_cast<uint8_t>(isobus::NAME::Function::RateControl));
		// cada papel é um equipamento diferente na rede
		nome.set_identity_number(m == Modo::cabine ? 2026 : m == Modo::ouvinte ? 2031 : 2032);
		nome.set_manufacturer_code(1407);
		return nome;
	}

	int32_t iniciar(const char *interface, agiso_callback cb, Modo m)
	{
		try
		{
			// VT e TC escrevem com printf; redirecionado para arquivo, o C guardaria
			// tudo em buffer. Linha a linha, o log sai na hora.
			std::setvbuf(stdout, nullptr, _IOLBF, 0);
			callback = cb;
			modo = m;
			const bool cabine = m == Modo::cabine;
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
			ecu = rede.create_internal_control_function(meu_nome(m), 0, cabine ? 0x81 : m == Modo::trator ? 0x01 : 0x90);

			// o GPS: recebe sempre; no modo trator, também manda (posição, rumo/velocidade, proa)
			const bool manda = m == Modo::trator;
			gps.reset(new isobus::NMEA2000MessageInterface(ecu, manda, false, manda, false, manda, false, manda));
			gps->get_position_rapid_update_event_publisher().add_listener(ao_receber_posicao);
			gps->get_course_speed_over_ground_rapid_update_event_publisher().add_listener(ao_receber_rumo);
			gps->initialize();

			// [passo 7]
			if (cabine)
				servicos_iniciar(); // liga o VT e o TC
			// [/passo 7]
			else
				quadros = isobus::CANHardwareInterface::get_can_frame_received_event_dispatcher().add_listener(ao_receber_quadro);

			// por último: o relógio lê ecu e os serviços, que já existem
			relogio = isobus::CANHardwareInterface::get_periodic_update_event_dispatcher().add_listener(a_cada_ciclo);
			return 0;
		}
		catch (...)
		{
			return -99;
		}
	}
} // namespace

extern "C" int32_t agiso_start(const char *interface, agiso_callback cb)
{
	return iniciar(interface, cb, Modo::cabine);
}

extern "C" int32_t agiso_start_ouvinte(const char *interface, agiso_callback cb)
{
	return iniciar(interface, cb, Modo::ouvinte);
}

extern "C" int32_t agiso_start_trator(const char *interface, agiso_callback cb)
{
	return iniciar(interface, cb, Modo::trator);
}

extern "C" void agiso_trator_mover(double lat, double lon, double rumo, double velocidade, double rpm)
{
	std::lock_guard<std::mutex> trava(mutexTrator);
	trator.lat = lat;
	trator.lon = lon;
	trator.rumo = rumo;
	trator.velocidade = velocidade;
	trator.rpm = rpm;
	trator.valido = true;
}

extern "C" void agiso_stop(void)
{
	try
	{
		callback = nullptr;
		isobus::CANHardwareInterface::get_periodic_update_event_dispatcher().remove_listener(relogio);
		isobus::CANHardwareInterface::get_can_frame_received_event_dispatcher().remove_listener(quadros);
		isobus::CANNetworkManager::CANNetwork.remove_any_control_function_parameter_group_number_callback(0xF004, ao_receber_eec1, nullptr);
		isobus::CANHardwareInterface::stop();
		if (gps)
			gps->terminate();
		gps.reset();
		// [passo 7]
		if (modo == Modo::cabine)
			servicos_parar();
		// [/passo 7]
	}
	catch (...)
	{
	}
}
