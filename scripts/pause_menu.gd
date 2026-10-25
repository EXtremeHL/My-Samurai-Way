class_name PauseMenu
extends CanvasLayer
## Esc while exploring: continue, save, back to the title. Pauses the tree.

const GOLD := Color(0.95, 0.78, 0.5)
const CREAM := Color(1.0, 0.94, 0.84)
const ITEMS := [["Continuar", "resume"], ["Gravar partida", "save"], ["Voltar ao título", "title"]]

var game: Node
var is_open := false
var _sel := 0
var _labels: Array[Label] = []
var _note: Label
var _root: Control


func _init(g: Node) -> void:
	game = g
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	_root.add_child(col)
	col.add_child(_label("Pausa", 44, CREAM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap)
	for i in ITEMS.size():
		var l := _label("", 28, CREAM)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(func(): _sel = i; _refresh())
		l.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_activate(i))
		col.add_child(l)
		_labels.append(l)
	_note = _label("A partida também é gravada sozinha a cada conversa e a cada parte do dia.", 16,
			Color(0.82, 0.78, 0.72))
	col.add_child(_note)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.05))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _refresh() -> void:
	for i in _labels.size():
		var on := i == _sel
		_labels[i].text = ("▶  %s  ◀" % ITEMS[i][0]) if on else ITEMS[i][0]
		_labels[i].add_theme_color_override("font_color", GOLD if on else CREAM)


func open() -> void:
	is_open = true
	_sel = 0
	_note.text = "A partida também é gravada sozinha a cada conversa e a cada parte do dia."
	_refresh()
	_root.visible = true
	get_tree().paused = true
	GameAudio.sfx("page", -4.0)


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(e: InputEvent) -> void:
	if not is_open:
		return
	if e.is_action_pressed("cancel"):
		close()
	elif e.is_action_pressed("move_up") or e.is_action_pressed("move_down"):
		_sel = (_sel + (1 if e.is_action_pressed("move_down") else -1) + ITEMS.size()) % ITEMS.size()
		GameAudio.sfx("ui_move")
		_refresh()
	elif e.is_action_pressed("interact"):
		_activate(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


func _activate(i: int) -> void:
	GameAudio.sfx("ui_select")
	match ITEMS[i][1]:
		"resume":
			close()
		"save":
			var ok := SaveGame.write(game.state, game.player.position, game.player.facing_vector())
			_note.text = "✓ Partida gravada — %s" % game.state.clock_text() if ok \
					else "Não foi possível gravar a partida."
		"title":
			game.autosave_now()
			close()
			game.back_to_title()
