class_name Personality
## Hidden temperament of a duelist. It decides how every kind of boca lands,
## and how the fighter behaves in a duel.

enum Id { ORGULHOSO, COLERICO, COBARDE, ESTOICO, GANANCIOSO }

## Emotional states a boca can provoke (one at a time per fighter).
enum Mood { NONE, ENFURECIDO, ABALADO, INTIMIDADO, DESCONCENTRADO, MOTIVADO, FOCADO }

const NAMES := {
	Id.ORGULHOSO: "Orgulhoso",
	Id.COLERICO: "Colérico",
	Id.COBARDE: "Cobarde",
	Id.ESTOICO: "Estoico",
	Id.GANANCIOSO: "Ganancioso",
}

const BLURBS := {
	Id.ORGULHOSO: "Vive para a reputação. Insultos põem-no fora de si; ameaças só o espicaçam.",
	Id.COLERICO: "Pavio curtíssimo. Quase tudo o enfurece, para o bem e para o mal.",
	Id.COBARDE: "Luta por obrigação. Ameaças fazem-no tremer, mas elogios dão-lhe coragem.",
	Id.ESTOICO: "Mente de água parada. Cada palavra desperdiçada torna-o mais atento.",
	Id.GANANCIOSO: "Luta por dinheiro. Fala-lhe de moedas e esquece-se da espada.",
}

const MOOD_NAMES := {
	Mood.NONE: "",
	Mood.ENFURECIDO: "Enfurecido",
	Mood.ABALADO: "Abalado",
	Mood.INTIMIDADO: "Intimidado",
	Mood.DESCONCENTRADO: "Desconcentrado",
	Mood.MOTIVADO: "Motivado",
	Mood.FOCADO: "Focado",
}

## Short effect summary shown in the boca menu once the personality is known.
const MOOD_SUMMARY := {
	Mood.NONE: "Sem efeito",
	Mood.ENFURECIDO: "Enfurece-o: ↑ataque, larga a guarda e deixa de fintar",
	Mood.ABALADO: "Abala-o: ↓ataque ↓pontaria, deixa de fintar",
	Mood.INTIMIDADO: "Intimida-o: ↓ataque ↓defesa, pode render-se",
	Mood.DESCONCENTRADO: "Distrai-o: perde a ação e baixa a guarda",
	Mood.MOTIVADO: "Motiva-o: ↑ataque ↑defesa (cuidado!)",
	Mood.FOCADO: "Concentra-o: ↑pontaria, ganha ki e finta mais (cuidado!)",
}

## Moods good for the speaker (green in the UI) vs. backfires (red).
const GOOD_FOR_SPEAKER := [Mood.ABALADO, Mood.INTIMIDADO, Mood.DESCONCENTRADO]
const RISKY := [Mood.ENFURECIDO]

## Stat multipliers per mood: [atk, def, accuracy delta]
const MOOD_STATS := {
	Mood.NONE: [1.0, 1.0, 0.0],
	Mood.ENFURECIDO: [1.3, 0.6, -0.15],
	Mood.ABALADO: [0.75, 1.0, -0.25],
	Mood.INTIMIDADO: [0.7, 0.8, 0.0],
	Mood.DESCONCENTRADO: [1.0, 0.7, 0.0],
	Mood.MOTIVADO: [1.3, 1.2, 0.05],
	Mood.FOCADO: [1.0, 1.0, 0.2],
}

const MOOD_TURNS := {
	Mood.ENFURECIDO: 3, Mood.ABALADO: 3, Mood.INTIMIDADO: 3,
	Mood.DESCONCENTRADO: 2, Mood.MOTIVADO: 3, Mood.FOCADO: 3,
}

## personality -> boca category -> [mood if it lands, chance]
## A miss means "no effect".
const REACTIONS := {
	Id.ORGULHOSO: {
		Bocas.Cat.INSULTO: [Mood.ENFURECIDO, 0.8],
		Bocas.Cat.TROCA: [Mood.ABALADO, 0.65],
		Bocas.Cat.AMEACA: [Mood.MOTIVADO, 0.7],
		Bocas.Cat.LISONJA: [Mood.DESCONCENTRADO, 0.6],
		Bocas.Cat.TENTACAO: [Mood.NONE, 1.0],
	},
	Id.COLERICO: {
		Bocas.Cat.INSULTO: [Mood.ENFURECIDO, 0.9],
		Bocas.Cat.TROCA: [Mood.ENFURECIDO, 0.85],
		Bocas.Cat.AMEACA: [Mood.ENFURECIDO, 0.7],
		Bocas.Cat.LISONJA: [Mood.DESCONCENTRADO, 0.35],
		Bocas.Cat.TENTACAO: [Mood.NONE, 1.0],
	},
	Id.COBARDE: {
		Bocas.Cat.INSULTO: [Mood.NONE, 1.0],
		Bocas.Cat.TROCA: [Mood.ABALADO, 0.6],
		Bocas.Cat.AMEACA: [Mood.INTIMIDADO, 0.75],
		Bocas.Cat.LISONJA: [Mood.MOTIVADO, 0.7],
		Bocas.Cat.TENTACAO: [Mood.DESCONCENTRADO, 0.65],
	},
	Id.ESTOICO: {
		Bocas.Cat.INSULTO: [Mood.FOCADO, 0.9],
		Bocas.Cat.TROCA: [Mood.ABALADO, 0.25],
		Bocas.Cat.AMEACA: [Mood.FOCADO, 0.9],
		Bocas.Cat.LISONJA: [Mood.FOCADO, 0.6],
		Bocas.Cat.TENTACAO: [Mood.FOCADO, 0.9],
	},
	Id.GANANCIOSO: {
		Bocas.Cat.INSULTO: [Mood.ENFURECIDO, 0.6],
		Bocas.Cat.TROCA: [Mood.NONE, 1.0],
		Bocas.Cat.AMEACA: [Mood.ABALADO, 0.55],
		Bocas.Cat.LISONJA: [Mood.NONE, 1.0],
		Bocas.Cat.TENTACAO: [Mood.DESCONCENTRADO, 0.8],
	},
}

## AI action weights: light, heavy, guard, parry, boca
const AI_WEIGHTS := {
	Id.ORGULHOSO: [0.30, 0.35, 0.10, 0.10, 0.15],
	Id.COLERICO: [0.35, 0.45, 0.05, 0.00, 0.15],
	Id.COBARDE: [0.30, 0.10, 0.35, 0.10, 0.15],
	Id.ESTOICO: [0.30, 0.20, 0.15, 0.30, 0.05],
	Id.GANANCIOSO: [0.40, 0.25, 0.15, 0.10, 0.10],
}

## Stoics hide their intent this often.
const HIDE_INTENT := {Id.ESTOICO: 0.5}

## How often each temperament shows a false intent (a feint).
const FEINT := {
	Id.ORGULHOSO: 0.2, Id.COLERICO: 0.0, Id.COBARDE: 0.15, Id.ESTOICO: 0.25, Id.GANANCIOSO: 0.3,
}

## Moods that make a fighter too rattled or reckless to hide or feint.
const HONEST_MOODS := [Mood.ENFURECIDO, Mood.ABALADO, Mood.INTIMIDADO]

## What they say when a boca hits home (or doesn't). personality -> mood -> lines
const REACTION_LINES := {
	Id.ORGULHOSO: {
		Mood.ENFURECIDO: ["Como OUSAS?! Vou cortar-te essa língua!", "Repete isso, verme. REPETE!"],
		Mood.ABALADO: ["O-o quê? A minha técnica é perfeita!", "...Quem te disse isso? Mentira!"],
		Mood.MOTIVADO: ["Ameaças? A mim? Agora sim, vou levar-te a sério.", "Ha! Finalmente um adversário com fogo!"],
		Mood.DESCONCENTRADO: ["Hm... é verdade, sou magnífico, não sou?", "Continua, continua... gosto de ouvir isso."],
		Mood.NONE: ["Palavras de vagabundo.", "Dinheiro? Ofendes-me ainda mais."],
	},
	Id.COLERICO: {
		Mood.ENFURECIDO: ["RAAAH! Cala-te! CALA-TE!", "Vou-te partir aos bocadinhos!"],
		Mood.DESCONCENTRADO: ["Hã? Eu? ...Obrigado? Espera, não!"],
		Mood.NONE: ["Hã? Fala mais alto!", "Não percebi nada, mas não gostei."],
	},
	Id.COBARDE: {
		Mood.INTIMIDADO: ["E-espera! Eu só cumpro ordens!", "N-não precisas de fazer isso..."],
		Mood.ABALADO: ["N-não tem graça nenhuma...", "A minha mãe dizia o mesmo..."],
		Mood.MOTIVADO: ["Achas mesmo? Então... então eu consigo!", "Sim! Eu sou forte! Eu sou FORTE!"],
		Mood.DESCONCENTRADO: ["Moedas? Quantas moedas?", "Saké...? Não, não, estou de serviço!"],
		Mood.NONE: ["Hm-hm. Palavras não cortam.", "Já me chamaram pior. Hoje, até."],
	},
	Id.ESTOICO: {
		Mood.FOCADO: ["...", "Os teus olhos dizem mais do que a tua boca.", "Respiras demasiado alto quando mentes."],
		Mood.ABALADO: ["...Hm. Talvez tenhas razão.", "Interessante. Ninguém mo tinha dito."],
		Mood.NONE: ["...", "O vento também fala. Não lhe respondo."],
	},
	Id.GANANCIOSO: {
		Mood.DESCONCENTRADO: ["Moedas, dizes tu? ...Quantas?", "Melhor do que o Magistrado? Conta-me mais."],
		Mood.ENFURECIDO: ["Ninguém insulta o meu nome sem pagar!", "Isso vai-te custar caro. Muito caro."],
		Mood.ABALADO: ["Tch. Isto não vale o que me pagam.", "Hm. Talvez devesse ter pedido mais."],
		Mood.NONE: ["Poupa o fôlego.", "Elogios não pagam a renda."],
	},
}

const SURRENDER_LINES := {
	Id.COBARDE: "Pronto! Pronto! Eu desisto! Não me mates!",
	Id.GANANCIOSO: "Chega! Não me pagam o suficiente para morrer.",
}

## Their own bocas, thrown at the hero on a 'boca' turn.
const TAUNTS := {
	Id.ORGULHOSO: ["Ajoelha-te e talvez te deixe viver.", "Uma espada partida para um homem partido."],
	Id.COLERICO: ["Vou-te esmagar como um percevejo!", "Pára quieto para eu te acertar!"],
	Id.COBARDE: ["O-olha que eu chamo os outros guardas!", "Vai-te embora e ninguém se magoa. Principalmente eu."],
	Id.ESTOICO: ["Respiras demasiado alto.", "Já perdeste. Só ainda não sabes."],
	Id.GANANCIOSO: ["A tua cabeça vale dez moedas. Não é pessoal.", "Cada golpe que falho é dinheiro perdido."],
}


static func reaction(p: int, cat: int) -> Array:
	return REACTIONS[p][cat]


static func line_for(p: int, mood: int, rng: RandomNumberGenerator) -> String:
	var table: Dictionary = REACTION_LINES[p]
	var pool: Array = table.get(mood, table.get(Mood.NONE, ["..."]))
	return pool[rng.randi() % pool.size()]
