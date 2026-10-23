class_name StoryHUD
extends CanvasLayer
## Exploration HUD (clock + vitality), the journal (Tab / J) and the
## part-of-day title card.

const GOLD := Color(0.85, 0.7, 0.4)
const INK := Color(0.06, 0.07, 0.14, 0.88)
const TEXT := Color(0.96, 0.93, 0.86)

var clock_label: Label
var pips: Label
var hp_bar: ProgressBar
var hp_label: Label
var clock_panel: PanelContainer
var journal_panel: PanelContainer
var journal_body: RichTextLabel
var card: Label
var journal_open := false


func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	clock_panel = _panel(INK)
	clock_panel.offset_left = 24
	clock_panel.offset_top = 20
	root.add_child(clock_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	clock_panel.add_child(_margin(v, 14, 8))
	clock_label = _label("", 22, Color(1.0, 0.92, 0.75))
	v.add_child(clock_label)
	pips = _label("", 15, Color(0.9, 0.8, 0.55))
	v.add_child(pips)
	var hrow := HBoxContainer.new()
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(150, 10)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.12)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.78, 0.22, 0.2)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fg)
	hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(hp_bar)
	hp_label = _label("", 14, TEXT)
	hrow.add_child(hp_label)
	v.add_child(hrow)
	var help := _label("[Tab] Diário", 13, Color(0.7, 0.68, 0.75))
	v.add_child(help)

	journal_panel = _panel(Color(0.05, 0.05, 0.1, 0.95))
	journal_panel.set_anchors_preset(Control.PRESET_CENTER)
	journal_panel.offset_left = -360
	journal_panel.offset_right = 360
	journal_panel.offset_top = -260
	journal_panel.offset_bottom = 260
	root.add_child(journal_panel)
	journal_body = RichTextLabel.new()
	journal_body.bbcode_enabled = true
	journal_body.scroll_active = true
	journal_body.add_theme_font_size_override("normal_font_size", 18)
	journal_body.add_theme_font_size_override("bold_font_size", 22)
	journal_body.add_theme_color_override("default_color", TEXT)
	journal_panel.add_child(_margin(journal_body, 26, 20))
	journal_panel.visible = false

	card = _label("", 46, Color(1.0, 0.94, 0.82))
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -500
	card.offset_right = 500
	card.offset_top = -60
	card.offset_bottom = 60
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_constant_override("outline_size", 12)
	card.modulate.a = 0.0
	root.add_child(card)


func _panel(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _margin(c: Control, h: int, vv: int) -> MarginContainer:
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, h)
	for s in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, vv)
	m.add_child(c)
	return m


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 6)
	return l


func refresh(s: GameState) -> void:
	clock_label.text = s.clock_text()
	var left := s.units_left()
	pips.text = "●".repeat(left) + "○".repeat(GameState.UNITS_PER_PERIOD - left)
	hp_bar.max_value = s.hero_max_hp()
	hp_bar.value = s.hero_hp
	hp_label.text = "  %d/%d" % [s.hero_hp, s.hero_max_hp()]
	if journal_open:
		_fill_journal(s)


func set_explore_visible(on: bool) -> void:
	clock_panel.visible = on


func toggle_journal(s: GameState) -> void:
	journal_open = not journal_open
	journal_panel.visible = journal_open
	if journal_open:
		_fill_journal(s)


func _fill_journal(s: GameState) -> void:
	var t := "[b]Diário de um ronin[/b]\n%s  ·  %s\n\n" % [s.clock_text(), s.blade_name()]
	t += "[b]Reputação[/b]\n"
	for f in GameState.FACTIONS:
		var r: int = s.rep[f]
		var col := "#8ee68e" if r > 10 else ("#ff8070" if r < -10 else "#d8d0c0")
		var word := "aliado" if r >= 40 else ("respeita-te" if r > 10 else ("hostil" if r <= -40 else ("desconfia" if r < -10 else "neutro")))
		t += "  %s: [color=%s]%+d  (%s)[/color]\n" % [GameState.FACTION_NAMES[f], col, r, word]
	t += "\n[b]Acontecimentos[/b]\n"
	var j := Story.journal(s)
	if j.is_empty():
		t += "  [i]Acabaste de chegar a Kurogane.[/i]\n"
	for line in j:
		t += "  · %s\n" % line
	t += "\n[color=#a8a0b8]Finais descobertos: %d de %d[/color]" % [Endings.discovered().size(), Endings.ALL.size()]
	t += "\n[color=#a8a0b8][Tab] fechar[/color]"
	journal_body.text = t


func show_card(text: String, hold: float) -> void:
	card.text = text
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.5 * hold)
	tw.tween_interval(hold)
	tw.tween_property(card, "modulate:a", 0.0, 0.5 * hold)
