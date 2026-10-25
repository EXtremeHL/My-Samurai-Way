class_name UiStyle
## The game's look for every screen: washi paper panels, brush-ink text and a
## vermilion hanko seal for names and highlights. Panels come from generated
## 9-slice textures (tools/gen_art.py -> assets/ui/).
##
## Two text registers:
##   on paper  -> INK colours, no outline
##   over the 3D scene (hints, banners, floating numbers) -> CREAM + dark outline

const WASHI := preload("res://assets/ui/washi.png")
const SEAL := preload("res://assets/ui/seal.png")
const PAPER_MARGIN := 24           # matches UI_MARGIN in gen_art.py
const SEAL_MARGIN := 10

const INK := Color(0.16, 0.12, 0.11)
const INK_SOFT := Color(0.38, 0.31, 0.27)
const INK_FAINT := Color(0.55, 0.48, 0.42)
const VERMILION := Color(0.69, 0.14, 0.12)
const SEAL_TEXT := Color(0.99, 0.94, 0.9)
const CREAM := Color(1.0, 0.94, 0.84)
const GOLD := Color(0.95, 0.78, 0.5)
const OUTLINE := Color(0.06, 0.03, 0.05)
# readable on paper (darker than the over-scene versions)
const GOOD_INK := Color(0.16, 0.45, 0.2)
const BAD_INK := Color(0.66, 0.13, 0.1)
const RISK_INK := Color(0.62, 0.38, 0.05)
const FILL_HP := Color(0.69, 0.16, 0.13)
const FILL_KI := Color(0.18, 0.32, 0.55)


## Washi panel. `pad` is the inner space around the content, in px.
static func paper(pad_h := 22, pad_v := 16) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = WASHI
	sb.set_texture_margin_all(PAPER_MARGIN)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	# the paper sits 6 px in from the texture edge (10 px bottom/right: shadow)
	sb.content_margin_left = 6 + pad_h
	sb.content_margin_right = 10 + pad_h
	sb.content_margin_top = 6 + pad_v
	sb.content_margin_bottom = 10 + pad_v
	return sb


static func seal(pad_h := 14, pad_v := 4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = SEAL
	sb.set_texture_margin_all(SEAL_MARGIN)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func panel(pad_h := 22, pad_v := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", paper(pad_h, pad_v))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func seal_panel(text: String, size := 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", seal())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := ink_label(text, size, SEAL_TEXT)
	l.name = "Text"
	p.add_child(l)
	return p


## Text on paper.
static func ink_label(text: String, size: int, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Text drawn straight over the scene.
static func scene_label(text: String, size: int, color := CREAM, outline := 6) -> Label:
	var l := ink_label(text, size, color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	return l


static func ink_rich(size: int, color := INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 1)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_constant_override("line_separation", 4)
	return r


## An ink-stroke bar (vitality / ki) for paper panels.
static func bar(fill: Color, width := 150, height := 9) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, height)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.12)
	bg.border_color = Color(INK, 0.55)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


static func margin(c: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(c)
	return m


## Menu row text: a vermilion pointer on the selected one.
static func menu_text(label: String, selected: bool) -> String:
	return ("▶  " + label) if selected else ("     " + label)
