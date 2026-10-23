class_name EndingScreen
extends CanvasLayer
## Full-screen ending card. [E] starts a new journey.

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
	_root.color = Color(0.02, 0.02, 0.04, 0.0)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -440
	box.offset_right = 440
	box.offset_top = -270
	box.offset_bottom = 270
	box.add_theme_constant_override("separation", 14)
	box.modulate.a = 0.0
	_root.add_child(box)
	box.add_child(_label("My Samurai Way  ·  FIM", 20, Color(0.75, 0.65, 0.5), true))
	box.add_child(_label(e.title, 44, Color(1.0, 0.9, 0.7), true))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.add_theme_font_size_override("normal_font_size", 20)
	body.add_theme_color_override("default_color", Color(0.92, 0.9, 0.85))
	body.text = "[center]%s[/center]" % "\n\n".join(e.text)
	box.add_child(body)
	var rep := "Corvo %+d · Magistrado %+d · Vila %+d   —   %s" % [s.rep.corvo, s.rep.magistrado, s.rep.vila, s.clock_text()]
	box.add_child(_label(rep, 16, Color(0.65, 0.62, 0.72), true))
	box.add_child(_label("Finais descobertos: %d de %d" % [seen.size(), Endings.ALL.size()], 18, Color(0.85, 0.75, 0.55), true))
	box.add_child(_label("[E] Começar uma nova viagem", 18, Color(0.95, 0.9, 0.8), true))
	var tw := create_tween()
	tw.tween_property(_root, "color:a", 1.0, 1.2 * speed)
	tw.tween_property(box, "modulate:a", 1.0, 1.0 * speed)
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
