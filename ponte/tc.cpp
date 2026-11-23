// tc.cpp — um Task Controller mínimo: recebe o DDOP e acompanha os valores
#include "agiso.h"
#include "servicos.hpp"

#include "isobus/isobus/can_network_manager.hpp"
#include "isobus/isobus/isobus_device_descriptor_object_pool.hpp"
#include "isobus/isobus/isobus_task_controller_server.hpp"
#include "isobus/utility/system_timing.hpp"

#include <cstdio>
#include <map>
#include <memory>
#include <mutex>
#include <utility>
#include <vector>

using namespace isobus;
using namespace isobus::task_controller_object;
using Cliente = std::shared_ptr<ControlFunction>;

class CadernoDeCampo : public TaskControllerServer
{
public:
	explicit CadernoDeCampo(std::shared_ptr<InternalControlFunction> ecu) :
	  TaskControllerServer(ecu, 1, 16, 0, TaskControllerOptions().with_documentation().with_implement_section_control()) {}

	// --- 1. Receber o DDOP (pode chegar em partes) ---
	bool store_device_descriptor_object_pool(Cliente de, const std::vector<std::uint8_t> &dados, bool juntar) override
	{
		std::lock_guard<std::mutex> trava(mutex);
		if (!juntar)
			ddop.clear();
		ddop.insert(ddop.end(), dados.begin(), dados.end());
		std::printf("TC  | DDOP recebido de 0x%02X: %zu bytes\n", de->get_address(), dados.size());
		return true;
	}

	// --- 2. Ativar: ler a árvore e anotar o que pedir ---
	bool activate_object_pool(Cliente de, ObjectPoolActivationError &erro, ObjectPoolErrorCodes &erroPool, std::uint16_t &, std::uint16_t &) override
	{
		std::lock_guard<std::mutex> trava(mutex);
		DeviceDescriptorObjectPool arvore;
		if (!arvore.deserialize_binary_object_pool(ddop, de->get_NAME()))
		{
			erro = ObjectPoolActivationError::ThereAreErrorsInTheDDOP;
			return false;
		}
		pedidos.clear();
		for (std::uint16_t i = 0; i < arvore.size(); i++)
		{
			auto objeto = arvore.get_object_by_index(i);
			if (objeto->get_object_type() != ObjectTypes::DeviceElement)
				continue;
			auto det = std::static_pointer_cast<DeviceElementObject>(objeto);
			std::printf("TC  | DET %u %s\n", det->get_element_number(), det->get_designator().c_str());
			for (std::uint16_t c = 0; c < det->get_number_child_objects(); c++)
			{
				auto filho = arvore.get_object_by_id(det->get_child_object_id(c));
				if (filho && (filho->get_object_type() == ObjectTypes::DeviceProcessData))
				{
					auto dpd = std::static_pointer_cast<DeviceProcessDataObject>(filho);
					std::printf("TC  |     DPD  DDI %-3u %s\n", dpd->get_ddi(), dpd->get_designator().c_str());
					pedidos.emplace_back(det->get_element_number(), dpd->get_ddi());
				}
			}
		}
		cliente = de;
		assinar = true; // no próximo ciclo, depois de responder a ativação
		erro = ObjectPoolActivationError::NoErrors;
		erroPool = ObjectPoolErrorCodes::NoErrors;
		return true;
	}

	// --- 3. Chegou um valor do implemento ---
	bool on_value_command(Cliente, std::uint16_t ddi, std::uint16_t elemento, std::int32_t valor, std::uint8_t &erros) override
	{
		std::lock_guard<std::mutex> trava(mutex);
		valores[{ elemento, ddi }] = valor;
		erros = 0;
		return true;
	}

	// --- 4. A cada ciclo: assinar os valores e mostrar um resumo ---
	void ciclo()
	{
		update();
		std::lock_guard<std::mutex> trava(mutex);
		if (assinar && cliente)
		{
			assinar = false;
			for (const auto &p : pedidos)
			{
				send_request_value(cliente, p.second, p.first); // "quanto vale?"
				send_change_threshold_measurement_command(cliente, p.second, p.first, 1); // "avise quando mudar"
			}
			std::printf("TC  | assinei %zu valores\n", pedidos.size());
		}
		if (cliente && SystemTiming::time_expired_ms(ultimoResumo, 2000))
		{
			ultimoResumo = SystemTiming::get_timestamp_ms();
			// DDI 72 = volume (mL), 116 = área (m²), 1 = taxa (mm³/m²)
			std::printf("TC  | tanque %.0f L | área %.2f ha | taxa %.0f L/ha\n",
			            valores[{ 2, 72 }] / 1000.0,
			            valores[{ 1, 116 }] / 10000.0,
			            valores[{ 2, 1 }] / 100.0);
		}
	}

	// --- 5. O TC manda uma ordem ---
	bool definir(std::uint16_t elemento, std::uint16_t ddi, std::int32_t valor)
	{
		std::lock_guard<std::mutex> trava(mutex);
		return cliente && send_set_value(cliente, ddi, elemento, static_cast<std::uint32_t>(valor));
	}

	// --- 6. Respostas mínimas para o resto da norma ---
	bool change_designator(Cliente, std::uint16_t, const std::vector<std::uint8_t> &) override { return true; }
	bool deactivate_object_pool(Cliente) override { return true; }
	bool delete_device_descriptor_object_pool(Cliente, ObjectPoolDeletionErrors &) override { return true; }
	bool get_is_stored_device_descriptor_object_pool_by_structure_label(Cliente, const std::vector<std::uint8_t> &, const std::vector<std::uint8_t> &) override { return false; }
	bool get_is_stored_device_descriptor_object_pool_by_localization_label(Cliente, const std::array<std::uint8_t, 7> &) override { return false; }
	bool get_is_enough_memory_available(std::uint32_t) override { return true; }
	void identify_task_controller(std::uint8_t) override {}
	void on_client_timeout(Cliente) override {}
	void on_process_data_acknowledge(Cliente, std::uint16_t, std::uint16_t, std::uint8_t, ProcessDataCommands) override {}
	void on_client_version_received(Cliente, std::uint8_t) override {}

private:
	std::mutex mutex;
	std::vector<std::uint8_t> ddop;
	std::vector<std::pair<std::uint16_t, std::uint16_t>> pedidos; // (elemento, DDI)
	std::map<std::pair<std::uint16_t, std::uint16_t>, std::int32_t> valores;
	Cliente cliente;
	bool assinar = false;
	std::uint32_t ultimoResumo = 0;
};

namespace
{
	std::shared_ptr<InternalControlFunction> ecuTC;
	std::unique_ptr<CadernoDeCampo> tc;
} // namespace

void tc_iniciar()
{
	NAME nome(0);
	nome.set_arbitrary_address_capable(true);
	nome.set_industry_group(2);
	nome.set_function_code(static_cast<std::uint8_t>(NAME::Function::TaskController));
	nome.set_identity_number(2028);
	nome.set_manufacturer_code(1407);
	ecuTC = CANNetworkManager::CANNetwork.create_internal_control_function(nome, 0, 0xF7);
	tc.reset(new CadernoDeCampo(ecuTC));
	// Sem idioma definido, o TC não responde ao pedido de idioma do
	// implemento, e o implemento espera 6 s a mais antes de continuar.
	tc->get_language_command_interface().set_language_code("pt");
	tc->get_language_command_interface().set_country_code("BR");
	tc->initialize();
}

void tc_ciclo()
{
	if (tc)
		tc->ciclo();
}

void tc_parar()
{
	if (tc)
		tc->terminate();
	tc.reset();
	if (ecuTC)
		CANNetworkManager::CANNetwork.deactivate_control_function(ecuTC);
	ecuTC.reset();
}

extern "C" int32_t agiso_tc_definir(uint16_t elemento, uint16_t ddi, int32_t valor)
{
	return (tc && tc->definir(elemento, ddi, valor)) ? 0 : -1;
}
