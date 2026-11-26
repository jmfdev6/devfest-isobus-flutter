// trator.cpp — o trator da demo: anda num talhão e anuncia na rede onde está.
//
//   ./build/trator [interface] [km/h]          (padrão: vcan0, 8 km/h; Ctrl+C para parar)
//
// Manda, 10 vezes por segundo:
//   NMEA 2000  129025 posição rápida, 129029 posição GNSS, 129026 rumo/velocidade, 127250 proa
//   ISOBUS     0xFE49 velocidade de solo (a plantadeira precisa dela para dosar)
//
// O caminho: passadas norte-sul num talhão de 60 x 120 m, com meia-volta na cabeceira.
// As passadas ficam a 7,6 m uma da outra e a barra tem 9,1 m: na volta, 1,5 m se
// sobrepõe ao que já foi plantado. É ali que o TC (TC-SEC) tem que cortar a seção.
#include "isobus/hardware_integration/can_hardware_interface.hpp"
#include "isobus/hardware_integration/socket_can_interface.hpp"
#include "isobus/isobus/can_network_manager.hpp"
#include "isobus/isobus/nmea2000_message_interface.hpp"

#include <atomic>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <thread>

namespace
{
	// O talhão, em Sinop (MT). Coordenadas locais: leste (e) e norte (n), em metros.
	constexpr double LAT0 = -11.8640, LON0 = -55.5050;
	constexpr double LARGURA_TALHAO = 60, COMPRIMENTO_TALHAO = 120;
	constexpr double PASSADA = 7.6; // distância entre passadas (a barra tem 9,144 m)
	constexpr double PI = 3.14159265358979323846;
	constexpr double METROS_POR_GRAU = 111320;

	std::atomic_bool rodando{ true };

	// Onde o trator está e para onde aponta (rumo: 0 = norte, sentido horário, em radianos)
	struct Pose
	{
		double e, n, rumo;
	};

	// Anda "metros" no caminho de passadas: reta, meia-volta, reta...
	class Caminho
	{
	public:
		Pose andar(double metros)
		{
			if (virando)
			{
				// meia-volta: semicírculo de raio PASSADA/2, por fora do talhão
				angulo += metros / (PASSADA / 2);
				if (angulo >= PI)
				{
					virando = false;
					sentido = -sentido;
					e = centroE + PASSADA / 2;
					n = sentido > 0 ? 0 : COMPRIMENTO_TALHAO;
				}
				else
				{
					// semicírculo com centro em (centroE, cabeceira): no fim da subida vira pela
					// direita (rumo 0 -> 180°), no fim da descida pela esquerda (rumo 180° -> 0)
					const double a = angulo;
					e = centroE - std::cos(a) * PASSADA / 2;
					n = (sentido > 0 ? COMPRIMENTO_TALHAO : 0) + sentido * std::sin(a) * PASSADA / 2;
					rumo = sentido > 0 ? a : PI - a;
					return { e, n, rumo };
				}
			}
			n += sentido * metros;
			rumo = sentido > 0 ? 0 : PI;
			const bool fim = sentido > 0 ? n >= COMPRIMENTO_TALHAO : n <= 0;
			if (fim)
			{
				n = sentido > 0 ? COMPRIMENTO_TALHAO : 0;
				if (e + PASSADA > LARGURA_TALHAO)
				{
					// acabou o talhão: volta ao começo (a cabine continua lembrando o que plantou)
					e = 4.6;
					n = 0;
					sentido = 1;
				}
				else
				{
					virando = true;
					angulo = 0;
					centroE = e + PASSADA / 2;
				}
			}
			return { e, n, rumo };
		}

	private:
		double e = 4.6, n = 0, rumo = 0; // começa com a barra inteira dentro do talhão
		int sentido = 1; // 1 = para o norte
		bool virando = false;
		double angulo = 0, centroE = 0;
	};

	void parar(int)
	{
		rodando = false;
	}
} // namespace

int main(int argc, char **argv)
{
	const char *interface = argc > 1 ? argv[1] : "vcan0";
	const double kmh = argc > 2 ? std::atof(argv[2]) : 8.0;
	const double mps = kmh / 3.6;
	std::signal(SIGINT, parar);
	std::signal(SIGTERM, parar);
	std::setvbuf(stdout, nullptr, _IOLBF, 0);

	auto driver = std::make_shared<isobus::SocketCANInterface>(interface);
	isobus::CANHardwareInterface::set_number_of_can_channels(1);
	isobus::CANHardwareInterface::assign_can_channel_frame_handler(0, driver);
	if (!isobus::CANHardwareInterface::start() || !driver->get_is_valid())
	{
		std::fprintf(stderr, "não consegui abrir %s\n", interface);
		return 1;
	}

	// O trator na rede: o NAME de um trator agrícola (o mesmo do send_velocidade.sh)
	isobus::NAME nome(0);
	nome.set_arbitrary_address_capable(true);
	nome.set_industry_group(2);
	nome.set_function_code(134); // trator
	nome.set_identity_number(2030);
	nome.set_manufacturer_code(1407);
	auto trator = isobus::CANNetworkManager::CANNetwork.create_internal_control_function(nome, 0, 0x01);
	while (rodando && !trator->get_address_valid())
		std::this_thread::sleep_for(std::chrono::milliseconds(50));
	std::printf("trator na rede como 0x%02X, %.1f km/h em %s (Ctrl+C para parar)\n", trator->get_address(), kmh, interface);

	// O GPS: a AgIsoStack++ monta e manda as mensagens NMEA 2000 sozinha, no ritmo da norma
	isobus::NMEA2000MessageInterface gps(trator, true, false, true, false, true, false, true);
	gps.initialize();

	Caminho caminho;
	double distancia_mm = 0;
	auto proximo = std::chrono::steady_clock::now();
	int ciclo = 0;
	while (rodando)
	{
		const Pose p = caminho.andar(mps * 0.1);
		const double lat = LAT0 + p.n / METROS_POR_GRAU;
		const double lon = LON0 + p.e / (METROS_POR_GRAU * std::cos(LAT0 * PI / 180));
		const auto rumo = static_cast<std::uint16_t>(std::lround(p.rumo / 0.0001));

		gps.get_position_rapid_update_transmit_message().set_latitude(static_cast<std::int32_t>(std::lround(lat / 1e-7)));
		gps.get_position_rapid_update_transmit_message().set_longitude(static_cast<std::int32_t>(std::lround(lon / 1e-7)));
		auto &completa = gps.get_gnss_position_data_transmit_message();
		completa.set_latitude(static_cast<std::int64_t>(lat / 1e-16));
		completa.set_longitude(static_cast<std::int64_t>(lon / 1e-16));
		completa.set_gnss_method(isobus::NMEA2000Messages::GNSSPositionData::GNSSMethod::RTKFixedInteger);
		completa.set_number_of_space_vehicles(14);
		auto &cogSog = gps.get_cog_sog_transmit_message();
		cogSog.set_course_over_ground_reference(isobus::NMEA2000Messages::CourseOverGroundSpeedOverGroundRapidUpdate::CourseOverGroundReference::True);
		cogSog.set_course_over_ground(rumo);
		cogSog.set_speed_over_ground(static_cast<std::uint16_t>(std::lround(mps / 0.01)));
		gps.get_vessel_heading_transmit_message().set_heading(rumo);
		gps.update();

		// 0xFE49: bytes 0-1 velocidade (mm/s), 2-5 distância (mm), 7 = para frente
		distancia_mm += mps * 100;
		const auto mms = static_cast<std::uint16_t>(std::lround(mps * 1000));
		const auto dist = static_cast<std::uint32_t>(distancia_mm);
		const std::uint8_t solo[8] = { static_cast<std::uint8_t>(mms), static_cast<std::uint8_t>(mms >> 8),
			                             static_cast<std::uint8_t>(dist), static_cast<std::uint8_t>(dist >> 8),
			                             static_cast<std::uint8_t>(dist >> 16), static_cast<std::uint8_t>(dist >> 24), 0xFF, 0x01 };
		isobus::CANNetworkManager::CANNetwork.send_can_message(0xFE49, solo, sizeof(solo), trator);

		if (++ciclo % 50 == 0) // a cada 5 s
			std::printf("e=%.1f n=%.1f m  rumo %.0f°  lat %.7f lon %.7f\n", p.e, p.n, p.rumo * 180 / PI, lat, lon);

		proximo += std::chrono::milliseconds(100);
		std::this_thread::sleep_until(proximo);
	}
	isobus::CANHardwareInterface::stop();
	return 0;
}
