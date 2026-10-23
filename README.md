# O Caminho do Ronin

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

## Correr
```bash
GODOT=".../Godot_v4.7-stable_win64_console.exe"
"$GODOT" --path . -- --look noite              # dourado | neblina | noite
"$GODOT" --path . -- --capture res://.captures # renderiza as 3 luzes e sai
```

## Estrutura
- `scripts/main.gd`: cena de entrada, câmara e hooks da linha de comandos.
- `scripts/village.gd`: constrói Kurogane-juku, o primeiro vale.
- `scripts/look.gd`: presets de luz e pós-processamento.
- `scripts/pixel_sprite.gd` + `shaders/sprite_lit.gdshader`: cartões de
  pixel-art iluminados que projetam sombra.
- `scripts/mat.gd`: materiais partilhados (densidade de texels constante).
