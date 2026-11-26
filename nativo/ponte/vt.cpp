// vt.cpp — um Terminal Virtual: recebe a tela do implemento e a transforma em desenho
#include "agiso.h"
#include "servicos.hpp"

#include "isobus/isobus/can_network_manager.hpp"
#include "isobus/isobus/isobus_virtual_terminal_server.hpp"
#include "isobus/utility/system_timing.hpp"

#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

using namespace isobus;
using Implemento = std::shared_ptr<VirtualTerminalServerManagedWorkingSet>;

namespace
{
	constexpr int LARGURA_TELA = 480; // área da máscara de dados, em pixels
	constexpr int LADO_TECLA = 80; // cada soft key é um quadrado

	// O VT usa fontes Latin-1 (Ç = 1 byte); o Dart espera UTF-8
	std::string latin1_para_utf8(const std::string &entrada)
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

	// Uma figura do implemento já convertida para RGBA (4 bytes por pixel)
	struct Figura
	{
		const VTObject *origem = nullptr; // para saber se o pool mudou
		int largura = 0, altura = 0;
		std::vector<std::uint8_t> rgba;
	};
} // namespace

// --- 4. Desenhar: percorre a árvore da máscara ativa e gera uma lista de desenho ---
// Cada objeto vira comandos simples em coordenadas absolutas, com a cor já em RGB:
//   re = retângulo, el = elipse, ln = linha, tx = texto, pi = figura, me = medidor,
//   bt = área de toque (botão ou caixa de seleção)
// O Flutter só precisa desenhar esses comandos, sem conhecer a norma.
class Pintor
{
public:
	explicit Pintor(Implemento ws) :
	  ws(ws) {}

	std::string ops; // JSON: os comandos, separados por vírgula
	std::vector<std::pair<std::uint16_t, std::string>> textos; // para o modo texto do terminal
	std::vector<std::uint16_t> figuras;

	void objeto(std::uint16_t id, int x, int y, int profundidade = 0)
	{
		auto o = ws->get_object_by_id(id);
		if (!o || profundidade > 32) // ponteiros podem formar ciclos
			return;
		const int w = o->get_width(), h = o->get_height();
		switch (o->get_object_type())
		{
			case VirtualTerminalObjectType::DataMask:
			case VirtualTerminalObjectType::AlarmMask:
			case VirtualTerminalObjectType::Key:
			{
				const int lado = o->get_object_type() == VirtualTerminalObjectType::Key ? LADO_TECLA : LARGURA_TELA;
				retangulo(x, y, lado, lado, -1, 0, cor(o->get_background_color()), 0);
				filhos(o, x, y, profundidade);
			}
			break;

			case VirtualTerminalObjectType::Container:
				if (!std::static_pointer_cast<Container>(o)->get_hidden())
					filhos(o, x, y, profundidade);
				break;

			case VirtualTerminalObjectType::ObjectPointer:
				objeto(std::static_pointer_cast<ObjectPointer>(o)->get_value(), x, y, profundidade + 1);
				break;

			case VirtualTerminalObjectType::Button:
			{
				auto b = std::static_pointer_cast<Button>(o);
				if (!b->get_option(Button::Options::TransparentBackground))
					retangulo(x, y, w, h, -1, 0, cor(b->get_background_color()), 0);
				if (!b->get_option(Button::Options::NoBorder) && !b->get_option(Button::Options::SuppressBorder))
					retangulo(x, y, w, h, cor(b->get_border_colour()), 2, -1, 0);
				filhos(o, x, y, profundidade);
				if (!b->get_option(Button::Options::Disabled))
					toque(x, y, w, h, id);
			}
			break;

			case VirtualTerminalObjectType::OutputString:
			case VirtualTerminalObjectType::InputString:
			{
				auto s = std::static_pointer_cast<StringVTObject>(o);
				auto var = std::dynamic_pointer_cast<StringVariable>(ws->get_object_by_id(s->get_variable_reference()));
				const std::string valor = latin1_para_utf8(var ? var->get_value() : s->get_value());
				texto(s, x, y, valor, s->get_option(StringVTObject::Options::Transparent), s->get_option(StringVTObject::Options::AutoWrap));
			}
			break;

			case VirtualTerminalObjectType::OutputNumber:
			case VirtualTerminalObjectType::InputNumber:
			{
				auto n = std::static_pointer_cast<NumberVTObject>(o);
				texto(n, x, y, numero(n), n->get_option(NumberVTObject::Options::Transparent), false);
			}
			break;

			case VirtualTerminalObjectType::OutputList:
			case VirtualTerminalObjectType::InputList:
			{
				// a lista mostra só o item escolhido pelo valor
				auto l = std::static_pointer_cast<ListVTObject>(o);
				auto var = std::dynamic_pointer_cast<NumberVariable>(ws->get_object_by_id(l->get_variable_reference()));
				const std::uint32_t item = var ? var->get_value() : l->get_value();
				if (item < o->get_number_children())
					objeto(o->get_child_id(static_cast<std::uint16_t>(item)), x, y, profundidade + 1);
			}
			break;

			case VirtualTerminalObjectType::InputBoolean:
			{
				auto b = std::static_pointer_cast<InputBoolean>(o);
				auto var = std::dynamic_pointer_cast<NumberVariable>(ws->get_object_by_id(b->get_variable_reference()));
				const bool marcado = 0 != (var ? var->get_value() : b->get_value());
				auto fonte = std::dynamic_pointer_cast<FontAttributes>(ws->get_object_by_id(b->get_foreground_colour_object_id()));
				const int frente = cor(fonte ? fonte->get_colour() : 0);
				retangulo(x, y, w, w, frente, 1, cor(b->get_background_color()), 0);
				if (marcado)
				{
					linha(x + w / 5, y + w / 2, w * 3 / 10, w * 3 / 10, frente, 2, 0);
					linha(x + w / 2, y + w / 5, w * 3 / 10, w * 6 / 10, frente, 2, 1);
				}
				if (b->get_enabled())
					toque(x, y, w, w, id);
			}
			break;

			case VirtualTerminalObjectType::OutputRectangle:
			{
				auto r = std::static_pointer_cast<OutputRectangle>(o);
				int corLinha, espessura;
				atributos_linha(r->get_line_attributes(), corLinha, espessura);
				retangulo(x, y, w, h, corLinha, espessura, preenchimento(r->get_fill_attributes(), corLinha), r->get_line_suppression_bitfield());
			}
			break;

			case VirtualTerminalObjectType::OutputEllipse:
			{
				auto e = std::static_pointer_cast<OutputEllipse>(o);
				int corLinha, espessura;
				atributos_linha(e->get_line_attributes(), corLinha, espessura);
				abre("el", x, y, w, h);
				num("l", corLinha), num("lw", espessura), num("f", preenchimento(e->get_fill_attributes(), corLinha));
				num("ty", static_cast<int>(e->get_ellipse_type())), num("a0", e->get_start_angle() * 2), num("a1", e->get_end_angle() * 2);
				ops += '}';
			}
			break;

			case VirtualTerminalObjectType::OutputLine:
			{
				auto l = std::static_pointer_cast<OutputLine>(o);
				int corLinha, espessura;
				atributos_linha(l->get_line_attributes(), corLinha, espessura);
				linha(x, y, w, h, corLinha, espessura, static_cast<int>(l->get_line_direction()));
			}
			break;

			case VirtualTerminalObjectType::OutputMeter:
			{
				auto m = std::static_pointer_cast<OutputMeter>(o);
				auto var = std::dynamic_pointer_cast<NumberVariable>(ws->get_object_by_id(m->get_variable_reference()));
				int opcoes = 0;
				for (int bit = 0; bit < 4; bit++)
					opcoes |= m->get_option(static_cast<OutputMeter::Options>(bit)) ? (1 << bit) : 0;
				abre("me", x, y, w, w);
				num("min", m->get_min_value()), num("max", m->get_max_value());
				num("v", var ? var->get_value() : m->get_value());
				num("nc", cor(m->get_needle_colour())), num("ac", cor(m->get_arc_and_tick_colour())), num("bc", cor(m->get_border_colour()));
				num("ti", m->get_number_of_ticks()), num("o", opcoes);
				num("a0", m->get_start_angle() * 2), num("a1", m->get_end_angle() * 2);
				ops += '}';
			}
			break;

			case VirtualTerminalObjectType::PictureGraphic:
			{
				auto p = std::static_pointer_cast<PictureGraphic>(o);
				if (p->get_actual_width() == 0)
					break;
				// a largura pedida pode ampliar ou reduzir a figura; a altura acompanha
				abre("pi", x, y, w, p->get_actual_height() * w / p->get_actual_width());
				num("id", id);
				ops += '}';
				figuras.push_back(id);
			}
			break;

			default:
				break; // ponytail: gráficos de barra, polígonos e janelas ainda não são desenhados
		}
	}

private:
	Implemento ws;

	void filhos(std::shared_ptr<VTObject> o, int x, int y, int profundidade)
	{
		for (std::uint16_t i = 0; i < o->get_number_children(); i++)
			objeto(o->get_child_id(i), x + o->get_child_x(i), y + o->get_child_y(i), profundidade + 1);
	}

	// O implemento escolhe cores por índice (0 a 255); a paleta dele diz o RGB
	int cor(std::uint8_t indice)
	{
		auto c = ws->get_colour(indice);
		auto canal = [](float v) { return static_cast<int>(std::lround(v * 255)); };
		return (canal(c.r) << 16) | (canal(c.g) << 8) | canal(c.b);
	}

	void atributos_linha(std::uint16_t id, int &corLinha, int &espessura)
	{
		auto a = std::dynamic_pointer_cast<LineAttributes>(ws->get_object_by_id(id));
		corLinha = a ? cor(a->get_background_color()) : -1;
		espessura = a ? a->get_width() : 0;
	}

	int preenchimento(std::uint16_t id, int corLinha)
	{
		auto f = std::dynamic_pointer_cast<FillAttributes>(ws->get_object_by_id(id));
		if (!f || f->get_type() == FillAttributes::FillType::NoFill)
			return -1;
		if (f->get_type() == FillAttributes::FillType::FillWithLineColor)
			return corLinha;
		return cor(f->get_background_color()); // ponytail: padrão de preenchimento vira cor sólida
	}

	// valor na tela = (variável + offset) x escala
	std::string numero(std::shared_ptr<NumberVTObject> n)
	{
		auto var = std::dynamic_pointer_cast<NumberVariable>(ws->get_object_by_id(n->get_variable_reference()));
		const std::int64_t bruto = var ? var->get_value() : n->get_value();
		double valor = static_cast<double>(bruto + n->get_offset()) * n->get_scale();
		const int decimais = n->get_number_of_decimals();
		if (n->get_option(NumberVTObject::Options::Truncate))
			valor = std::trunc(valor * std::pow(10, decimais)) / std::pow(10, decimais);
		if (valor == 0 && n->get_option(NumberVTObject::Options::DisplayZeroAsBlank))
			return "";
		char buf[48];
		std::snprintf(buf, sizeof(buf), n->get_format() ? "%.*e" : "%.*f", decimais, valor);
		// o GTK liga o locale do sistema (pt_BR = vírgula); o VT usa sempre ponto
		for (char *c = buf; *c; c++)
			if (*c == ',')
				*c = '.';
		return buf;
	}

	void texto(std::shared_ptr<TextualVTObject> t, int x, int y, const std::string &valor, bool transparente, bool quebra)
	{
		auto fonte = std::dynamic_pointer_cast<FontAttributes>(ws->get_object_by_id(t->get_font_attributes()));
		abre("tx", x, y, t->get_width(), t->get_height());
		str("s", valor);
		num("c", cor(fonte ? fonte->get_colour() : 0));
		num("fw", fonte ? fonte->get_font_width_pixels() : 8), num("fh", fonte ? fonte->get_font_height_pixels() : 8);
		num("st", fonte ? fonte->get_style() : 0);
		num("bg", transparente ? -1 : cor(t->get_background_color()));
		num("hj", static_cast<int>(t->get_horizontal_justification())), num("vj", static_cast<int>(t->get_vertical_justification()));
		num("wr", quebra);
		ops += '}';
		textos.emplace_back(t->get_id(), valor);
	}

	void retangulo(int x, int y, int w, int h, int corLinha, int espessura, int corFundo, int supressao)
	{
		abre("re", x, y, w, h);
		num("l", corLinha), num("lw", espessura), num("f", corFundo), num("ls", supressao);
		ops += '}';
	}

	void linha(int x, int y, int w, int h, int corLinha, int espessura, int direcao)
	{
		abre("ln", x, y, w, h);
		num("c", corLinha), num("lw", espessura), num("d", direcao);
		ops += '}';
	}

	void toque(int x, int y, int w, int h, std::uint16_t id)
	{
		abre("bt", x, y, w, h);
		num("id", id);
		ops += '}';
	}

	// --- o JSON, montado à mão: só números e textos ---
	void abre(const char *tipo, int x, int y, int w, int h)
	{
		if (!ops.empty())
			ops += ',';
		ops += "{\"t\":\"";
		ops += tipo;
		ops += '"';
		num("x", x), num("y", y), num("w", w), num("h", h);
	}
	void num(const char *chave, std::int64_t valor)
	{
		ops += ",\"";
		ops += chave;
		ops += "\":" + std::to_string(valor);
	}
	void str(const char *chave, const std::string &valor)
	{
		ops += ",\"";
		ops += chave;
		ops += "\":\"";
		for (unsigned char c : valor)
		{
			if (c == '"' || c == '\\')
				ops += '\\', ops += static_cast<char>(c);
			else if (c < 0x20)
			{
				char buf[8];
				std::snprintf(buf, sizeof(buf), "\\u%04x", c);
				ops += buf;
			}
			else
				ops += static_cast<char>(c);
		}
		ops += '"';
	}
};

class TelaDaCabine : public VirtualTerminalServer
{
public:
	explicit TelaDaCabine(std::shared_ptr<InternalControlFunction> ecu) :
	  VirtualTerminalServer(ecu) {}

	void ciclo() // update() é protected: expomos aqui
	{
		// A pilha não atualiza a mensagem de status quando o implemento troca de
		// máscara. O implemento confia nela, então mantemos as duas em dia aqui.
		if (auto ws = get_active_working_set())
		{
			activeWorkingSetDataMaskObjectID = mascara_ativa(ws);
			activeWorkingSetSoftkeyMaskObjectID = mascara_de_teclas(ws);
		}
		update();
	}

	// --- 1. Como é esta tela (perguntas obrigatórias da norma) ---
	bool get_is_enough_memory(std::uint32_t) const override { return true; }
	VTVersion get_version() const override { return VTVersion::Version4; }
	std::uint8_t get_number_of_navigation_soft_keys() const override { return 0; }
	std::uint8_t get_soft_key_descriptor_x_pixel_width() const override { return LADO_TECLA; }
	std::uint8_t get_soft_key_descriptor_y_pixel_height() const override { return LADO_TECLA; }
	std::uint8_t get_number_of_possible_virtual_soft_keys_in_soft_key_mask() const override { return 6; }
	std::uint8_t get_number_of_physical_soft_keys() const override { return 6; }
	std::uint16_t get_data_mask_area_size_x_pixels() const override { return LARGURA_TELA; }
	std::uint16_t get_data_mask_area_size_y_pixels() const override { return LARGURA_TELA; }
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
	}

	// A máscara que o implemento mandou mostrar (muda com "Change Active Mask")
	static std::uint16_t mascara_ativa(Implemento ws)
	{
		auto wsObj = std::dynamic_pointer_cast<WorkingSet>(ws->get_working_set_object());
		return wsObj ? wsObj->get_active_mask() : NULL_OBJECT_ID;
	}

	// A máscara de teclas da máscara ativa (de dados ou de alarme)
	static std::uint16_t mascara_de_teclas(Implemento ws)
	{
		auto m = ws->get_object_by_id(mascara_ativa(ws));
		if (auto d = std::dynamic_pointer_cast<DataMask>(m))
			return d->get_soft_key_mask();
		if (auto a = std::dynamic_pointer_cast<AlarmMask>(m))
			return a->get_soft_key_mask();
		return NULL_OBJECT_ID;
	}

	// --- 4b. A tela inteira em JSON: máscara + cada soft key ---
	std::string desenhar(Implemento ws, std::vector<std::pair<std::uint16_t, std::string>> &textos)
	{
		Pintor mascara(ws);
		mascara.objeto(mascara_ativa(ws), 0, 0);
		std::string teclas;
		std::vector<std::uint16_t> figurasUsadas = mascara.figuras;
		textos = mascara.textos;
		auto skm = ws->get_object_by_id(mascara_de_teclas(ws));
		for (std::uint16_t i = 0; skm && i < skm->get_number_children(); i++)
		{
			std::uint16_t id = skm->get_child_id(i);
			if (auto p = std::dynamic_pointer_cast<ObjectPointer>(ws->get_object_by_id(id)))
				id = p->get_value();
			if (!std::dynamic_pointer_cast<Key>(ws->get_object_by_id(id)))
				continue;
			Pintor tecla(ws);
			tecla.objeto(id, 0, 0);
			teclas += (teclas.empty() ? "" : ",") + std::string("{\"id\":") + std::to_string(id) + ",\"ops\":[" + tecla.ops + "]}";
			figurasUsadas.insert(figurasUsadas.end(), tecla.figuras.begin(), tecla.figuras.end());
			textos.insert(textos.end(), tecla.textos.begin(), tecla.textos.end());
		}
		atualizar_figuras(ws, figurasUsadas);
		return "{\"ws\":" + std::to_string(ws->get_control_function()->get_address()) +
		  ",\"mascara\":" + std::to_string(mascara_ativa(ws)) +
		  ",\"lado\":" + std::to_string(LARGURA_TELA) + ",\"tecla\":" + std::to_string(LADO_TECLA) +
		  ",\"ops\":[" + mascara.ops + "],\"teclas\":[" + teclas + "]}";
	}

	// Converte cada figura nova (índice de cor por pixel) para RGBA, uma vez só
	void atualizar_figuras(Implemento ws, const std::vector<std::uint16_t> &ids)
	{
		std::lock_guard<std::mutex> trava(mutexFiguras);
		for (auto id : ids)
		{
			auto p = std::dynamic_pointer_cast<PictureGraphic>(ws->get_object_by_id(id));
			if (!p || figuras[id].origem == p.get())
				continue;
			Figura &f = figuras[id];
			f.origem = p.get();
			f.largura = p->get_actual_width();
			f.altura = p->get_actual_height();
			const bool transparente = p->get_option(PictureGraphic::Options::Transparent);
			const auto &pixels = p->get_raw_data();
			f.rgba.assign(static_cast<std::size_t>(f.largura) * f.altura * 4, 0);
			for (std::size_t i = 0; i < pixels.size() && i * 4 < f.rgba.size(); i++)
			{
				// Transparente = os 4 bytes em zero. O Flutter lê os pixels como alfa
				// pré-multiplicado: com RGB != 0 e alfa 0, a cor seria SOMADA ao fundo
				// (e taparia, por exemplo, os retângulos de status das seções).
				if (transparente && pixels[i] == p->get_transparency_colour())
					continue;
				auto c = ws->get_colour(pixels[i]);
				f.rgba[i * 4 + 0] = static_cast<std::uint8_t>(std::lround(c.r * 255));
				f.rgba[i * 4 + 1] = static_cast<std::uint8_t>(std::lround(c.g * 255));
				f.rgba[i * 4 + 2] = static_cast<std::uint8_t>(std::lround(c.b * 255));
				f.rgba[i * 4 + 3] = 255;
			}
		}
	}

	// --- 5. O operador tocou em algo: o VT só avisa o implemento ---
	void tocar(Implemento ws, std::uint16_t id)
	{
		auto o = ws->get_object_by_id(id);
		auto dono = ws->get_control_function();
		if (auto key = std::dynamic_pointer_cast<Key>(o))
		{
			send_soft_key_activation_message(KeyActivationCode::ButtonPressedOrLatched, id, mascara_de_teclas(ws), key->get_key_code(), dono);
			send_soft_key_activation_message(KeyActivationCode::ButtonUnlatchedOrReleased, id, mascara_de_teclas(ws), key->get_key_code(), dono);
		}
		else if (auto botao = std::dynamic_pointer_cast<Button>(o))
		{
			send_button_activation_message(KeyActivationCode::ButtonPressedOrLatched, id, mascara_ativa(ws), botao->get_key_code(), dono);
			send_button_activation_message(KeyActivationCode::ButtonUnlatchedOrReleased, id, mascara_ativa(ws), botao->get_key_code(), dono);
		}
		else if (auto caixa = std::dynamic_pointer_cast<InputBoolean>(o))
		{
			// a caixa de seleção muda aqui e o implemento fica sabendo do novo valor
			auto var = std::dynamic_pointer_cast<NumberVariable>(ws->get_object_by_id(caixa->get_variable_reference()));
			const std::uint8_t novo = (var ? var->get_value() : caixa->get_value()) ? 0 : 1;
			if (var)
				var->set_value(novo);
			else
				caixa->set_value(novo);
			// com variável, o implemento acompanha o valor pelo ID dela
			send_change_numeric_value_message(var ? var->get_id() : id, novo, dono);
		}
	}

	// O que o Dart lê: protegido por mutex, porque o Dart roda em outra thread
	std::mutex mutexTela;
	std::string telaJson;
	std::mutex mutexFiguras;
	std::map<std::uint16_t, Figura> figuras;
};

namespace
{
	std::shared_ptr<InternalControlFunction> ecuVT;
	std::unique_ptr<TelaDaCabine> vt;
	std::uint32_t ultimoDesenho = 0;
	std::uint32_t ultimaOlhada = 0;
	std::map<std::uint16_t, std::string> ultimaTela; // o que o modo texto já mostrou
	const VTObject *ultimoPool = nullptr;

	// Toques vindos do Dart: viram fila e são enviados na thread da pilha
	std::mutex mutexToques;
	std::vector<std::uint16_t> toques;
	std::atomic_bool temTela{ false };

	// Modo texto: mostra no terminal só o que mudou
	void mostrar(const std::vector<std::pair<std::uint16_t, std::string>> &textos)
	{
		std::string linha;
		for (const auto &item : textos)
		{
			if (ultimaTela[item.first] != item.second)
				linha += std::to_string(item.first) + "=\"" + item.second + "\"  ";
			ultimaTela[item.first] = item.second;
		}
		if (!linha.empty())
			std::printf("VT  | %s\n", linha.c_str());
	}
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
	auto ws = vt->get_active_working_set();
	temTela = ws && ws->get_working_set_object();
	if (!temTela)
	{
		std::lock_guard<std::mutex> trava(vt->mutexTela);
		vt->telaJson.clear();
		return;
	}
	if (ws->get_working_set_object().get() != ultimoPool) // pool novo: o modo texto mostra tudo de novo
	{
		ultimoPool = ws->get_working_set_object().get();
		ultimaTela.clear();
	}

	std::vector<std::uint16_t> pendentes;
	{
		std::lock_guard<std::mutex> trava(mutexToques);
		pendentes.swap(toques);
	}
	for (auto id : pendentes)
		vt->tocar(ws, id);

	// a cada 100 ms, redesenha (barato: algumas centenas de objetos)
	if (!pendentes.empty() || SystemTiming::time_expired_ms(ultimoDesenho, 100))
	{
		ultimoDesenho = SystemTiming::get_timestamp_ms();
		std::vector<std::pair<std::uint16_t, std::string>> textos;
		std::string json = vt->desenhar(ws, textos);
		{
			std::lock_guard<std::mutex> trava(vt->mutexTela);
			vt->telaJson.swap(json);
		}
		// a cada 2 s, o modo texto mostra o que mudou
		if (SystemTiming::time_expired_ms(ultimaOlhada, 2000))
		{
			ultimaOlhada = SystemTiming::get_timestamp_ms();
			mostrar(textos);
		}
	}
}

void vt_parar()
{
	temTela = false;
	vt.reset();
	if (ecuVT)
		CANNetworkManager::CANNetwork.deactivate_control_function(ecuVT);
	ecuVT.reset();
	ultimaTela.clear();
	ultimoPool = nullptr;
}

extern "C" int32_t agiso_vt_apertar(uint16_t tecla)
{
	if (!vt || !temTela)
		return -1;
	std::lock_guard<std::mutex> trava(mutexToques);
	toques.push_back(tecla);
	return 0;
}

// [passo 10]
extern "C" int32_t agiso_vt_tela(char *destino, int32_t tamanho)
{
	if (!vt)
		return -1;
	std::lock_guard<std::mutex> trava(vt->mutexTela);
	if (vt->telaJson.empty())
		return -1;
	const auto n = static_cast<int32_t>(vt->telaJson.size());
	if (destino && n <= tamanho)
		std::memcpy(destino, vt->telaJson.data(), static_cast<std::size_t>(n));
	return n; // maior que o tamanho? o Dart aumenta o buffer e pede de novo
}

extern "C" int32_t agiso_vt_figura(uint16_t id, uint8_t *rgba, int32_t tamanho, int32_t *largura, int32_t *altura)
{
	if (!vt)
		return -1;
	std::lock_guard<std::mutex> trava(vt->mutexFiguras);
	auto it = vt->figuras.find(id);
	if (it == vt->figuras.end() || it->second.rgba.empty())
		return -1;
	const auto &f = it->second;
	*largura = f.largura;
	*altura = f.altura;
	const auto n = static_cast<int32_t>(f.rgba.size());
	if (rgba && n <= tamanho)
		std::memcpy(rgba, f.rgba.data(), static_cast<std::size_t>(n));
	return n;
}
// [/passo 10]
