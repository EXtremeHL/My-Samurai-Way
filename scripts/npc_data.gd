class_name NpcData
## Who lives in Kurogane-juku and what they say.
##
## The valley: Kurogane ("aço negro") is famous for the black-steel blades of
## the Hayashi forge. Three powers want it:
##   - Magistrado Akamatsu and his guards (the law, bought and paid for)
##   - Bando do Corvo, ronin led by Kuroda Jinbei (the sword for hire)
##   - the townsfolk and old Genzō of the forge (who just want to live)
## You arrive with a broken katana. Lines are [speaker, text]; "" = narrator.

const TOWN := {
	"oyuki": {
		"name": "Oyuki", "sheet": "girl", "pos": Vector3(-7.3, 0, -1.9),
		"first": [
			["Oyuki", "Bem-vindo à casa de chá Yamabuki! Senta-te, viajante. O chá é quente e as notícias são de graça."],
			["Oyuki", "Estás em Kurogane-juku. Dizem que o aço daqui corta pedra... mas hoje em dia corta mais gente do que pedra."],
			["Oyuki", "Os guardas do Magistrado Akamatsu cobram portagem na ponte. Os homens do Corvo cobram o resto."],
			["Tu", "E quem protege a vila?"],
			["Oyuki", "...Ninguém. Por isso é que olhaste para mim assim? Guarda essa espada, ronin. Ainda."],
		],
		"again": [
			["Oyuki", "O velho Genzō está ali ao lado. Se alguém consegue consertar essa lâmina partida, é ele."],
		],
	},
	"genzo": {
		"name": "Genzō", "sheet": "elder", "pos": Vector3(-9.4, 0, -1.7),
		"first": [
			["Genzō", "Hm. Essa bainha está leve demais para a lâmina que devia levar."],
			["Tu", "Partiu-se. Num duelo que eu perdi."],
			["Genzō", "Uma lâmina partida e um homem vivo. Já vi negócios piores."],
			["Genzō", "Fui o último mestre da forja Hayashi. O Corvo quer o meu aço, o Magistrado quer o meu imposto e o meu neto quer que eu me cale."],
			["Genzō", "Traz-me aço negro do velho poço da mina e talvez eu volte a acender o forno. Talvez."],
		],
		"again": [
			["Genzō", "O poço da mina fica a norte, depois do santuário. Os guardas fecharam o caminho... por razões que só o Magistrado entende."],
		],
	},
	"tetsu": {
		"name": "Ronin de chapéu de palha", "sheet": "ronin", "pos": Vector3(-4.9, 0, -1.4),
		"facing": "side",
		"first": [
			["Ronin de chapéu de palha", "..."],
			["Ronin de chapéu de palha", "Mais um ronin com fome. O vale está cheio deles."],
			["Ronin de chapéu de palha", "O chefe Kuroda paga bem a quem sabe segurar uma espada. Mesmo partida."],
			["Ronin de chapéu de palha", "Eu? Eu sou o Tetsu. Ninguém em Kurogane me venceu. Ninguém. Pergunta a quem quiseres."],
			["Tu", "E se eu não quiser trabalhar para o Corvo?"],
			["Ronin de chapéu de palha", "Então reza para não te cruzares comigo depois do pôr do sol."],
		],
		"again": [
			["Ronin de chapéu de palha", "Ainda aqui? Pensa na proposta. O Corvo não pergunta duas vezes."],
			["Ronin de chapéu de palha", "Ou queres mostrar-me o que vale essa meia espada?"],
			{"choice": ["Desembainhar a espada", "Ir embora"], "tags": ["duel:tetsu", ""]},
		],
		"beaten": [
			["Tetsu", "...Ganhaste. Desta vez."],
			["Tetsu", "O chefe Kuroda vai querer conhecer o vagabundo que me pôs de joelhos. Prepara-te."],
		],
		"duel_spot": Vector3(-4.6, 0, 0.35),
	},
	"heita": {
		"name": "Heita", "sheet": "villager", "pos": Vector3(4.2, 0, 0.2),
		"facing": "side", "flip": true,
		"first": [
			["Heita", "Ai, as minhas costas! Carrego carvão para a forja há vinte anos e agora nem há forja."],
			["Heita", "Para atravessar a ponte vermelha, os guardas querem três moedas. Três! Por uma ponte que o meu avô construiu!"],
			["Heita", "Se fosses um samurai a sério, ias lá e... não, esquece. Não quero sarilhos."],
		],
		"again": [
			["Heita", "Do outro lado do rio fica o acampamento do Corvo. Ninguém decente vai para lá."],
		],
	},
	"guarda": {
		"name": "Guarda do Magistrado", "sheet": "guard", "pos": Vector3(-3.0, 0, -11.4),
		"first": [
			["Guarda do Magistrado", "Alto! O caminho do santuário está fechado por ordem do Magistrado Akamatsu."],
			["Tu", "Porquê?"],
			["Guarda do Magistrado", "Porque o Magistrado assim o quer. Precisas de mais razões, vagabundo?"],
			["", "A mão dele treme no cabo da espada. Os olhos não param de procurar os outros guardas."],
		],
		"again": [
			["Guarda do Magistrado", "Ainda aqui? D-desaparece, antes que eu te prenda por vadiagem."],
			{"choice": ["Forçar a passagem", "Recuar"], "tags": ["duel:guarda", ""]},
		],
		"beaten": [
			["Guarda do Magistrado", "Eu não vi nada! Passa, passa... mas o Magistrado vai saber disto."],
		],
		"duel_spot": Vector3(-3.0, 0, -10.1),
		"beaten_pos": Vector3(-4.5, 0, -11.2),
	},
}

const PLAYER_START := Vector3(0.6, 0, 0.7)
const WAKE_POS := Vector3(-7.3, 0, -0.7)

const WAKE_LINES := [
	["", "..."],
	["Oyuki", "Ah, acordaste! Encontrei-te estendido no meio da rua."],
	["Oyuki", "Quem quer que tenha sido, não te quis matar. Ainda. Bebe este chá e não faças mais disparates... hoje."],
]
