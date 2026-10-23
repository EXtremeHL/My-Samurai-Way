class_name Foes
## Duelists of the valley. `sheet` picks the combat sprite sheet.

const HERO := {"name": "Tu", "hp": 110, "atk": 18, "def": 10, "ki": 20}

const ALL := {
	"tetsu": {
		"name": "Tetsu, o Corvo", "sheet": "ronin", "personality": Personality.Id.ORGULHOSO,
		"hp": 160, "atk": 22, "def": 8, "ki": 20,
		"intro": "Vou mostrar-te porque é que ninguém em Kurogane me venceu.",
		"win": "Impossível... um vagabundo com meia espada...",
		"lose": "Volta quando tiveres uma espada inteira. E um homem inteiro a segurá-la.",
	},
	"guarda": {
		"name": "Guarda do Magistrado", "sheet": "guard", "personality": Personality.Id.COBARDE,
		"hp": 140, "atk": 21, "def": 9, "ki": 10,
		"intro": "E-em nome do Magistrado Akamatsu... recua!",
		"win": "Ai... ai... o Magistrado não me paga o suficiente para isto...",
		"lose": "Ha! Ha... pronto, e agora vai-te embora, sim? Por favor.",
	},
}


static func make_hero() -> Fighter:
	return Fighter.make(HERO.name, HERO)


static func make_foe(id: String) -> Fighter:
	var d: Dictionary = ALL[id]
	return Fighter.make(d.name, d, d.personality)
