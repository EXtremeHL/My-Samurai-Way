class_name Endings
## How the story of the valley can end. Decided purely from GameState.

## Tests and screenshot runs point this elsewhere so they never touch the
## player's real list of discovered endings.
static var save_path := "user://finais.cfg"

const ALL := {
	"protetor": {
		"title": "O Protetor de Kurogane",
		"text": [
			"Com o Corvo disperso e o Magistrado de joelhos, a vila acordou sem dono pela primeira vez em vinte anos.",
			"Oyuki serviu chá de graça durante três dias. O Heita jura que a ponte nunca esteve tão bonita.",
			"Ofereceram-te uma casa. Recusaste. Mas sempre que um viajante pergunta pelo vale, contam-lhe a história do ronin que ficou só o tempo suficiente.",
		],
	},
	"corvo": {
		"title": "O Corvo Voa Alto",
		"text": [
			"O Magistrado caiu e as asas negras do Corvo cobriram o vale.",
			"Kuroda deu-te o lugar à direita dele. As portagens continuaram... só mudou quem as cobrava.",
			"Às vezes, à noite, perguntas-te se a vila te olha como olhava para o Akamatsu. Depois bebes, e deixas de perguntar.",
		],
	},
	"lei": {
		"title": "A Espada do Magistrado",
		"text": [
			"Kuroda Jinbei caiu, e com ele o Bando do Corvo. O Magistrado Akamatsu cumpriu a palavra: cinquenta ryō e um lugar à mesa.",
			"A portagem da ponte subiu outra vez no mês seguinte. Agora és tu que estás ao lado dos guardas quando a cobram.",
			"A lei venceu em Kurogane. Ninguém soube dizer se isso era uma boa notícia.",
		],
	},
	"lamina": {
		"title": "A Lâmina Renascida",
		"text": [
			"Saíste do vale com uma lâmina de aço negro à cintura e o som do martelo do Genzō ainda nos ouvidos.",
			"Kurogane continuou com os seus problemas. Mas a forja voltou a acender-se, e a vila voltou a ter algo de que se orgulhar.",
			"Dizem que, desde então, nenhum duelo te correu mal. Dizem muita coisa.",
		],
	},
	"desertor": {
		"title": "O Desertor",
		"text": [
			"Juraste lealdade, aceitaste o trabalho... e foste-te embora pela estrada de leste antes de o cumprir.",
			"Durante muito tempo, em Kurogane, o teu nome serviu para insultar os cães que fugiam com a cauda entre as pernas.",
		],
	},
	"vagabundo": {
		"title": "Só de Passagem",
		"text": [
			"Atravessaste Kurogane como o vento atravessa um arrozal: tudo se mexeu um bocadinho, e nada mudou.",
			"A estrada de leste é longa. Há outros vales, outras pontes, outras portagens.",
		],
	},
	"odiado": {
		"title": "O Ronin Maldito",
		"text": [
			"Quando partiste, a vila inteira fechou as portas. Ninguém te desejou boa viagem.",
			"As mães de Kurogane ainda hoje assustam os filhos com o teu nome.",
		],
	},
	"chamas": {
		"title": "Kurogane em Chamas",
		"text": [
			"Ao terceiro dia, o Corvo e o Magistrado deixaram de fingir. A guerra rebentou na rua principal.",
			"A casa de chá ardeu primeiro. Depois a estalagem. Tu escolheste um lado, mas não o suficiente para acabar com aquilo.",
			"De manhã, só restava o fumo... e a ponte vermelha, intacta, a ligar coisa nenhuma a coisa nenhuma.",
		],
	},
	"mais_um_dia": {
		"title": "Mais Um Dia em Kurogane",
		"text": [
			"O terceiro dia terminou como os outros: a portagem cobrada, o Corvo à espreita, o forno do Genzō frio.",
			"Partiste de madrugada. Ninguém reparou.",
		],
	},
	"caido": {
		"title": "O Último Corte",
		"text": [
			"A lâmina de Kuroda foi mais rápida do que a tua respiração.",
			"Caíste na estrada de leste, de olhos abertos para o céu de Kurogane. Os corvos, os de verdade, chegaram antes do pôr do sol.",
		],
	},
}


static func down(s: GameState, who: String) -> bool:
	return s.has("venceu_" + who) or s.has("dead_" + who)


## Endings that close the story the moment they become true (after duels).
static func on_event(s: GameState) -> String:
	if down(s, "kuroda") and down(s, "akamatsu") and s.rep.vila >= 30:
		return "protetor"
	if s.has("corvo_membro") and down(s, "akamatsu") and not down(s, "kuroda"):
		return "corvo"
	if s.has("trabalho_magistrado") and not s.has("corvo_membro") and down(s, "kuroda") and not down(s, "akamatsu"):
		return "lei"
	return ""


## reason: "leave" (walked out east) or "time" (the third night ended).
static func evaluate(s: GameState, reason: String) -> String:
	var e := on_event(s)
	if e != "":
		return e
	if s.rep.vila <= -40:
		return "odiado"
	if reason == "leave":
		if s.has("espada_forjada"):
			return "lamina"
		if s.has("corvo_membro") or s.has("trabalho_magistrado"):
			return "desertor"
		return "vagabundo"
	if s.has("espada_forjada") and s.rep.vila >= 20:
		return "lamina"
	if s.has("corvo_membro") or s.has("trabalho_magistrado") or s.has("humilhou_oyuki"):
		return "chamas"
	return "mais_um_dia"


# ---------------------------------------------------------------------------
# discovered endings, kept between runs
# ---------------------------------------------------------------------------
static func discovered() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return []
	return cfg.get_value("finais", "vistos", [])


static func record(id: String) -> Array:
	var seen := discovered()
	if not seen.has(id):
		seen.append(id)
	var cfg := ConfigFile.new()
	cfg.set_value("finais", "vistos", seen)
	cfg.save(save_path)
	return seen
