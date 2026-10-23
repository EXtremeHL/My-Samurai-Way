class_name DialogueBox
extends CanvasLayer
## Bottom-of-screen dialogue window with a name tag and typewriter text.
## interact: first press finishes the line, second press advances.

signal finished
signal choice_made(tag: String)

const CPS := 48.0              # characters per second

var lines: Array = []
var index := 0
var open := false
var _shown := 0.0
var _panel: PanelContainer
var _name_tag: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _arrow: Label
var _blink := 0.0
var choosing := false
var choice_index := 0
var _choice_tags: Array = []
var _choice_panel: PanelContainer
var _choice_box: VBoxContainer


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 110
	_panel.offset_right = -110
	_panel.offset_top = -178
	_panel.offset_bottom = -30
	_panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.07, 0.14, 0.9), Color(0.85, 0.7, 0.4), 3))
	root.add_child(_panel)

	var margin := MarginContainer.new()
	for s in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + s, 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 23)
	_text.add_theme_color_override("default_color", Color(0.96, 0.93, 0.86))
	_text.add_theme_constant_override("line_separation", 6)
	margin.add_child(_text)

	_name_tag = PanelContainer.new()
	_name_tag.add_theme_stylebox_override("panel", _box(Color(0.5, 0.12, 0.12, 0.95), Color(0.85, 0.7, 0.4), 2))
	_name_tag.anchor_top = 1.0
	_name_tag.anchor_bottom = 1.0
	_name_tag.offset_left = 140
	_name_tag.offset_top = -196
	_name_tag.offset_bottom = -164
	_name_tag.grow_horizontal = Control.GROW_DIRECTION_END
	root.add_child(_name_tag)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.8))
	var nm := MarginContainer.new()
	for s in ["left", "right"]:
		nm.add_theme_constant_override("margin_" + s, 14)
	nm.add_child(_name_label)
	_name_tag.add_child(nm)

	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.add_theme_font_size_override("font_size", 18)
	_arrow.add_theme_color_override("font_color", Color(0.95, 0.78, 0.45))
	_arrow.anchor_left = 1.0
	_arrow.anchor_right = 1.0
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = -150
	_arrow.offset_top = -62
	root.add_child(_arrow)

	_choice_panel = PanelContainer.new()
	_choice_panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.07, 0.14, 0.95), Color(0.85, 0.7, 0.4), 3))
	_choice_panel.anchor_left = 1.0
	_choice_panel.anchor_right = 1.0
	_choice_panel.anchor_top = 1.0
	_choice_panel.anchor_bottom = 1.0
	_choice_panel.offset_left = -440
	_choice_panel.offset_right = -130
	_choice_panel.offset_bottom = -196
	_choice_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_choice_panel)
	var cm := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		cm.add_theme_constant_override("margin_" + s, 14)
	_choice_panel.add_child(cm)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	cm.add_child(_choice_box)
	_set_visible(false)


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


func _set_visible(on: bool) -> void:
	_panel.visible = on
	_name_tag.visible = on
	_arrow.visible = on
	_choice_panel.visible = on and choosing


func start(new_lines: Array) -> void:
	lines = new_lines
	index = 0
	open = true
	choosing = false
	_set_visible(true)
	_show_line()


func current_speaker() -> String:
	if not open or lines[index] is Dictionary:
		return ""
	return lines[index][0]


func line_complete() -> bool:
	return _text.visible_characters < 0 or _text.visible_characters >= _text.get_total_character_count()


func _show_line() -> void:
	if lines[index] is Dictionary:
		_start_choice(lines[index])
		return
	var speaker: String = lines[index][0]
	_name_tag.visible = speaker != ""
	_name_label.text = speaker
	var txt: String = lines[index][1]
	_text.text = "[i]%s[/i]" % txt if speaker == "" else txt
	_shown = 0.0
	_text.visible_characters = 0


## A choice entry: {"choice": [labels...], "tags": [tags...]}. The previous
## line stays on screen while the options are shown.
func _start_choice(entry: Dictionary) -> void:
	choosing = true
	choice_index = 0
	_choice_tags = entry.tags
	for c in _choice_box.get_children():
		c.queue_free()
	for i in entry.choice.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 22)
		_choice_box.add_child(l)
	_text.visible_characters = -1
	_choice_panel.visible = true
	_refresh_choice(entry.choice)


func _refresh_choice(labels: Array = []) -> void:
	var kids := _choice_box.get_children().filter(func(n): return not n.is_queued_for_deletion())
	for i in kids.size():
		var l: Label = kids[i]
		if not labels.is_empty():
			l.set_meta("label", labels[i])
		var sel := i == choice_index
		l.text = ("▶ " if sel else "   ") + str(l.get_meta("label"))
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if sel else Color(0.85, 0.82, 0.76))


func choose(i: int) -> void:
	## Confirms option i (also used by tests).
	if not choosing:
		return
	choosing = false
	_choice_panel.visible = false
	var tag: String = _choice_tags[i]
	open = false
	_set_visible(false)
	choice_made.emit(tag)
	finished.emit()


func _process(delta: float) -> void:
	if not open or choosing:
		_arrow.modulate.a = 0.0
		return
	if not line_complete():
		_shown += delta * CPS
		_text.visible_characters = int(_shown)
		_arrow.modulate.a = 0.0
	else:
		_text.visible_characters = -1
		_blink += delta
		_arrow.modulate.a = 0.5 + 0.5 * sin(_blink * 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if not open:
		return
	if choosing:
		var n := _choice_tags.size()
		if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
			choice_index = (choice_index - 1 + n) % n
			_refresh_choice()
		elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
			choice_index = (choice_index + 1) % n
			_refresh_choice()
		elif event.is_action_pressed("interact"):
			choose(choice_index)
		elif event.is_action_pressed("cancel"):
			choose(n - 1)          # cancel = the last, safe option
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		advance()


func advance() -> void:
	if choosing:
		return
	if not line_complete():
		_text.visible_characters = -1
		return
	index += 1
	if index >= lines.size():
		open = false
		_set_visible(false)
		finished.emit()
	else:
		_show_line()
