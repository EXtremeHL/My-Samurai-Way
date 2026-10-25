class_name DuelUI
extends CanvasLayer
## Duel HUD: fighter panels, intent banner, action menu, description box,
## speech bubbles and floating combat text. Pure presentation - DuelStage
## tells it what to show and listens for `picked`.

signal picked(kind: String, value: int)   # kind: "act" | "boca" | "back"

# over-the-scene colours (floating numbers, banners); paper text uses UiStyle
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
var _building := false          # suppresses focus sounds while a menu is rebuilt
var _bubbles := {}


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hero_panel = _fighter_panel(false)
	foe_panel = _fighter_panel(true)

	intent_panel = PanelContainer.new()
	intent_panel.add_theme_stylebox_override("panel", UiStyle.seal(22, 8))
	intent_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	intent_panel.offset_left = -330
	intent_panel.offset_right = 330
	intent_panel.offset_top = 176
	root.add_child(intent_panel)
	intent_label = UiStyle.ink_label("", 21, UiStyle.SEAL_TEXT)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_panel.add_child(intent_label)

	menu_panel = UiStyle.panel(10, 8)
	menu_panel.anchor_top = 1.0
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_left = 40
	menu_panel.offset_right = 340
	menu_panel.offset_bottom = -30
	menu_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(menu_panel)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 2)
	menu_panel.add_child(UiStyle.margin(menu_box, 0, 8))

	desc_panel = UiStyle.panel(22, 12)
	desc_panel.anchor_left = 0.0
	desc_panel.anchor_right = 1.0
	desc_panel.anchor_top = 1.0
	desc_panel.anchor_bottom = 1.0
	desc_panel.offset_left = 350
	desc_panel.offset_right = -40
	desc_panel.offset_top = -158
	desc_panel.offset_bottom = -30
	root.add_child(desc_panel)
	desc_label = UiStyle.ink_rich(20)
	desc_panel.add_child(UiStyle.margin(desc_label, 0, 8))

	banner = UiStyle.scene_label("", 66, UiStyle.CREAM, 16)
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
func _fighter_panel(right: bool) -> Dictionary:
	var p := UiStyle.panel(16, 8)
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
	p.add_child(UiStyle.margin(v, 0, 6))
	var top := HBoxContainer.new()
	var name_l := UiStyle.ink_label("", 23)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mood_l := UiStyle.ink_label("", 17, UiStyle.RISK_INK)
	top.add_child(name_l)
	top.add_child(mood_l)
	v.add_child(top)
	var sub := UiStyle.ink_label("", 16, UiStyle.INK_SOFT)
	v.add_child(sub)
	var hp_row := HBoxContainer.new()
	var hp := UiStyle.bar(UiStyle.FILL_HP, 230, 12)
	var hp_t := UiStyle.ink_label("", 15, UiStyle.INK_SOFT)
	hp_row.add_child(hp)
	hp_row.add_child(hp_t)
	v.add_child(hp_row)
	var ki_row := HBoxContainer.new()
	var ki := UiStyle.bar(UiStyle.FILL_KI, 230, 8)
	var ki_t := UiStyle.ink_label("", 15, UiStyle.FILL_KI)
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
	p.mood.add_theme_color_override("font_color", mood_color_ink(f.mood, not is_hero))


static func mood_color(m: int, on_foe: bool) -> Color:
	if m in Personality.GOOD_FOR_SPEAKER:
		return GOOD if on_foe else BAD
	if m in Personality.RISKY:
		return RISK
	return BAD if on_foe else GOOD


## The same judgement, in colours that read on washi paper.
static func mood_color_ink(m: int, on_foe: bool) -> Color:
	if m in Personality.GOOD_FOR_SPEAKER:
		return UiStyle.GOOD_INK if on_foe else UiStyle.BAD_INK
	if m in Personality.RISKY:
		return UiStyle.RISK_INK
	return UiStyle.BAD_INK if on_foe else UiStyle.GOOD_INK


func set_intent(t: String, flash := false) -> void:
	intent_label.text = t
	if flash:
		intent_panel.modulate = Color(1.6, 1.35, 1.2)
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
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", UiStyle.INK)
	b.add_theme_color_override("font_focus_color", UiStyle.VERMILION)
	b.add_theme_color_override("font_hover_color", UiStyle.VERMILION)
	b.add_theme_color_override("font_pressed_color", UiStyle.VERMILION)
	b.add_theme_color_override("font_disabled_color", Color(UiStyle.INK_FAINT, 0.6))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 14
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(UiStyle.VERMILION, 0.1)
	focus.border_color = UiStyle.VERMILION
	focus.border_width_left = 3
	focus.content_margin_left = 14
	for s in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("hover", focus)
	b.pressed.connect(func():
		GameAudio.sfx("ui_back" if kind == "back" else "ui_select", -4.0)
		picked.emit(kind, value))
	b.focus_entered.connect(func():
		desc_label.text = desc
		if not _building:
			GameAudio.sfx("ui_move", -8.0))
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
			var col := mood_color_ink(mood, true).to_html(false)
			if mood == Personality.Mood.NONE:
				line += "\n[color=#%s]%s[/color]" % [UiStyle.INK_SOFT.to_html(false), Personality.MOOD_SUMMARY[mood]]
			else:
				line += "\n[color=#%s]%s[/color]  (%d%%)" % [col, Personality.MOOD_SUMMARY[mood], roundi(o[1] * 100.0)]
		else:
			line += "\n[color=#%s]Reação: ??? (não sabes que tipo de homem ele é)[/color]" % UiStyle.INK_SOFT.to_html(false)
		if heard > 0:
			line += "\n[i]Já lhe disseste isto %d×. Resulta cada vez menos.[/i]" % heard
		_item(Bocas.NAMES[c], "boca", c, line)
	_item("◂ Voltar", "back", 0, "Voltar às ações.")
	show_menu(true)
	_focus_first()


func _focus_first() -> void:
	for c in menu_box.get_children():
		if c is Button and not c.disabled:
			_building = true
			c.grab_focus()
			_building = false
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
	var p := UiStyle.panel(14, 6)
	var v := VBoxContainer.new()
	if speaker != "":
		v.add_child(UiStyle.ink_label(speaker, 16, UiStyle.VERMILION * tint))
	var body := UiStyle.ink_label(text, 20)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 300
	v.add_child(body)
	p.add_child(UiStyle.margin(v, 0, 4))
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


func clear_bubble(key: String) -> void:
	if _bubbles.has(key) and is_instance_valid(_bubbles[key]):
		_bubbles[key].queue_free()
	_bubbles.erase(key)


func clear_bubbles() -> void:
	for k in _bubbles.keys():
		clear_bubble(k)


func float_text(text: String, screen_pos: Vector2, c: Color, size := 30, rise := 60.0) -> void:
	var l := UiStyle.scene_label(text, size, c, 10)
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
