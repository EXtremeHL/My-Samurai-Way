class_name Bocas
## The hero's repertoire of bocas (taunts), by category.

enum Cat { INSULTO, AMEACA, TROCA, LISONJA, TENTACAO }

const ORDER := [Cat.INSULTO, Cat.AMEACA, Cat.TROCA, Cat.LISONJA, Cat.TENTACAO]

const NAMES := {
	Cat.INSULTO: "Insulto",
	Cat.AMEACA: "Ameaça",
	Cat.TROCA: "Troça",
	Cat.LISONJA: "Lisonja",
	Cat.TENTACAO: "Tentação",
}

const HINTS := {
	Cat.INSULTO: "Ataca a honra e a família.",
	Cat.AMEACA: "Promete-lhe uma morte feia.",
	Cat.TROCA: "Goza com a técnica dele.",
	Cat.LISONJA: "Elogios com veneno.",
	Cat.TENTACAO: "Moedas, saké, uma saída fácil.",
}

const LINES := {
	Cat.INSULTO: [
		"A tua família deve ter vergonha de ti. Eu teria.",
		"Samurai? Já vi espantalhos com mais honra.",
		"Lutas como quem nunca teve mestre. Ou o mestre fugiu.",
	],
	Cat.AMEACA: [
		"Esta lâmina está partida. A tua cabeça vai fazer-lhe companhia.",
		"Já enterrei homens maiores do que tu. E mais rápidos.",
		"Reza agora. Depois não vais ter tempo.",
	],
	Cat.TROCA: [
		"Seguras essa espada como quem segura uma vassoura.",
		"Essa guarda tem mais buracos do que o telhado da estalagem.",
		"Foi o teu avô que te ensinou isso? Devia ter-te ensinado outra coisa.",
	],
	Cat.LISONJA: [
		"Que bela postura. Quase pareces perigoso.",
		"Um guerreiro como tu merecia um adversário melhor... pena ser eu.",
		"Dizem que és o melhor espadachim do vale. Mostra-me porquê.",
	],
	Cat.TENTACAO: [
		"Tenho moedas. Quanto vale para ti esquecer que me viste?",
		"Quem te paga, paga-te mal. Eu pagaria melhor.",
		"Há saké na casa de chá. Podíamos estar lá em vez de aqui.",
	],
}

## Each earlier use of the same category on the same foe: "já ouvi essa".
const REPEAT_PENALTY := 0.12
