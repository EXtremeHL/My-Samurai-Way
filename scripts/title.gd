extends Node
## Title screen (the project's main scene).
##
## It is deliberately light so it shows up at once, even in the browser. Right
## after it appears, the real game scene is built *underneath* it, paused and
## hidden, so the slow part of a web start (building the valley and compiling
## its shaders) happens while the player reads the title, not on a frozen
## black screen. "Começar" then just unpauses the game and fades the title out.
## That click also unlocks browser audio, which needs a user gesture.
##
## With command-line user args (tests, captures) it hands over to the game at
## once.

const GAME_SCENE := "res://scenes/main.tscn"
const GOLD := UiStyle.GOLD
const CREAM := UiStyle.CREAM

var game: Node = null
var ready_to_play := false
var _items: Array[Dictionary] = []      # {label, action}
var _sel := 0
var _menu_box: VBoxContainer
var _status: Label
var _layer: CanvasLayer
var _root: Control
var _leaving := false
var _confirm_new := false
var _testing := false                   # keep this node alive for the self-test


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := args.find("--title-shots")
	if not args.is_empty() and shot < 0:
		get_tree().change_scene_to_file.call_deferred(GAME_SCENE)
		return
	if shot >= 0:
		# self-test: a throwaway save on day 2 night, which "Continuar" must load
		SaveGame.path = "user://partida_teste_titulo.cfg"
		Endings.save_path = "user://finais_teste.cfg"
		var s := GameState.new()
		s.day = 2
		s.period_i = 2
		s.set_flag("salvou_oyuki")
		SaveGame.write(s, Vector3(1.5, 0, 0.6), Vector3.RIGHT)
	_build_ui()
	# let the title render first, then build the game under it
	await get_tree().process_frame
	await get_tree().process_frame
	_load_game()
	if shot >= 0 and shot + 1 < args.size():
		_self_test(args[shot + 1])


## --title-shots <dir>: title screenshots plus the hand-over, then quit.
func _self_test(dir: String) -> void:
	_testing = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var ok := true
	while not ready_to_play:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir.path_join("title.png"))
	var gp: Node = game.get("player")
	var p0: Vector3 = gp.global_position
	Input.action_press("move_right")          # the game must ignore input under the title
	for i in 20:
		await get_tree().physics_frame
	Input.action_release("move_right")
	ok = ok and gp.global_position.is_equal_approx(p0)
	print("check frozen under title: ", gp.global_position.is_equal_approx(p0))
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("after_start.png"))
	ok = ok and _leaving
	p0 = gp.global_position
	Input.action_press("move_right")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_right")
	var moved: bool = not gp.global_position.is_equal_approx(p0)
	print("check moves after start: ", moved)
	var music: String = GameAudio.inst.current_music if GameAudio.inst else ""
	print("check music: ", music)
	var gs: GameState = game.get("state")
	var resumed := gs.clock_text() == "Dia 2 · Noite" and gs.has("salvou_oyuki")
	print("check continue loaded the save: ", resumed, " (", gs.clock_text(), ")")
	print("check night music after continue: ", music == "town_night")
	ok = ok and moved and resumed and music == "town_night"
	SaveGame.erase()
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_root)

	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.02, 0.07, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_root.add_child(col)

	col.add_child(_label("My Samurai Way", 84, CREAM, 6))
	col.add_child(_label("Um ronin. Um vale dividido. Três dias para decidir.", 22, GOLD, 3))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)

	var sheet_row := CenterContainer.new()
	col.add_child(sheet_row)
	var sheet := UiStyle.panel(40, 18)
	sheet.custom_minimum_size.x = 520
	sheet_row.add_child(sheet)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	sheet.add_child(UiStyle.margin(_menu_box, 0, 8))
	var saved := SaveGame.summary()
	_items = []
	if saved != "":
		_items.append({"label": "Continuar — %s" % saved, "action": "continue"})
		_items.append({"label": "Novo jogo", "action": "new"})
	else:
		_items.append({"label": "Começar", "action": "new"})
	if OS.has_feature("web"):
		_items.append({"label": "Ecrã inteiro", "action": "fullscreen"})
	else:
		_items.append({"label": "Sair", "action": "quit"})
	for i in _items.size():
		var l := UiStyle.ink_label("", 28)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_hover.bind(i))
		l.gui_input.connect(_item_input.bind(i))
		_menu_box.add_child(l)
		_items[i]["node"] = l

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap2)
	_status = _label("A preparar o vale…", 21, CREAM, 6)
	col.add_child(_status)

	var found := Endings.discovered().size()
	var foot := _label("Finais descobertos: %d / %d     ·     WASD andar · E falar · Tab diário" \
			% [found, Endings.ALL.size()], 17, Color(0.93, 0.88, 0.8), 5)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -44
	foot.offset_bottom = -16
	_root.add_child(foot)
	_refresh_menu()


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.05))
	l.add_theme_constant_override("outline_size", outline)
	return l


func _refresh_menu() -> void:
	for i in _items.size():
		var l: Label = _items[i]["node"]
		var on := i == _sel
		var txt: String = _items[i]["label"]
		if i == 0 and not ready_to_play:
			txt += "  (a preparar…)"
		if _items[i]["action"] == "new" and _confirm_new:
			txt = "Novo jogo? A partida gravada será apagada — confirma"
		l.text = UiStyle.menu_text(txt, on)
		l.add_theme_color_override("font_color", UiStyle.VERMILION if on else UiStyle.INK)


# ---------------------------------------------------------------------------
# loading the game underneath
# ---------------------------------------------------------------------------
func _load_game() -> void:
	var packed: PackedScene = load(GAME_SCENE)
	game = packed.instantiate()
	game.process_mode = Node.PROCESS_MODE_DISABLED   # frozen until "Começar"
	get_tree().root.add_child.call_deferred(game)
	# a few rendered frames so the 3D shaders get compiled behind the title
	for i in 6:
		await get_tree().process_frame
	ready_to_play = true
	_status.text = "Clica ou carrega em Enter para começar"
	var t := create_tween().set_loops()
	t.tween_property(_status, "modulate:a", 0.35, 0.9)
	t.tween_property(_status, "modulate:a", 1.0, 0.9)
	_refresh_menu()


# ---------------------------------------------------------------------------
# input
# ---------------------------------------------------------------------------
func _unhandled_input(e: InputEvent) -> void:
	if _leaving or _items.is_empty():
		return
	if e.is_action_pressed("move_up") or e.is_action_pressed("move_down"):
		_sel = (_sel + (1 if e.is_action_pressed("move_down") else -1) + _items.size()) % _items.size()
		GameAudio.sfx("ui_move")
		_refresh_menu()
	elif e.is_action_pressed("interact"):
		_activate(_sel)
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_activate(0)     # a click anywhere: the first option (continue, or start)
	else:
		return
	get_viewport().set_input_as_handled()


func _hover(i: int) -> void:
	if i != _sel and not _leaving:
		_sel = i
		_refresh_menu()


func _item_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_activate(i)


func _activate(i: int) -> void:
	var action: String = _items[i]["action"]
	if action != "new" and _confirm_new:
		_confirm_new = false
		_refresh_menu()
	match action:
		"continue":
			start(true)
		"new":
			if SaveGame.exists() and not _confirm_new:
				_confirm_new = true
				_sel = i
				GameAudio.sfx("ui_back")
				_refresh_menu()
				return
			SaveGame.erase()
			start(false)
		"fullscreen":
			GameAudio.sfx("ui_select")
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full \
					else DisplayServer.WINDOW_MODE_FULLSCREEN)
		"quit":
			get_tree().quit()


## Unpauses the game underneath (loading the save if resuming) and fades the
## title away.
func start(resume := false) -> void:
	if _leaving:
		return
	if not ready_to_play:
		_status.text = "Quase pronto…"
		while not ready_to_play:
			await get_tree().process_frame
	_leaving = true
	GameAudio.sfx("ui_select")
	game.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().current_scene = game       # so later scene changes free it
	game.begin(resume)
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.8)
	if not _testing:
		t.tween_callback(queue_free)
