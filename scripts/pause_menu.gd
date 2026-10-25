class_name PauseMenu
extends CanvasLayer
## Esc while exploring: continue, save, back to the title. Pauses the tree.

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
	dim.color = Color(0.03, 0.02, 0.05, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var sheet := UiStyle.panel(48, 26)
	sheet.set_anchors_preset(Control.PRESET_CENTER)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(sheet)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	sheet.add_child(col)
	var seal_row := CenterContainer.new()
	seal_row.add_child(UiStyle.seal_panel("Pausa", 24))
	col.add_child(seal_row)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)
	for i in ITEMS.size():
		var l := _label("", 28, UiStyle.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(func(): _sel = i; _refresh())
		l.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_activate(i))
		col.add_child(l)
		_labels.append(l)
	_note = _label("A partida também é gravada sozinha a cada conversa e a cada parte do dia.", 16,
			UiStyle.INK_SOFT)
	col.add_child(_note)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _refresh() -> void:
	for i in _labels.size():
		var on := i == _sel
		_labels[i].text = UiStyle.menu_text(ITEMS[i][0], on)
		_labels[i].add_theme_color_override("font_color", UiStyle.VERMILION if on else UiStyle.INK)


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
