# My Samurai Way

RPG de samurai em **HD-2D**, inspirado em *Way of the Samurai*: um ronin chega a
um vale dividido entre facções e, em poucos dias, as escolhas dele decidem quem
fica com o vale e qual dos muitos finais acontece. Os duelos são **por turnos,
estilo JRPG**.

## Pilares
1. **Vale vivo, tempo curto.** Cada vale decorre em poucos dias (manhã → tarde →
   noite). As facções movem-se sem esperar pelo jogador.
2. **Liberdade de lealdade.** Podes servir, trair ou ignorar qualquer facção a
   qualquer momento; o jogo lembra-se.
3. **Muitos finais.** Os finais saem do estado do mundo (quem vive, quem manda,
   reputação, a tua katana), não de um único ramo de diálogo.
4. **Duelos por turnos com peso.** Posturas, guarda, ataques fracos e fortes,
   contra-ataques e *bocas*, num combate curto e mortal.
5. **HD-2D.** Sprites em pixel-art iluminados num diorama 3D com bloom,
   profundidade de campo, nevoeiro e luz dinâmica.

## Arte
Toda a arte é gerada por código e é reprodutível:

```bash
uv run --with pillow --with numpy python tools/gen_art.py
```

- `assets/sprites/char_*.png`: folhas de 5×3 (idle + 4 frames de caminhada ×
  baixo/cima/lado) com 32×48 px por frame.
- `assets/sprites/tree_*.png`, `bush.png`: folhagem sombreada por esferas.
- `assets/textures/*.png`: tiles com 32 px por metro, aplicados em triplanar
  no mundo.

## O vale e o tempo
- **3 dias**, cada um com **manhã** (neblina), **tarde** (dourada) e **noite**.
- Cada conversa gasta tempo (●●●●●●●● no canto do ecrã). Um duelo gasta mais. Na **estalagem** descansas e passas à parte seguinte do dia.
- As pessoas mudam conforme a hora. À noite o guarda do santuário dorme e um bandido do Corvo aparece na casa de chá. No dia 2 chegam o Magistrado Akamatsu e o chefe Kuroda.
- Há três **facções** (Corvo, Magistrado e Vila), cada uma com a sua **reputação**.
- **[Tab] Diário**: mostra a reputação, os acontecimentos e os finais descobertos.
- Depois de vencer um duelo escolhes **poupar ou matar** o adversário. Os mortos não voltam.
- Se perderes, acordas horas depois na casa de chá, com as feridas.

### Finais (10)
| Final | Como |
|---|---|
| O Protetor de Kurogane | derrotar Kuroda **e** Akamatsu com a vila do teu lado |
| O Corvo Voa Alto | juntar-te ao Corvo e derrubar o Magistrado |
| A Espada do Magistrado | aceitar o contrato do Magistrado e derrotar Kuroda |
| A Lâmina Renascida | trazer aço negro ao Genzō, forjar a espada e partir |
| O Desertor | aceitar um trabalho e fugir pela estrada |
| Só de Passagem | partir sem mudar nada |
| O Ronin Maldito | a vila odeia-te (reputação ≤ −40) |
| Kurogane em Chamas | tomar um lado e deixar o tempo acabar |
| Mais Um Dia em Kurogane | o terceiro dia acaba sem nada resolvido |
| O Último Corte | perder contra Kuroda |

Os finais descobertos ficam guardados entre jogos (`user://finais.cfg`).

### Acrescentar conteúdo
A história é **orientada a dados** e está em `scripts/story/story_data.gd`. Cada personagem tem horários,
condições de presença e conversas. Cada conversa tem condições (`when`) e efeitos (`after` e tags nas
escolhas). Os finais são regras em `scripts/story/endings.gd`. O `tests/test_story.gd` valida tudo:
tags, flags lidas mas nunca ativadas, NPCs presentes sem nada para dizer, e uma rota até cada final.

## Duelos
Os duelos são **por turnos** e decorrem na própria rua, onde estás. Em cada turno o adversário
mostra a **intenção** (golpe rápido, golpe forte, guarda, contra-ataque, técnica). A
habilidade está em lê-la:

- **Golpe forte** atravessa uma guarda, mas pode ser contra-atacado.
- **Contra-ataque** só desvia golpes fortes. Contra um golpe rápido ficas em contrapé.
- **Guarda** contra técnicas. O **Corte do Relâmpago** (60 ki) não pode ser contra-atacado.
- Alguns adversários **fintam**: mostram uma intenção e fazem outra.

### Bocas
Antes de agir podes **mandar uma boca** (15 ki, uma por turno, não gasta o turno). Cada
adversário tem uma **personalidade escondida** que decide o efeito:

| | Insulto | Ameaça | Troça | Lisonja | Tentação |
|---|---|---|---|---|---|
| **Orgulhoso** | enfurece | motiva ⚠ | abala | distrai | — |
| **Colérico** | enfurece | enfurece | enfurece | distrai | — |
| **Cobarde** | — | intimida (rende-se!) | abala | motiva ⚠ | distrai |
| **Estoico** | foca ⚠ | foca ⚠ | abala (raro) | foca ⚠ | foca ⚠ |
| **Ganancioso** | enfurece | abala | — | — | distrai |

- *Abalado / intimidado / enfurecido*: o adversário deixa de conseguir fintar.
- *Enfurecido*: bate mais forte, mas larga a guarda.
- *Distraído*: perde a vez.
- Repetir a mesma boca resulta cada vez menos ("já ouvi essa").
- A personalidade revela-se quando uma boca tem efeito, ou se usares **Observar**.
- Os aldeões dão pistas sobre quem é quem.

Balanceamento medido com jogadores simulados (`tests/test_duel.gd`, 400 duelos cada):

| contra | atacar às cegas | ler intenções | + bocas certas | + bocas erradas |
|---|---|---|---|---|
| Tetsu (orgulhoso) | 16% | 71% | 86% | 27% |
| Guarda (cobarde) | 44% | 83% | 97% | 35% |

## Som e música
Tudo é sintetizado em código e determinístico (os mesmos ficheiros em cada execução):
```bash
uv run --with numpy python tools/gen_sfx.py   && uv run --with numpy python tools/verify_sfx.py
uv run --with numpy python tools/gen_music.py && uv run --with numpy python tools/verify_music.py
```
- **Música** (`assets/audio/music/`), na escala miyako-bushi em Ré:
  - `town_day`: koto e shakuhachi, 80 BPM.
  - `town_night`: drone, koto esparso e sino de templo.
  - `duel`: taiko, shime-daiko, shamisen e hyoshigi, 132 BPM.
  - `ending`: shakuhachi a solo.
- **Ambiente**: `amb_day` (vento, pássaros, riacho) e `amb_night` (grilos, riacho).
- **30 efeitos** (`assets/audio/sfx/`): espadas, impactos, contra-ataque metálico, bocas, reações,
  passos em terra e em madeira, sino das horas, interface e máquina de escrever.
- A música e o ambiente seguem o relógio, com crossfade. O duelo e o final têm música própria.

## Controlos
| Tecla | Ação |
|---|---|
| WASD / setas | andar |
| Shift (manter) | correr |
| E / Espaço / Enter | falar · avançar diálogo |
| Esc | avançar / fechar diálogo · voltar no menu de bocas |
| Tab / J | diário |
| Setas / W S + E | navegar nos menus e escolhas |

## Correr
```bash
GODOT=".../Godot_v4.7-stable_win64_console.exe"
"$GODOT" --path .                              # jogar
"$GODOT" --path . -- --look noite              # dourado | neblina | noite
"$GODOT" --path . -- --capture res://.captures # renderiza as 3 luzes e sai
"$GODOT" --path . -- --shots res://.captures   # capturas de jogo (andar/falar/ponte)
```

## Testes
```bash
"$GODOT" --headless --path . -s tests/smoke_project_config.gd   # config + input map
"$GODOT" --headless --path . -s tests/test_audio.gd              # todos os sons referidos existem; loops em loop
"$GODOT" --headless --path . -s tests/test_story.gd              # história: dados, horários, rotas para os 10 finais
"$GODOT" --headless --path . -s tests/test_duel.gd               # lógica do duelo + balanceamento
"$GODOT" --headless --path . -s tests/foe_report.gd              # taxas de vitória por adversário e estilo
"$GODOT" --headless --path . -s tests/balance_sweep.gd           # grelha de stats vs. estilos de jogo
"$GODOT" --headless --path . -- --playthrough                    # integração (jogo real)
```

## Estrutura
- `scripts/main.gd`: cena de entrada, câmara e hooks da linha de comandos.
- `scripts/village.gd`: constrói Kurogane-juku (com colisões e altura do terreno).
- `scripts/actor.gd`, `player.gd`, `npc.gd`: personagens que andam, com animação de 4 frames em 3 direções.
- `scripts/npc_data.gd`: quem vive na vila e o que diz (facções e enredo).
- `scripts/dialogue_box.gd`: caixa de diálogo com efeito de máquina de escrever.
- `scripts/duel/`: duelos. Contém `duel.gd` (lógica pura), `personality.gd` (tabela de reações),
  `bocas.gd`, `foes.gd`, `duel_stage.gd` (animação no mundo) e `duel_ui.gd` (interface).
- `scripts/story/`: `game_state.gd` (relógio, reputação, flags), `story_data.gd` (o vale),
  `story.gd` (quem está onde e o que diz), `endings.gd`, `story_hud.gd` e `ending_screen.gd`.
- `scripts/look.gd`: presets de luz e pós-processamento.
- `scripts/pixel_sprite.gd` + `shaders/sprite_lit.gdshader`: cartões de
  pixel-art iluminados que projetam sombra.
- `scripts/mat.gd`: materiais partilhados (densidade de texels constante).
