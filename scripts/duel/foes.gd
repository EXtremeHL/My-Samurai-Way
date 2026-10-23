class_name Foes
## Duelists of the valley. `sheet` picks the combat sprite sheet.
## Outcome tags (GameState.apply) run after the duel:
##   on_win (beaten) -> then the player chooses on_spare / on_kill
##   on_surrender     -> he gave up; treated as beaten and spared
##   on_lose          -> the hero fell

const HERO := {"name": "Tu", "hp": 110, "atk": 18, "def": 10, "ki": 20}

const ALL := {
	"tetsu": {
		"name": "Tetsu, o Corvo", "sheet": "ronin", "personality": Personality.Id.ORGULHOSO,
		"hp": 160, "atk": 22, "def": 8, "ki": 20,
		"intro": "Vou mostrar-te porque é que ninguém em Kurogane me venceu.",
		"win": "Impossível... um vagabundo com meia espada...",
		"lose": "Volta quando tiveres uma espada inteira. E um homem inteiro a segurá-la.",
		"on_win": "flag:venceu_tetsu;rep:corvo:-10;rep:vila:+5",
		"on_spare": "rep:corvo:+5",
		"on_kill": "flag:dead_tetsu;rep:corvo:-30;rep:vila:+5",
		"on_lose": "rep:corvo:+5;rep:vila:-5",
	},
	"guarda": {
		"name": "Guarda do Magistrado", "sheet": "guard", "personality": Personality.Id.COBARDE,
		"hp": 140, "atk": 21, "def": 9, "ki": 10,
		"intro": "E-em nome do Magistrado Akamatsu... recua!",
		"win": "Ai... ai... o Magistrado não me paga o suficiente para isto...",
		"lose": "Ha! Ha... pronto, e agora vai-te embora, sim? Por favor.",
		"on_win": "flag:venceu_guarda;rep:magistrado:-15;rep:vila:+10",
		"on_spare": "",
		"on_kill": "flag:dead_guarda;rep:magistrado:-25;rep:vila:-10",
		"on_lose": "rep:magistrado:+5",
	},
	"bandido": {
		"name": "Bandido do Corvo", "sheet": "bandit", "personality": Personality.Id.COLERICO,
		"hp": 160, "atk": 24, "def": 8, "ki": 10,
		"intro": "Queres armar-te em herói? Vou-te ensinar o preço dos heróis!",
		"win": "Argh! O... o chefe vai saber disto!",
		"lose": "Ha! E agora, menina? Já não tens herói nenhum.",
		"on_win": "flag:salvou_oyuki;flag:bandido_resolvido;rep:vila:+25;rep:corvo:-15",
		"on_spare": "",
		"on_kill": "flag:dead_bandido;rep:corvo:-10;rep:vila:-5",
		"on_lose": "rep:vila:-5",
	},
	"kuroda": {
		"name": "Kuroda Jinbei", "sheet": "kuroda", "personality": Personality.Id.ESTOICO,
		"hp": 170, "atk": 22, "def": 10, "ki": 40,
		"intro": "Respira fundo. Será das últimas vezes.",
		"win": "...Bem cortado. O vale é teu, vagabundo. Vê se o mereces.",
		"lose": "",
		"on_win": "flag:venceu_kuroda;rep:corvo:-40;rep:vila:+15",
		"on_spare": "",
		"on_kill": "flag:dead_kuroda;rep:vila:+5",
		"on_lose": "end:caido",
	},
	"akamatsu": {
		"name": "Magistrado Akamatsu", "sheet": "akamatsu", "personality": Personality.Id.GANANCIOSO,
		"hp": 150, "atk": 21, "def": 10, "ki": 30,
		"intro": "Sabes quanto custa matar um magistrado? Eu sei. Já fiz as contas.",
		"win": "Não... não me mates! Tenho ryō! Muitos ryō!",
		"lose": "Prendam-no. Não: deixem-no aí. Que a vila veja quem manda.",
		"on_win": "flag:venceu_akamatsu;rep:magistrado:-40;rep:vila:+20",
		"on_spare": "rep:vila:-5",
		"on_kill": "flag:dead_akamatsu;rep:vila:+10",
		"on_lose": "rep:magistrado:+10;rep:vila:-10",
	},
}


static func make_hero() -> Fighter:
	return Fighter.make(HERO.name, HERO)


static func make_foe(id: String) -> Fighter:
	var d: Dictionary = ALL[id]
	return Fighter.make(d.name, d, d.personality)
