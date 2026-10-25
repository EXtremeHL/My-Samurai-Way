class_name EndingScreen
extends CanvasLayer
## Ending card: a washi sheet over the darkened valley. [E] back to the title.

signal restart

var ending_id := ""
var _root: ColorRect
var _ready_for_input := false


func show_ending(id: String, s: GameState, speed := 1.0) -> void:
	ending_id = id
	layer = 20
	var e: Dictionary = Endings.ALL[id]
	var seen := Endings.record(id)
	_root = ColorRect.new()
	_root.color = Color(0.03, 0.02, 0.04, 0.0)     # the valley stays faintly visible behind
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var sheet := UiStyle.panel(56, 30)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.offset_left = -470
	sheet.offset_right = 470
	sheet.offset_top = -300
	sheet.offset_bottom = 300
	sheet.modulate.a = 0.0
	_root.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	sheet.add_child(box)
	box.add_child(_label("My Samurai Way", 18, UiStyle.INK_FAINT, true))
	var seal_row := CenterContainer.new()
	seal_row.add_child(UiStyle.seal_panel("FIM", 20))
	box.add_child(seal_row)
	box.add_child(_label(e.title, 44, UiStyle.VERMILION, true))
	var body := UiStyle.ink_rich(21)
	body.fit_content = true
	body.text = "[center]%s[/center]" % "\n\n".join(e.text)
	box.add_child(body)
	var rep := "Corvo %+d · Magistrado %+d · Vila %+d   —   %s" % [s.rep.corvo, s.rep.magistrado, s.rep.vila, s.clock_text()]
	box.add_child(_label(rep, 16, UiStyle.INK_SOFT, true))
	box.add_child(_label("Finais descobertos: %d de %d" % [seen.size(), Endings.ALL.size()], 18, UiStyle.INK, true))
	box.add_child(_label("[E] Voltar ao título", 18, UiStyle.VERMILION, true))
	var tw := create_tween()
	tw.tween_property(_root, "color:a", 0.78, 1.2 * speed)
	tw.tween_property(sheet, "modulate:a", 1.0, 1.0 * speed)
	await tw.finished
	_ready_for_input = true


func _label(t: String, size: int, c: Color, center: bool) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _unhandled_input(event: InputEvent) -> void:
	if _ready_for_input and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		restart.emit()
