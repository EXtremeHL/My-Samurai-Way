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
	get_tree().quit(0)
