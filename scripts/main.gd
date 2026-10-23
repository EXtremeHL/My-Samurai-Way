extends Node3D
## Entry scene: builds the valley, the player, NPCs, camera, HUD.
##
## Command-line hooks (after a bare `--`):
##   --look <dourado|neblina|noite>   lighting preset
##   --capture <dir>                  render every lighting preset to PNGs, quit
##   --shots <dir>                    render gameplay screenshots (walk/talk), quit
##   --playthrough                    run the integration test runner, quit

const CAM_OFFSET := Vector3(0.0, 8.4, 18.7)     # camera position relative to focus
const FOCUS_OFFSET := Vector3(0.0, 0.6, -4.9)   # focus point relative to player
const CAM_FOLLOW := 5.0

var village: Village
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D
var player: Player
var dialogue: DialogueBox
var npcs := {}
var talking_to: Npc = null
var _title: Label
var hint: Label
var stage: DuelStage
var anim_speed := 1.0           # tests shrink this to fast-forward duels
var duel_seed := -1             # fixed by tests; -1 = random
var last_duel_result := -1
var _pending_duel := ""
var _fade: ColorRect


func _ready() -> void:
	village = Village.new()
	add_child(village)
	village.build()

	sun = DirectionalLight3D.new()
	add_child(sun)
	var we := WorldEnvironment.new()
	env = Environment.new()
	we.environment = env
	add_child(we)

	for id in NpcData.TOWN:
		var n := Npc.new()
		village.add_child(n)
		n.setup(id, NpcData.TOWN[id])
		npcs[id] = n

	player = Player.new()
	player.name = "Player"
	player.position = NpcData.PLAYER_START
	village.add_child(player)
	for n in npcs.values():
		player.npcs.append(n)
	player.interact_requested.connect(_on_interact)

	cam = Camera3D.new()
	cam.fov = 34.0
	cam.attributes = Look.make_camera_attributes()
	add_child(cam)
	cam.position = _focus_point() + CAM_OFFSET
	cam.look_at(_focus_point(), Vector3.UP)
	cam.current = true

	_build_overlay()
	dialogue = DialogueBox.new()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.choice_made.connect(_on_choice)
	stage = DuelStage.new(self)
	add_child(stage)
	stage.finished.connect(_on_duel_finished)

	var args := OS.get_cmdline_user_args()
	var look := "dourado"
	var i := args.find("--look")
	if i >= 0 and i + 1 < args.size():
		look = args[i + 1]
	Look.apply(look, env, sun, village)

	i = args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])
		return
	i = args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		_shots(args[i + 1])
		return
	if args.has("--playthrough"):
		var runner: Node = load("res://tests/playthrough_runner.gd").new()
		add_child(runner)
		runner.run(self)
		return
	_show_title("Kurogane-juku", "Vale de Kurogane")


func _focus_point() -> Vector3:
	var p := player.position + FOCUS_OFFSET
	p.x = clampf(p.x, -9.0, 15.0)
	p.y = FOCUS_OFFSET.y
	return p


func _process(delta: float) -> void:
	if stage.active:
		hint.text = ""
		return
	var target := _focus_point() + CAM_OFFSET
	cam.position = cam.position.lerp(target, 1.0 - exp(-CAM_FOLLOW * delta))
	var f: Npc = player.focus
	hint.text = "[E]  Falar com %s" % f.display_name if f and not dialogue.open else ""


## Jump the camera to the player without easing (teleports, tests, shots).
func snap_camera() -> void:
	cam.position = _focus_point() + CAM_OFFSET


func _on_interact(n: Npc) -> void:
	talking_to = n
	player.frozen = true
	n.turn_to(player.position)
	player.face_dir(n.position - player.position)
	player.animate(false, 0.0)
	dialogue.start(n.lines())


func _on_dialogue_finished() -> void:
	if talking_to:
		talking_to.times_talked += 1
		talking_to.return_home()
	talking_to = null
	player.frozen = false
	if _pending_duel != "":
		var id := _pending_duel
		_pending_duel = ""
		start_duel(id)


func _on_choice(tag: String) -> void:
	if tag.begins_with("duel:"):
		_pending_duel = tag.substr(5)


# ---------------------------------------------------------------------------
# duels
# ---------------------------------------------------------------------------
func start_duel(id: String) -> void:
	var npc: Npc = npcs[id]
	player.frozen = true
	player.set_physics_process(false)
	npc.show_prompt(false)
	stage.seed_value = duel_seed if duel_seed >= 0 else randi()
	stage.start(id, npc, NpcData.TOWN[id].duel_spot)


func _on_duel_finished(result: int, id: String) -> void:
	last_duel_result = result
	var npc: Npc = npcs[id]
	if result == Duel.Result.WIN or result == Duel.Result.SURRENDER:
		npc.state = "vencido"
		var short_name: String = Foes.ALL[id].name.get_slice(",", 0)
		npc.display_name = short_name
		npc.home = NpcData.TOWN[id].get("beaten_pos", npc.home)
	# the foe walks back to his post
	var t := create_tween()
	t.tween_property(npc, "position", npc.home, 0.6 * anim_speed)
	await t.finished
	npc.return_home()
	if result == Duel.Result.LOSE:
		await _wake_at_teahouse()
	player.snap_to_ground()
	player.set_physics_process(true)
	player.frozen = false


func _wake_at_teahouse() -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.6 * anim_speed)
	await t.finished
	player.position = NpcData.WAKE_POS
	player.face_dir(Vector3.FORWARD)
	snap_camera()
	await get_tree().create_timer(0.5 * anim_speed).timeout
	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.8 * anim_speed)
	await t2.finished
	player.frozen = true
	dialogue.start(NpcData.WAKE_LINES)
	await dialogue.finished


# ---------------------------------------------------------------------------
# overlay: vignette + location title card
# ---------------------------------------------------------------------------
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vm
	layer.add_child(vignette)
	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 70
	_title.offset_left = -400
	_title.offset_right = 400
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.12))
	_title.add_theme_constant_override("outline_size", 10)
	_title.modulate.a = 0.0
	layer.add_child(_title)
	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -300
	hint.offset_right = 300
	hint.offset_top = -64
	hint.offset_bottom = -30
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	hint.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	hint.add_theme_constant_override("outline_size", 8)
	layer.add_child(hint)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	layer.add_child(_fade)
	add_child(layer)


func _show_title(place: String, sub: String) -> void:
	_title.text = "%s\n— %s —" % [place, sub]
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.0)
	tw.tween_interval(2.2)
	tw.tween_property(_title, "modulate:a", 0.0, 1.2)


# ---------------------------------------------------------------------------
# automation
# ---------------------------------------------------------------------------
func _save_shot(dir: String, file: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var path := abs_dir.path_join(file)
	get_viewport().get_texture().get_image().save_png(path)
	print("captured: ", path)


func _wait(frames: int) -> void:
	for _f in frames:
		await get_tree().process_frame


func _capture(dir: String) -> void:
	for v in Look.VARIANTS:
		Look.apply(v, env, sun, village)
		await _wait(40)
		_save_shot(dir, "look_%s.png" % v)
	get_tree().quit(0)


func _shots(dir: String) -> void:
	# 1. walking toward the tea house, captured mid-stride
	player.position = Vector3(-2.4, 0, 0.1)
	snap_camera()
	Input.action_press("move_left")
	await _wait(26)
	Input.action_release("move_left")
	player.set_physics_process(false)
	player.face_dir(Vector3.LEFT)
	player.walk_frame = 1
	player._apply_frame()
	await _wait(30)
	_save_shot(dir, "shot_walk.png")
	player.set_physics_process(true)
	# 2. next to Oyuki: the talk prompt, then the dialogue box
	player.position = Vector3(-7.3, 0, -0.75)
	player.face_dir(Vector3.FORWARD)
	snap_camera()
	await _wait(20)
	_save_shot(dir, "shot_prompt.png")
	_on_interact(npcs["oyuki"])
	await _wait(150)
	_save_shot(dir, "shot_dialogue.png")
	for _k in 6:
		dialogue.advance()
	await _wait(120)
	_save_shot(dir, "shot_dialogue_hero.png")
	# 3. on the bridge at night
	while dialogue.open:
		dialogue.advance()
	Look.apply("noite", env, sun, village)
	player.position = Vector3(12.5, 0, 0.2)
	player.snap_to_ground()
	player.face_dir(Vector3.RIGHT)
	snap_camera()
	await _wait(40)
	_save_shot(dir, "shot_bridge_night.png")
	# 4. a duel with Tetsu on the main street
	Look.apply("dourado", env, sun, village)
	duel_seed = 7
	player.position = Vector3(-4.9, 0, -0.6)
	snap_camera()
	await _wait(5)
	start_duel("tetsu")
	await stage.awaiting_input
	await _wait(20)
	_save_shot(dir, "shot_duel_menu.png")
	stage._on_picked("boca_menu", 0)
	await _wait(10)
	_save_shot(dir, "shot_duel_boca.png")
	stage.pick_boca(Bocas.Cat.INSULTO)
	await get_tree().create_timer(1.0).timeout
	_save_shot(dir, "shot_duel_boca_line.png")
	await get_tree().create_timer(1.9).timeout
	_save_shot(dir, "shot_duel_boca_reply.png")
	await stage.awaiting_input
	await _wait(10)
	_save_shot(dir, "shot_duel_after_boca.png")
	stage.pick(Duel.Act.HEAVY)
	await get_tree().create_timer(0.66).timeout
	_save_shot(dir, "shot_duel_strike.png")
	await stage.awaiting_input
	stage._on_picked("boca_menu", 0)
	await _wait(10)
	_save_shot(dir, "shot_duel_boca_known.png")
	get_tree().quit(0)
