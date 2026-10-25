class_name StoryHUD
extends CanvasLayer
## Exploration HUD (clock + vitality), the journal (Tab / J) and the
## part-of-day title card.


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

	clock_panel = UiStyle.panel(16, 8)
	clock_panel.offset_left = 24
	clock_panel.offset_top = 20
	root.add_child(clock_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	clock_panel.add_child(UiStyle.margin(v, 0, 6))
	clock_label = UiStyle.ink_label("", 24)
	v.add_child(clock_label)
	pips = UiStyle.ink_label("", 15, UiStyle.INK_SOFT)
	v.add_child(pips)
	var hrow := HBoxContainer.new()
	hp_bar = UiStyle.bar(UiStyle.FILL_HP, 150, 9)
	hrow.add_child(hp_bar)
	hp_label = UiStyle.ink_label("", 15, UiStyle.INK_SOFT)
	hrow.add_child(hp_label)
	v.add_child(hrow)
	var help := UiStyle.ink_label("[Tab] Diário  ·  [Esc] Pausa", 14, UiStyle.INK_FAINT)
	v.add_child(help)

	journal_panel = UiStyle.panel(34, 24)
	journal_panel.set_anchors_preset(Control.PRESET_CENTER)
	journal_panel.offset_left = -360
	journal_panel.offset_right = 360
	journal_panel.offset_top = -260
	journal_panel.offset_bottom = 260
	root.add_child(journal_panel)
	journal_body = UiStyle.ink_rich(19)
	journal_body.scroll_active = true
	journal_body.add_theme_font_size_override("bold_font_size", 24)
	var sb := journal_body.get_v_scroll_bar()
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(UiStyle.INK, 0.35)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	sb.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
		sb.add_theme_stylebox_override(k, grab)
	journal_panel.add_child(UiStyle.margin(journal_body, 0, 6))
	journal_panel.visible = false

	card = UiStyle.scene_label("", 52, UiStyle.CREAM, 12)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -500
	card.offset_right = 500
	card.offset_top = -60
	card.offset_bottom = 60
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_constant_override("outline_size", 12)
	card.modulate.a = 0.0
	root.add_child(card)


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
	var red := UiStyle.VERMILION.to_html(false)
	var t := "[b][color=#%s]Diário de um ronin[/color][/b]\n%s  ·  %s\n\n" % [red, s.clock_text(), s.blade_name()]
	t += "[b]Reputação[/b]\n"
	for f in GameState.FACTIONS:
		var r: int = s.rep[f]
		var col := UiStyle.GOOD_INK.to_html(false) if r > 10 else (UiStyle.BAD_INK.to_html(false) if r < -10 else UiStyle.INK_SOFT.to_html(false))
		var word := "aliado" if r >= 40 else ("respeita-te" if r > 10 else ("hostil" if r <= -40 else ("desconfia" if r < -10 else "neutro")))
		t += "  %s: [color=#%s]%+d  (%s)[/color]\n" % [GameState.FACTION_NAMES[f], col, r, word]
	t += "\n[b]Acontecimentos[/b]\n"
	var j := Story.journal(s)
	if j.is_empty():
		t += "  [i]Acabaste de chegar a Kurogane.[/i]\n"
	for line in j:
		t += "  · %s\n" % line
	var faint := UiStyle.INK_FAINT.to_html(false)
	t += "\n[color=#%s]Finais descobertos: %d de %d[/color]" % [faint, Endings.discovered().size(), Endings.ALL.size()]
	t += "\n[color=#%s][Tab] fechar[/color]" % faint
	journal_body.text = t


func show_card(text: String, hold: float) -> void:
	card.text = text
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.5 * hold)
	tw.tween_interval(hold)
	tw.tween_property(card, "modulate:a", 0.0, 0.5 * hold)
