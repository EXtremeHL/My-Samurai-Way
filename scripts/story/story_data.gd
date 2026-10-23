class_name StoryData
## The valley of Kurogane: who is where, what they say, and how it ends.
##
## CHARS[id]
##   name, sheet ("" = invisible spot, e.g. a door), duel_spot
##   at:      {period: Vector3}       missing period = not around
##   when:    [cond, cond...]         present if ANY holds (omit = always)
##   gone:    [flags]                 absent once any is set
##   moved:   {flag: Vector3}         new post once the flag is set
##   names:   {flag: name}            known by another name once the flag is set
##   talks:   [entry...]              first entry whose `when` holds is used
##
## entry
##   id, when (GameState.check dict), once (bool), cost (time units, default 1)
##   lines:   [[speaker, text] | {"choice": [labels], "tags": [tag strings]}]
##   after:   tag string applied when the conversation ends
##
## Tags: flag:x  unflag:x  mark:x  rep:faction:+n  time:n  heal:r
##       duel:foe  chain:entry_id  rest  end:ending_id (end:leave / end:time = evaluate)

const STREET_OYUKI := Vector3(-7.3, 0, -1.9)
const CAMP_KURODA := Vector3(18.6, 0, -1.5)

const PLAYER_START := Vector3(0.6, 0, 0.7)
const WAKE_POS := Vector3(-7.3, 0, -0.7)
const WAKE_LINES := [
	["", "..."],
	["Oyuki", "Ah, acordaste! Encontrei-te estendido no meio da rua."],
	["Oyuki", "Dormiste umas boas horas. Bebe este chá e não faças mais disparates... hoje."],
]

const CHARS := {
	# ======================================================================
	"oyuki": {
		"name": "Oyuki", "sheet": "girl",
		"at": {"manha": STREET_OYUKI, "tarde": STREET_OYUKI, "noite": Vector3(-8.2, 0, -1.6)},
		"talks": [
			{"id": "oyuki_assediada", "when": {"period": ["noite"], "day_max": 2, "noflags": ["bandido_resolvido"]},
				"lines": [
					["Oyuki", "Por favor... aquele homem do Corvo não me larga. Diz que a casa de chá agora lhes paga \"protecção\"."],
					["Oyuki", "Ninguém da vila se atreve a dizer nada."],
				]},
			{"id": "oyuki_salva", "once": true, "when": {"flags": ["salvou_oyuki"]},
				"lines": [
					["Oyuki", "Obrigada. A sério. Toma, chá de gengibre com mel: é bom para as feridas."],
					["Oyuki", "Amanhã a vila inteira vai saber o que fizeste. Em Kurogane, as notícias correm mais depressa que o rio."],
				], "after": "heal:0.5;rep:vila:+5"},
			{"id": "oyuki_magoada", "when": {"flags": ["humilhou_oyuki"]},
				"lines": [["Oyuki", "...Afasta-te de mim."]]},
			{"id": "oyuki_espada", "once": true, "when": {"flags": ["espada_forjada"]},
				"lines": [
					["Oyuki", "Essa espada... o Genzō voltou a acender o forno! A vila inteira ouviu o martelo."],
					["Oyuki", "Há anos que ninguém sorria assim em Kurogane."],
				], "after": "rep:vila:+5"},
			{"id": "oyuki_portagem", "once": true, "when": {"day_min": 2},
				"lines": [
					["Oyuki", "O Magistrado dobrou a portagem da ponte outra vez."],
					["Oyuki", "O Heita jura que o dinheiro nem sai da vila. Vai direitinho para a casa do Magistrado."],
				]},
			{"id": "oyuki_1", "once": true,
				"lines": [
					["Oyuki", "Bem-vindo à casa de chá Yamabuki! Senta-te, viajante. O chá é quente e as notícias são de graça."],
					["Oyuki", "Estás em Kurogane-juku. Dizem que o aço daqui corta pedra... mas hoje em dia corta mais gente do que pedra."],
					["Oyuki", "Os guardas do Magistrado Akamatsu cobram portagem na ponte. Os homens do Corvo cobram o resto."],
					["Tu", "E quem protege a vila?"],
					["Oyuki", "...Ninguém. Por isso é que olhaste para mim assim? Guarda essa espada, ronin. Ainda."],
				]},
			{"id": "oyuki_dica",
				"lines": [
					["Oyuki", "O velho Genzō está ali ao lado. Se alguém consegue consertar essa lâmina partida, é ele."],
					["Oyuki", "E se precisares de dormir, a estalagem Tsuru tem esteiras limpas. Mais ou menos limpas."],
				]},
		],
	},
	# ======================================================================
	"genzo": {
		"name": "Genzō", "sheet": "elder",
		"at": {"manha": Vector3(-9.4, 0, -1.7), "tarde": Vector3(-9.4, 0, -1.7)},
		"talks": [
			{"id": "genzo_feito", "when": {"flags": ["espada_forjada"]},
				"lines": [["Genzō", "Uma boa lâmina não faz um bom homem. Mas ajuda. Não a desonres."]]},
			{"id": "genzo_pronta", "when": {"flags": ["forja_iniciada"], "since": {"forja": 1}},
				"lines": [
					["Genzō", "Aqui está. Aço negro de Kurogane, dobrado mil vezes, temperado no rio ao nascer do sol."],
					["", "O peso é perfeito. A lâmina parece respirar contigo."],
					["Genzō", "Agora tens uma espada inteira. Falta saber se tens um homem inteiro para a segurar."],
				], "after": "flag:espada_forjada;unflag:forja_iniciada;rep:vila:+10"},
			{"id": "genzo_espera", "when": {"flags": ["forja_iniciada"]},
				"lines": [["Genzō", "Ainda não. O aço não se apressa. Volta quando o sol tiver mudado de lugar."]]},
			{"id": "genzo_aco", "when": {"flags": ["aco_negro"]},
				"lines": [
					["Genzō", "Isso é... aço negro do velho poço! Há trinta anos que não via um bloco assim."],
					["Genzō", "Deixa-mo. E deixa-me também essa lâmina partida. Volta noutra parte do dia."],
				], "after": "unflag:aco_negro;flag:forja_iniciada;mark:forja;rep:vila:+5"},
			{"id": "genzo_1", "once": true,
				"lines": [
					["Genzō", "Hm. Essa bainha está leve demais para a lâmina que devia levar."],
					["Tu", "Partiu-se. Num duelo que eu perdi."],
					["Genzō", "Uma lâmina partida e um homem vivo. Já vi negócios piores."],
					["Genzō", "Fui o último mestre da forja Hayashi. O Corvo quer o meu aço, o Magistrado quer o meu imposto e o meu neto quer que eu me cale."],
					["Genzō", "Traz-me aço negro do velho poço da mina e talvez eu volte a acender o forno. Talvez."],
				], "after": "flag:quer_aco"},
			{"id": "genzo_dica",
				"lines": [
					["Genzō", "O poço da mina fica depois do santuário. Os guardas do Magistrado vigiam o caminho de dia..."],
					["Genzō", "...à noite dormem, como toda a gente. Mais ou menos como toda a gente."],
				]},
		],
	},
	# ======================================================================
	"tetsu": {
		"name": "Ronin de chapéu de palha", "sheet": "ronin", "duel_spot": Vector3(-4.6, 0, 0.35),
		"names": {"conhece_tetsu": "Tetsu"},
		"at": {"manha": Vector3(17.0, 0, -2.6), "tarde": Vector3(-4.9, 0, -1.4), "noite": Vector3(16.6, 0, 2.2)},
		"gone": ["dead_tetsu"],
		"talks": [
			{"id": "tetsu_vencido", "once": true, "when": {"flags": ["venceu_tetsu"]},
				"lines": [
					["Tetsu", "...Ganhaste. Desta vez."],
					["Tetsu", "O chefe Kuroda vai querer conhecer o vagabundo que me pôs de joelhos. Prepara-te."],
				]},
			{"id": "tetsu_humilde", "when": {"flags": ["venceu_tetsu"]},
				"lines": [["Tetsu", "Não precisas de esfregar. Já percebi."]]},
			{"id": "tetsu_irmao", "when": {"flags": ["corvo_membro"]},
				"lines": [["Tetsu", "Bem-vindo ao bando, irmão. Não me envergonhes à frente do chefe."]]},
			{"id": "tetsu_1", "once": true,
				"lines": [
					["Ronin de chapéu de palha", "..."],
					["Ronin de chapéu de palha", "Mais um ronin com fome. O vale está cheio deles."],
					["Ronin de chapéu de palha", "O chefe Kuroda paga bem a quem sabe segurar uma espada. Mesmo partida."],
					["Ronin de chapéu de palha", "Eu? Eu sou o Tetsu. Ninguém em Kurogane me venceu. Ninguém. Pergunta a quem quiseres."],
					["Tu", "E se eu não quiser trabalhar para o Corvo?"],
					["Tetsu", "Então reza para não te cruzares comigo depois do pôr do sol."],
				], "after": "flag:conhece_tetsu"},
			{"id": "tetsu_desafio",
				"lines": [
					["Tetsu", "Ainda aqui? Pensa na proposta. O Corvo não pergunta duas vezes."],
					["Tetsu", "Ou queres mostrar-me o que vale essa espada?"],
					{"choice": ["Desembainhar a espada", "Ir embora"], "tags": ["duel:tetsu", ""]},
				]},
		],
	},
	# ======================================================================
	"heita": {
		"name": "Heita", "sheet": "villager",
		"at": {"manha": Vector3(4.2, 0, 0.2), "tarde": Vector3(4.2, 0, 0.2)},
		"facing": "side", "flip": true,
		"talks": [
			{"id": "heita_corrupcao", "once": true, "when": {"day_min": 2},
				"lines": [
					["Heita", "Psst. Anda cá. Vi com estes olhos."],
					["Heita", "Os guardas levam o dinheiro da portagem directamente para a casa do Magistrado. Nem um ryō vai para a ponte."],
					["Heita", "Se a vila tivesse alguém com coragem... e uma espada... podia dizer-lho na cara. Eu não. Eu tenho costas fracas."],
				], "after": "flag:sabe_corrupcao"},
			{"id": "heita_guarda", "once": true, "when": {"flags": ["venceu_guarda"]},
				"lines": [["Heita", "Disseram-me que puseste um guarda de joelhos! Ha! Não sei se te agradeça ou se fuja de ti."]],
				"after": "rep:vila:+5"},
			{"id": "heita_1", "once": true,
				"lines": [
					["Heita", "Ai, as minhas costas! Carrego carvão para a forja há vinte anos e agora nem há forja."],
					["Heita", "Para atravessar a ponte vermelha, os guardas querem três moedas. Três! Por uma ponte que o meu avô construiu!"],
					["Heita", "Se fosses um samurai a sério, ias lá e... não, esquece. Não quero sarilhos."],
				]},
			{"id": "heita_dica",
				"lines": [["Heita", "Do outro lado do rio fica o acampamento do Corvo. Ninguém decente vai para lá."]]},
		],
	},
	# ======================================================================
	"guarda": {
		"name": "Guarda do Magistrado", "sheet": "guard", "duel_spot": Vector3(-3.0, 0, -10.1),
		"at": {"manha": Vector3(-3.0, 0, -11.4), "tarde": Vector3(-3.0, 0, -11.4)},
		"gone": ["dead_guarda"],
		"moved": {"venceu_guarda": Vector3(-4.6, 0, -11.2)},
		"talks": [
			{"id": "guarda_vencido",
				"when": {"flags": ["venceu_guarda"]},
				"lines": [["Guarda do Magistrado", "Eu não vi nada! Passa, passa... mas o Magistrado vai saber disto."]]},
			{"id": "guarda_1", "once": true,
				"lines": [
					["Guarda do Magistrado", "Alto! O caminho do santuário está fechado por ordem do Magistrado Akamatsu."],
					["Tu", "Porquê?"],
					["Guarda do Magistrado", "Porque o Magistrado assim o quer. Precisas de mais razões, vagabundo?"],
					["", "A mão dele treme no cabo da espada. Os olhos não param de procurar os outros guardas."],
				]},
			{"id": "guarda_desafio",
				"lines": [
					["Guarda do Magistrado", "Ainda aqui? D-desaparece, antes que eu te prenda por vadiagem."],
					{"choice": ["Forçar a passagem", "Recuar"], "tags": ["duel:guarda", ""]},
				]},
		],
	},
	# ======================================================================
	"bandido": {
		"name": "Bandido do Corvo", "sheet": "bandit", "duel_spot": Vector3(-6.4, 0, 0.45),
		"at": {"noite": Vector3(-6.5, 0, -0.9)},
		"when": [{"day_max": 2}],
		"gone": ["bandido_resolvido", "dead_bandido"],
		"facing": "side", "flip": true,
		"talks": [
			{"id": "bandido_irmao", "when": {"flags": ["corvo_membro"]},
				"lines": [
					["Bandido do Corvo", "Eh, és dos nossos! Anda, ajuda-me a convencer a menina a pagar o que deve."],
					{"choice": ["Ajudar a \"convencê-la\"", "Mandá-lo embora (és do bando, dás ordens)"],
						"tags": ["flag:humilhou_oyuki;flag:bandido_resolvido;rep:vila:-30;rep:corvo:+10",
							"flag:salvou_oyuki;flag:bandido_resolvido;rep:vila:+15;rep:corvo:-5"]},
				]},
			{"id": "bandido_1",
				"lines": [
					["Bandido do Corvo", "Que é que estás a olhar, vagabundo? Isto é assunto do Corvo."],
					["Bandido do Corvo", "A menina deve-nos dinheiro. E se não tem dinheiro... arranja-se outra forma."],
					{"choice": ["Defender a Oyuki", "Juntar-te à brincadeira", "Ignorar"],
						"tags": ["duel:bandido", "flag:humilhou_oyuki;flag:bandido_resolvido;rep:vila:-30;rep:corvo:+15", ""]},
				]},
		],
	},
	# ======================================================================
	"akamatsu": {
		"name": "Magistrado Akamatsu", "sheet": "akamatsu", "duel_spot": Vector3(0.0, 0, 0.5),
		"at": {"manha": Vector3(3.0, 0, -2.3), "tarde": Vector3(3.0, 0, -2.3)},
		"when": [{"day_min": 2}],
		"gone": ["dead_akamatsu"],
		"talks": [
			{"id": "akamatsu_vencido", "when": {"flags": ["venceu_akamatsu"]},
				"lines": [["Magistrado Akamatsu", "Leva o que quiseres... os ryō estão na arca. Mas deixa-me a vida, sim?"]]},
			{"id": "akamatsu_corvo", "when": {"flags": ["corvo_membro"]},
				"lines": [
					["Magistrado Akamatsu", "Um cão do Corvo na minha rua, à luz do dia? Que atrevimento."],
					{"choice": ["Desembainhar, em nome do Corvo", "Recuar"], "tags": ["duel:akamatsu", ""]},
				]},
			{"id": "akamatsu_1", "once": true,
				"lines": [
					["Magistrado Akamatsu", "Ah, o ronin de quem toda a gente fala. Aproxima-te. Não mordo... sem razão."],
					["Magistrado Akamatsu", "Kuroda Jinbei e os seus corvos aterrorizam o meu vale. Roubam, extorquem, não pagam impostos."],
					["Magistrado Akamatsu", "Sobretudo não pagam impostos."],
					["Magistrado Akamatsu", "Mata-o, e terás cinquenta ryō e um lugar à minha mesa."],
					{"choice": ["Aceitar o trabalho", "Recusar"],
						"tags": ["flag:trabalho_magistrado;rep:magistrado:+20;rep:corvo:-10", "rep:magistrado:-5"]},
				]},
			{"id": "akamatsu_acusacao", "when": {"flags": ["sabe_corrupcao"], "rep_min": {"vila": 20}, "noflags": ["trabalho_magistrado"]},
				"lines": [
					["Tu", "A portagem da ponte. Para onde vai o dinheiro, Magistrado?"],
					["Magistrado Akamatsu", "Para a ponte, naturalmente. Para... a manutenção da ponte."],
					["Tu", "A ponte que o avô do Heita construiu. E que ninguém repara há vinte anos."],
					["Magistrado Akamatsu", "...Cuidado com essa língua, vagabundo. Línguas compridas ficam curtas em Kurogane."],
					{"choice": ["Acusá-lo diante da vila e desafiá-lo", "Calar-te"], "tags": ["rep:vila:+10;duel:akamatsu", ""]},
				]},
			{"id": "akamatsu_espera", "when": {"flags": ["trabalho_magistrado"]},
				"lines": [["Magistrado Akamatsu", "O Kuroda ainda respira? Os meus ryō não esperam para sempre, ronin."]]},
			{"id": "akamatsu_dica",
				"lines": [["Magistrado Akamatsu", "Vai à tua vida, vagabundo. E paga a portagem."]]},
		],
	},
	# ======================================================================
	"kuroda": {
		"name": "Kuroda Jinbei", "sheet": "kuroda", "duel_spot": Vector3(17.4, 0, 0.3),
		"at": {"manha": CAMP_KURODA, "tarde": CAMP_KURODA, "noite": CAMP_KURODA},
		"when": [{"day_min": 2}, {"flags": ["venceu_tetsu"]}, {"flags": ["dead_tetsu"]}],
		"gone": ["venceu_kuroda", "dead_kuroda"],
		"talks": [
			{"id": "kuroda_vinganca", "when": {"flags": ["dead_tetsu"]},
				"lines": [
					["Kuroda Jinbei", "Mataste o Tetsu."],
					["Kuroda Jinbei", "Era um idiota orgulhoso. Mas era o MEU idiota."],
					["Kuroda Jinbei", "Não há palavras para isto. Só aço."],
					{"choice": ["Desembainhar"], "tags": ["duel:kuroda"]},
				]},
			{"id": "kuroda_contrato", "when": {"flags": ["trabalho_magistrado"], "noflags": ["corvo_membro"]},
				"lines": [
					["Kuroda Jinbei", "O Magistrado mandou-te, não foi? Cheiras aos ryō dele."],
					["Kuroda Jinbei", "Vieste cumprir o contrato ou só olhar?"],
					{"choice": ["Cumprir o contrato", "Só olhar"], "tags": ["duel:kuroda", ""]},
				]},
			{"id": "kuroda_ordens", "when": {"flags": ["corvo_membro"]},
				"lines": [
					["Kuroda Jinbei", "O Akamatsu passeia-se diante da estalagem de manhã e de tarde, como um pavão."],
					["Kuroda Jinbei", "Os guardas dele são uns cobardes. Tu sabes o que fazer."],
				]},
			{"id": "kuroda_1", "once": true,
				"lines": [
					["Kuroda Jinbei", "Então és tu o vagabundo de quem o Tetsu fala."],
					["", "Ele não se levanta. Não precisa. O ar à volta dele parece mais frio."],
					["Kuroda Jinbei", "O Magistrado rouba a vila com papéis e carimbos. Eu roubo-a com espadas. Pelo menos eu sou honesto."],
					["Kuroda Jinbei", "Junta-te ao Corvo. Derruba o Akamatsu, e o vale será nosso."],
					{"choice": ["Juntar-me ao Corvo", "Recusar"],
						"tags": ["flag:corvo_membro;rep:corvo:+25;rep:magistrado:-20", "rep:corvo:-5"]},
				]},
			{"id": "kuroda_protetor", "when": {"rep_min": {"vila": 30}, "noflags": ["corvo_membro"]},
				"lines": [
					["Tu", "Kurogane não precisa de corvos."],
					["Kuroda Jinbei", "...A vila escolheu um campeão. Que comovente."],
					{"choice": ["Expulsá-lo do vale", "Ainda não"], "tags": ["duel:kuroda", ""]},
				]},
			{"id": "kuroda_dica",
				"lines": [["Kuroda Jinbei", "O vento ainda sopra a teu favor, vagabundo. Por agora."]]},
		],
	},
	# ======================================================================
	# invisible spots
	"estalagem": {
		"name": "Estalagem Tsuru", "sheet": "",
		"at": {"manha": Vector3(1.5, 0, -3.05), "tarde": Vector3(1.5, 0, -3.05), "noite": Vector3(1.5, 0, -3.05)},
		"talks": [
			{"id": "estalagem_fim", "cost": 0, "when": {"day_min": 3, "period": ["noite"]},
				"lines": [
					["", "A estalagem está silenciosa. A última noite em Kurogane."],
					{"choice": ["Dormir (o terceiro dia termina)", "Sair"], "tags": ["rest", ""]},
				]},
			{"id": "estalagem", "cost": 0,
				"lines": [
					["", "A estalagem Tsuru cheira a arroz cozido e a tatami velho."],
					{"choice": ["Descansar até à próxima parte do dia", "Sair"], "tags": ["rest", ""]},
				]},
		],
	},
	"santuario": {
		"name": "Caminho do santuário", "sheet": "",
		"at": {"manha": Vector3(-3.0, 0, -12.15), "tarde": Vector3(-3.0, 0, -12.15), "noite": Vector3(-3.0, 0, -12.15)},
		"talks": [
			{"id": "santuario_bloqueado", "cost": 0,
				"when": {"period": ["manha", "tarde"], "noflags": ["venceu_guarda", "dead_guarda"]},
				"lines": [["Guarda do Magistrado", "Alto! Afasta-te do torii. Ninguém passa!"]]},
			{"id": "santuario_vazio", "cost": 0,
				"when": {"anyflags": ["aco_negro", "forja_iniciada", "espada_forjada"]},
				"lines": [["", "O velho poço da mina já não tem mais nada para te dar."]]},
			{"id": "santuario", "cost": 0,
				"lines": [
					["", "Para lá do torii, um carreiro sobe a encosta até ao velho poço da mina."],
					{"choice": ["Subir ao poço (demora algum tempo)", "Ficar"], "tags": ["chain:santuario_mina", ""]},
				]},
			{"id": "santuario_mina", "cost": 3, "chained": true,
				"lines": [
					["", "Sobes o carreiro entre pinheiros e lanternas de pedra caídas."],
					["", "No fundo do poço, entre ferrugem e ossos de raposa, um bloco de metal escuro brilha como água à noite."],
					["Tu", "Aço negro."],
				], "after": "flag:aco_negro"},
		],
	},
	"estrada": {
		"name": "Estrada para leste", "sheet": "",
		"at": {"manha": Vector3(20.5, 0, 0.25), "tarde": Vector3(20.5, 0, 0.25), "noite": Vector3(20.5, 0, 0.25)},
		"talks": [
			{"id": "estrada", "cost": 0,
				"lines": [
					["", "A estrada sai do vale para leste, entre arrozais e montanhas."],
					{"choice": ["Deixar o vale de Kurogane", "Ficar"], "tags": ["end:leave", ""]},
				]},
		],
	},
}

## Journal lines, shown for every flag that is set (in this order).
const JOURNAL := [
	["conhece_tetsu", "Conheceste Tetsu, ronin do Bando do Corvo."],
	["quer_aco", "O ferreiro Genzō pediu aço negro do velho poço da mina."],
	["aco_negro", "Tens um bloco de aço negro."],
	["forja_iniciada", "Genzō está a forjar a tua nova lâmina."],
	["espada_forjada", "Empunhas uma lâmina de aço negro."],
	["venceu_tetsu", "Derrotaste Tetsu num duelo."],
	["dead_tetsu", "Mataste Tetsu."],
	["venceu_guarda", "Humilhaste um guarda do Magistrado."],
	["dead_guarda", "Mataste um guarda do Magistrado."],
	["salvou_oyuki", "Defendeste Oyuki do Corvo."],
	["humilhou_oyuki", "Ajudaste o Corvo a extorquir Oyuki."],
	["sabe_corrupcao", "Sabes que Akamatsu embolsa a portagem da ponte."],
	["trabalho_magistrado", "Aceitaste matar Kuroda pelo Magistrado."],
	["corvo_membro", "Juntaste-te ao Bando do Corvo."],
	["venceu_kuroda", "Derrotaste Kuroda Jinbei."],
	["dead_kuroda", "Mataste Kuroda Jinbei."],
	["venceu_akamatsu", "Derrotaste o Magistrado Akamatsu."],
	["dead_akamatsu", "Mataste o Magistrado Akamatsu."],
]
