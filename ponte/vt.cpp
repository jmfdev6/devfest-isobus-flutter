// vt.cpp — um Terminal Virtual mínimo: recebe a tela e mostra em texto
#include "agiso.h"
#include "servicos.hpp"

#include "isobus/isobus/can_network_manager.hpp"
#include "isobus/isobus/isobus_virtual_terminal_server.hpp"
#include "isobus/utility/system_timing.hpp"

#include <cstdio>
#include <map>
#include <memory>
#include <string>

using namespace isobus;
using Implemento = std::shared_ptr<VirtualTerminalServerManagedWorkingSet>;

class TelaDaCabine : public VirtualTerminalServer
{
public:
	explicit TelaDaCabine(std::shared_ptr<InternalControlFunction> ecu) :
	  VirtualTerminalServer(ecu) {}

	void ciclo() { update(); } // update() é protected: expomos aqui

	// --- 1. Como é esta tela (perguntas obrigatórias da norma) ---
	bool get_is_enough_memory(std::uint32_t) const override { return true; }
	VTVersion get_version() const override { return VTVersion::Version4; }
	std::uint8_t get_number_of_navigation_soft_keys() const override { return 0; }
	std::uint8_t get_soft_key_descriptor_x_pixel_width() const override { return 80; }
	std::uint8_t get_soft_key_descriptor_y_pixel_height() const override { return 80; }
	std::uint8_t get_number_of_possible_virtual_soft_keys_in_soft_key_mask() const override { return 6; }
	std::uint8_t get_number_of_physical_soft_keys() const override { return 6; }
	std::uint16_t get_data_mask_area_size_x_pixels() const override { return 480; }
	std::uint16_t get_data_mask_area_size_y_pixels() const override { return 480; }
	std::vector<std::uint8_t> get_supported_objects() const override
	{
		std::vector<std::uint8_t> tipos;
		for (std::uint8_t t = 0; t <= 37; t++)
			tipos.push_back(t);
		return tipos;
	}

	// --- 2. Coisas que a demo não usa: respostas mínimas ---
	void suspend_working_set(Implemento) override {}
	SupportedWideCharsErrorCode get_supported_wide_chars(std::uint8_t, std::uint16_t, std::uint16_t, std::uint8_t &n, std::vector<std::uint8_t> &) override
	{
		n = 0;
		return SupportedWideCharsErrorCode::AnyOtherError;
	}
	std::vector<std::array<std::uint8_t, 7>> get_versions(NAME) override { return {}; }
	std::vector<std::array<std::uint8_t, 32>> get_extended_versions(NAME) override { return {}; }
	std::vector<std::uint8_t> load_version(const std::vector<std::uint8_t> &, NAME) override { return {}; }
	bool save_version(const std::vector<std::uint8_t> &, const std::vector<std::uint8_t> &, NAME) override { return true; }
	bool delete_version(const std::vector<std::uint8_t> &, NAME) override { return true; }
	bool delete_all_versions(std::uint8_t, NAME) override { return true; }
	bool delete_object_pool(NAME) override { return true; }
	void handle_unexpected_working_set_shutdown(Implemento, UnexpectedShutdownReason) override
	{
		std::printf("VT  | o implemento sumiu\n");
	}
	std::uint16_t abort_input(Implemento) override { return NULL_OBJECT_ID; }

	// --- 3. A tela chegou ---
	void object_pool_parse_finished(Implemento ws, bool ok) override
	{
		std::printf("VT  | tela do implemento 0x%02X %s\n", ws->get_control_function()->get_address(), ok ? "ACEITA" : "REJEITADA");
		mostrar(ws);
	}

	// --- 4. Ler a tela: o texto de cada objeto da máscara ativa, por ID ---
	std::map<std::uint16_t, std::string> textos(Implemento ws)
	{
		std::map<std::uint16_t, std::string> tela;
		auto mascara = ws->get_object_by_id(activeWorkingSetDataMaskObjectID);
		for (std::uint16_t i = 0; mascara && (i < mascara->get_number_children()); i++)
		{
			auto objeto = ws->get_object_by_id(mascara->get_child_id(i));
			if (objeto && (objeto->get_object_type() == VirtualTerminalObjectType::OutputString))
			{
				std::string texto = std::static_pointer_cast<OutputString>(objeto)->get_value();
				texto.erase(texto.find_last_not_of(' ') + 1);
				tela[objeto->get_id()] = latin1_para_utf8(texto);
			}
			if (objeto && (objeto->get_object_type() == VirtualTerminalObjectType::OutputNumber))
			{
				// valor = (variável + offset) x escala
				auto numero = std::static_pointer_cast<OutputNumber>(objeto);
				auto variavel = std::dynamic_pointer_cast<NumberVariable>(ws->get_object_by_id(numero->get_variable_reference()));
				const double valor = ((variavel ? variavel->get_value() : numero->get_value()) + numero->get_offset()) * numero->get_scale();
				char buf[32];
				std::snprintf(buf, sizeof(buf), "%.*f", numero->get_number_of_decimals(), valor);
				tela[objeto->get_id()] = buf;
			}
		}
		return tela;
	}

	// A primeira vez mostra tudo; depois, só o que mudou
	void mostrar(Implemento ws)
	{
		std::string linha;
		for (const auto &item : textos(ws))
		{
			if (ultimaTela[item.first] != item.second)
				linha += std::to_string(item.first) + "=\"" + item.second + "\"  ";
			ultimaTela[item.first] = item.second;
		}
		if (!linha.empty())
			std::printf("VT  | %s\n", linha.c_str());
	}

	// O VT usa fontes Latin-1 (Ç = 1 byte); o terminal espera UTF-8
	static std::string latin1_para_utf8(const std::string &entrada)
	{
		std::string saida;
		for (unsigned char c : entrada)
		{
			if (c < 0x80)
				saida += static_cast<char>(c);
			else
			{
				saida += static_cast<char>(0xC0 | (c >> 6));
				saida += static_cast<char>(0x80 | (c & 0x3F));
			}
		}
		return saida;
	}

	// --- 5. O operador apertou uma tecla: o VT só avisa o implemento ---
	bool apertar(std::uint16_t tecla)
	{
		auto ws = get_active_working_set();
		if (!ws)
			return false;
		auto mascara = std::dynamic_pointer_cast<DataMask>(ws->get_object_by_id(activeWorkingSetDataMaskObjectID));
		auto key = std::dynamic_pointer_cast<Key>(ws->get_object_by_id(tecla));
		if (!mascara || !key)
			return false;
		auto dono = ws->get_control_function();
		send_soft_key_activation_message(KeyActivationCode::ButtonPressedOrLatched, tecla, mascara->get_soft_key_mask(), key->get_key_code(), dono);
		return send_soft_key_activation_message(KeyActivationCode::ButtonUnlatchedOrReleased, tecla, mascara->get_soft_key_mask(), key->get_key_code(), dono);
	}

	std::map<std::uint16_t, std::string> ultimaTela;
};

namespace
{
	std::shared_ptr<InternalControlFunction> ecuVT;
	std::unique_ptr<TelaDaCabine> vt;
	std::uint32_t ultimaOlhada = 0;
} // namespace

void vt_iniciar()
{
	NAME nome(0);
	nome.set_arbitrary_address_capable(true);
	nome.set_industry_group(2);
	nome.set_function_code(static_cast<std::uint8_t>(NAME::Function::VirtualTerminal));
	nome.set_identity_number(2027);
	nome.set_manufacturer_code(1407);
	ecuVT = CANNetworkManager::CANNetwork.create_internal_control_function(nome, 0, 0x26);
	vt.reset(new TelaDaCabine(ecuVT));
	vt->initialize();
}

void vt_ciclo()
{
	if (!vt)
		return;
	vt->ciclo();
	// a cada 2 s, mostra o que mudou na tela
	auto ws = vt->get_active_working_set();
	if (ws && SystemTiming::time_expired_ms(ultimaOlhada, 2000))
	{
		ultimaOlhada = SystemTiming::get_timestamp_ms();
		vt->mostrar(ws);
	}
}

void vt_parar()
{
	vt.reset();
	if (ecuVT)
		CANNetworkManager::CANNetwork.deactivate_control_function(ecuVT);
	ecuVT.reset();
}

extern "C" int32_t agiso_vt_apertar(uint16_t tecla)
{
	return (vt && vt->apertar(tecla)) ? 0 : -1;
}
