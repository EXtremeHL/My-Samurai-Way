class_name DuelUI
extends CanvasLayer
## Duel HUD: fighter panels, intent banner, action menu, description box,
## speech bubbles and floating combat text. Pure presentation - DuelStage
## tells it what to show and listens for `picked`.

signal picked(kind: String, value: int)   # kind: "act" | "boca" | "back"

const GOLD := Color(0.85, 0.7, 0.4)
const INK := Color(0.06, 0.07, 0.14, 0.92)
const TEXT := Color(0.96, 0.93, 0.86)
const GOOD := Color(0.55, 0.9, 0.55)
const BAD := Color(1.0, 0.5, 0.42)
const RISK := Color(1.0, 0.78, 0.35)

var root: Control
var hero_panel: Dictionary
var foe_panel: Dictionary
var intent_label: Label
var intent_panel: PanelContainer
var menu_panel: PanelContainer
var menu_box: VBoxContainer
var desc_label: RichTextLabel
var desc_panel: PanelContainer
var banner: Label
var _descs := {}
var blade_name := "Lâmina partida"
var _bubbles := {}


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hero_panel = _fighter_panel(false)
	foe_panel = _fighter_panel(true)

	intent_panel = _panel(Color(0.12, 0.05, 0.06, 0.9))
	intent_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	intent_panel.offset_left = -330
	intent_panel.offset_right = 330
	intent_panel.offset_top = 176
	root.add_child(intent_panel)
	intent_label = _label("", 20, TEXT)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_panel.add_child(_margin(intent_label, 16, 8))

	menu_panel = _panel(INK)
	menu_panel.anchor_top = 1.0
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_left = 40
	menu_panel.offset_right = 330
	menu_panel.offset_bottom = -30
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(menu_panel)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 2)
	menu_panel.add_child(_margin(menu_box, 12, 10))

	desc_panel = _panel(INK)
	desc_panel.anchor_left = 0.0
	desc_panel.anchor_right = 1.0
	desc_panel.anchor_top = 1.0
	desc_panel.anchor_bottom = 1.0
	desc_panel.offset_left = 350
	desc_panel.offset_right = -40
	desc_panel.offset_top = -158
	desc_panel.offset_bottom = -30
	root.add_child(desc_panel)
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.scroll_active = false
	desc_label.add_theme_font_size_override("normal_font_size", 19)
	desc_label.add_theme_font_size_override("bold_font_size", 20)
	desc_label.add_theme_color_override("default_color", TEXT)
	desc_panel.add_child(_margin(desc_label, 18, 12))

	banner = _label("", 64, Color(1.0, 0.92, 0.75))
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.offset_left = -500
	banner.offset_right = 500
	banner.offset_top = -120
	banner.offset_bottom = -20
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_constant_override("outline_size", 16)
	banner.modulate.a = 0.0
	root.add_child(banner)
	show_menu(false)


# ---------------------------------------------------------------------------
# builders
# ---------------------------------------------------------------------------
func _box(bg: Color, border := GOLD, w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 5
	return sb


func _panel(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(bg))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _margin(child: Control, h: int, v: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", h)
	m.add_theme_constant_override("margin_right", h)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.add_child(child)
	return m


func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _bar(fill: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(250, 14)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.12)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.8)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func _fighter_panel(right: bool) -> Dictionary:
	var p := _panel(INK)
	if right:
		p.anchor_left = 1.0
		p.anchor_right = 1.0
		p.offset_left = -360
		p.offset_right = -40
	else:
		p.offset_left = 40
		p.offset_right = 360
	p.offset_top = 24
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(_margin(v, 14, 10))
	var top := HBoxContainer.new()
	var name_l := _label("", 22, Color(1.0, 0.92, 0.75))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mood_l := _label("", 17, RISK)
	top.add_child(name_l)
	top.add_child(mood_l)
	v.add_child(top)
	var sub := _label("", 16, Color(0.75, 0.72, 0.8))
	v.add_child(sub)
	var hp_row := HBoxContainer.new()
	var hp := _bar(Color(0.78, 0.22, 0.2))
	var hp_t := _label("", 15, TEXT)
	hp_row.add_child(hp)
	hp_row.add_child(hp_t)
	v.add_child(hp_row)
	var ki_row := HBoxContainer.new()
	var ki := _bar(Color(0.35, 0.6, 0.95))
	ki.custom_minimum_size.y = 9
	var ki_t := _label("", 15, Color(0.7, 0.82, 1.0))
	ki_row.add_child(ki)
	ki_row.add_child(ki_t)
	v.add_child(ki_row)
	return {"panel": p, "name": name_l, "mood": mood_l, "sub": sub, "hp": hp, "hp_t": hp_t, "ki": ki, "ki_t": ki_t}


# ---------------------------------------------------------------------------
# state display
# ---------------------------------------------------------------------------
func refresh(duel: Duel) -> void:
	_fill(hero_panel, duel.hero, blade_name, true)
	var sub := "Personalidade: ???"
	if duel.foe.revealed:
		sub = "Personalidade: %s" % Personality.NAMES[duel.foe.personality]
	_fill(foe_panel, duel.foe, sub, false)


func _fill(p: Dictionary, f: Fighter, sub: String, is_hero: bool) -> void:
	p.name.text = f.name
	p.sub.text = sub
	p.hp.max_value = f.max_hp
	var tw := create_tween()
	tw.tween_property(p.hp, "value", float(f.hp), 0.35)
	p.hp_t.text = " %d/%d" % [f.hp, f.max_hp]
	p.ki.max_value = 100
	p.ki.value = f.ki
	p.ki_t.text = " ki %d" % f.ki
	p.mood.text = Personality.MOOD_NAMES[f.mood].to_upper()
	p.mood.add_theme_color_override("font_color", mood_color(f.mood, not is_hero))


static func mood_color(m: int, on_foe: bool) -> Color:
	if m in Personality.GOOD_FOR_SPEAKER:
		return GOOD if on_foe else BAD
	if m in Personality.RISKY:
		return RISK
	return BAD if on_foe else GOOD


func set_intent(t: String, flash := false) -> void:
	intent_label.text = t
	if flash:
		intent_panel.modulate = Color(2.0, 1.6, 1.2)
		create_tween().tween_property(intent_panel, "modulate", Color.WHITE, 0.6)


# ---------------------------------------------------------------------------
# menus
# ---------------------------------------------------------------------------
func show_menu(on: bool) -> void:
	menu_panel.visible = on
	desc_panel.visible = on


func _clear_menu() -> void:
	for c in menu_box.get_children():
		menu_box.remove_child(c)
		c.queue_free()
	_descs.clear()


func _item(text: String, kind: String, value: int, desc: String, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.45))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.45))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.43, 0.5))
	var empty := StyleBoxEmpty.new()
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.85, 0.7, 0.4, 0.18)
	focus.set_corner_radius_all(3)
	for s in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("hover", focus)
	b.pressed.connect(func(): picked.emit(kind, value))
	b.focus_entered.connect(func(): desc_label.text = desc)
	b.mouse_entered.connect(func(): b.grab_focus())
	menu_box.add_child(b)
	_descs[b] = desc
	return b


func build_main_menu(duel: Duel) -> void:
	_clear_menu()
	var A := Duel.Act
	var tech_ok := duel.can_use(A.TECH)
	_item("Golpe rápido", "act", A.LIGHT,
		"[b]Golpe rápido[/b]: dano 1×, pontaria 92%.\nSeguro, e apanha quem espera por um contra-ataque.")
	_item("Golpe forte", "act", A.HEAVY,
		"[b]Golpe forte[/b]: dano 1.8×, pontaria 74%.\nAtravessa boa parte de uma guarda. Pode ser contra-atacado.")
	_item("%s (%d ki)" % [Duel.TECH_NAME, Duel.TECH_COST], "act", A.TECH,
		"[b]%s[/b]: dano 2.6×, pontaria 95%%. Não pode ser contra-atacado.\nCusta %d ki (tens %d)." % [Duel.TECH_NAME, Duel.TECH_COST, duel.hero.ki], tech_ok)
	_item("Guarda", "act", A.GUARD,
		"[b]Guarda[/b]: reduz muito o dano deste turno e recupera %d ki." % Duel.KI_GUARD)
	_item("Contra-ataque", "act", A.PARRY,
		"[b]Contra-ataque[/b]: se ele der um [b]golpe forte[/b], desvias e cortas de volta.\nContra um golpe rápido, ficas em contrapé (+30% de dano).")
	var boca_desc := "[b]Boca[/b]: diz-lhe umas verdades [i]antes[/i] de agires (%d ki).\nO efeito depende da personalidade dele: pode enfraquecê-lo... ou fortalecê-lo." % Duel.BOCA_KI
	if duel.boca_used:
		boca_desc = "Já mandaste uma boca este turno."
	elif not duel.can_boca():
		boca_desc = "Sem fôlego: precisas de %d ki para mandar uma boca." % Duel.BOCA_KI
	_item("Boca ▸", "boca_menu", 0, boca_desc, duel.can_boca())
	_item("Observar", "act", A.OBSERVE,
		"[b]Observar[/b]: gasta o turno a estudá-lo. Revela a personalidade e ganha %d ki." % Duel.KI_OBSERVE)
	show_menu(true)
	_focus_first()


func build_boca_menu(duel: Duel) -> void:
	_clear_menu()
	for c in Bocas.ORDER:
		var line := "[b]%s[/b]: %s" % [Bocas.NAMES[c], Bocas.HINTS[c]]
		var heard := duel.foe.times_heard(c)
		if duel.foe.revealed:
			var o := duel.boca_odds(c)
			var mood: int = o[0]
			var col := mood_color(mood, true).to_html(false)
			if mood == Personality.Mood.NONE:
				line += "\n[color=#%s]%s[/color]" % [Color(0.7, 0.7, 0.75).to_html(false), Personality.MOOD_SUMMARY[mood]]
			else:
				line += "\n[color=#%s]%s[/color]  (%d%%)" % [col, Personality.MOOD_SUMMARY[mood], roundi(o[1] * 100.0)]
		else:
			line += "\n[color=#b0aab8]Reação: ??? (não sabes que tipo de homem ele é)[/color]"
		if heard > 0:
			line += "\n[i]Já lhe disseste isto %d×. Resulta cada vez menos.[/i]" % heard
		_item(Bocas.NAMES[c], "boca", c, line)
	_item("◂ Voltar", "back", 0, "Voltar às ações.")
	show_menu(true)
	_focus_first()


func _focus_first() -> void:
	for c in menu_box.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			desc_label.text = _descs[c]
			return


func focused_button() -> Button:
	var f := get_viewport().gui_get_focus_owner()
	return f if f is Button and f.get_parent() == menu_box else null


# ---------------------------------------------------------------------------
# speech bubbles + floating text (screen space, follow 3D anchors)
# ---------------------------------------------------------------------------
func bubble(key: String, speaker: String, text: String, screen_pos: Vector2, tint := Color(1, 1, 1)) -> void:
	clear_bubble(key)
	var p := PanelContainer.new()
	var sb := _box(Color(0.98, 0.96, 0.9, 0.97), Color(0.15, 0.1, 0.12), 3)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	if speaker != "":
		v.add_child(_plain(speaker, 15, Color(0.6, 0.15, 0.15) * tint))
	var body := _plain(text, 19, Color(0.12, 0.08, 0.1))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 300
	v.add_child(body)
	p.add_child(_margin(v, 12, 8))
	root.add_child(p)
	p.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var sz := p.size
	var pos := screen_pos - Vector2(sz.x * 0.5, sz.y)
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 20, vp.x - sz.x - 20)
	pos.y = clampf(pos.y, 222, vp.y - sz.y - 150)
	p.position = pos
	p.scale = Vector2(0.85, 0.85)
	p.pivot_offset = Vector2(sz.x * 0.5, sz.y)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.12)
	_bubbles[key] = p


func _plain(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


func clear_bubble(key: String) -> void:
	if _bubbles.has(key) and is_instance_valid(_bubbles[key]):
		_bubbles[key].queue_free()
	_bubbles.erase(key)


func clear_bubbles() -> void:
	for k in _bubbles.keys():
		clear_bubble(k)


func float_text(text: String, screen_pos: Vector2, c: Color, size := 30, rise := 60.0) -> void:
	var l := _label(text, size, c)
	l.add_theme_constant_override("outline_size", 10)
	root.add_child(l)
	l.reset_size()
	l.position = screen_pos - l.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - rise, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)


func show_banner(t: String, c: Color, hold := 1.2) -> void:
	banner.text = t
	banner.add_theme_color_override("font_color", c)
	banner.scale = Vector2(1.3, 1.3)
	banner.pivot_offset = Vector2(500, 50)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	if hold > 0.0:
		tw.chain().tween_interval(hold)
		tw.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
