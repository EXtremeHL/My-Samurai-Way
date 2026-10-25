extends Node3D
## Entry scene: builds the valley and runs the story - the clock, who is
## where, conversations, duels and endings.
##
## Command-line hooks (after a bare `--`):
##   --look <dourado|neblina|noite>   lighting preset (otherwise follows the clock)
##   --capture <dir>                  render every lighting preset to PNGs, quit
##   --shots <dir>                    render gameplay screenshots, quit
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
var stage: DuelStage
var hud: StoryHUD
var ending_screen: EndingScreen
var state := GameState.new()
var npcs := {}
var talking_to: Npc = null
var current_entry: Dictionary = {}
var anim_speed := 1.0           # tests shrink this to fast-forward
var duel_seed := -1             # fixed by tests; -1 = random
var last_duel_result := -1
var ended_with := ""
var _pending: Array = []        # story commands collected during a conversation
var _title: Label
var hint: Label
var _fade: ColorRect
var audio: GameAudio
var _saved: Label
var pause_menu: PauseMenu


func _ready() -> void:
	audio = GameAudio.new()
	audio.name = "Audio"
	audio.process_mode = Node.PROCESS_MODE_ALWAYS   # keeps playing under the title screen
	add_child(audio)
	village = Village.new()
	add_child(village)
	village.build()

	sun = DirectionalLight3D.new()
	add_child(sun)
	var we := WorldEnvironment.new()
	env = Environment.new()
	we.environment = env
	add_child(we)

	for id in Story.ids():
		var n := Npc.new()
		village.add_child(n)
		n.setup(id, Story.char_data(id))
		npcs[id] = n

	player = Player.new()
	player.name = "Player"
	player.position = StoryData.PLAYER_START
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
	hud = StoryHUD.new()
	add_child(hud)
	dialogue = DialogueBox.new()
	dialogue.portraits = Story.portrait_table()
	add_child(dialogue)
	dialogue.finished.connect(_on_dialogue_finished)
	dialogue.choice_made.connect(_on_choice)
	stage = DuelStage.new(self)
	add_child(stage)
	stage.finished.connect(_on_duel_finished)
	pause_menu = PauseMenu.new(self)
	add_child(pause_menu)

	var args := OS.get_cmdline_user_args()
	if args.has("--playthrough") or args.has("--shots") or args.has("--promo") or args.has("--duelfx") or args.has("--night"):
		Endings.save_path = "user://finais_teste.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Endings.save_path))
		SaveGame.path = "user://partida_teste.cfg"
		SaveGame.erase()
	refresh_world()
	var i := args.find("--look")
	if i >= 0 and i + 1 < args.size():
		Look.apply(args[i + 1], env, sun, village)

	i = args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])
		return
	i = args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		_shots(args[i + 1])
		return
	i = args.find("--night")
	if i >= 0 and i + 1 < args.size():
		_night(args[i + 1])
		return
	i = args.find("--duelfx")
	if i >= 0 and i + 1 < args.size():
		_duelfx(args[i + 1])
		return
	i = args.find("--promo")
	if i >= 0 and i + 1 < args.size():
		_promo(args[i + 1])
		return
	if args.has("--playthrough"):
		var script: GDScript = load("res://tests/playthrough_runner.gd")
		if script == null or not script.can_instantiate():
			print("RESULT: FAIL (playthrough runner failed to compile)")
			get_tree().quit(1)
			return
		var runner: Node = script.new()
		add_child(runner)
		runner.run(self)
		return
	if get_tree().current_scene == self:
		begin(false)                    # launched directly, without the title screen


## Called by the title screen when the player starts: a new run or the saved one.
func begin(resume: bool) -> void:
	if resume:
		load_save()
	_show_title("My Samurai Way", "Kurogane-juku · %s" % state.clock_text())


## Restores the saved run into this scene. Returns false if there is none.
func load_save() -> bool:
	var d := SaveGame.read()
	if d.is_empty() or not state.from_dict(d.state):
		return false
	player.position = d.pos
	player.face_dir(d.facing)
	player.snap_to_ground()
	refresh_world()
	snap_camera()
	return true


## Saves when the hero is free to walk (never mid-conversation or mid-duel).
func autosave() -> void:
	if ended_with != "" or stage.active or dialogue.open:
		return
	if SaveGame.write(state, player.position, player.facing_vector()):
		_flash_saved()


func autosave_now() -> void:
	if ended_with == "":
		SaveGame.write(state, player.position, player.facing_vector())


func _flash_saved() -> void:
	_saved.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(_saved, "modulate:a", 0.0, 0.8)


# ---------------------------------------------------------------------------
# world <- state
# ---------------------------------------------------------------------------
## Lighting, who stands where, names and HUD, all derived from the state.
func refresh_world() -> void:
	Look.apply(state.look(), env, sun, village)
	for id in npcs:
		var n: Npc = npcs[id]
		if stage.active and (n == stage.foe):
			continue
		n.place(Story.present(id, state))
		n.display_name = Story.display_name(id, state)
	hud.refresh(state)
	update_music()


## Music + ambience follow the clock (the duel and the ending set their own).
func update_music() -> void:
	if stage.active or ended_with != "":
		return
	var night := state.period() == "noite"
	GameAudio.music("town_night" if night else "town_day")
	GameAudio.ambience("amb_night" if night else "amb_day")


func _focus_point() -> Vector3:
	var p := player.position + FOCUS_OFFSET
	p.x = clampf(p.x, -9.0, 15.0)
	p.y = FOCUS_OFFSET.y
	return p


func _process(delta: float) -> void:
	hud.set_explore_visible(not stage.active and ended_with == "")
	if stage.active:
		hint.text = ""
		return
	var target := _focus_point() + CAM_OFFSET
	cam.position = cam.position.lerp(target, 1.0 - exp(-CAM_FOLLOW * delta))
	var f: Npc = player.focus
	if f and not dialogue.open and not player.frozen:
		hint.text = "[E]  %s %s" % ["Ver" if f.is_spot() else "Falar com", f.display_name]
	else:
		hint.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel") and can_pause():
		get_viewport().set_input_as_handled()
		pause_menu.open()
		return
	if event.is_action_pressed("journal") and not dialogue.open and not stage.active and ended_with == "":
		get_viewport().set_input_as_handled()
		hud.toggle_journal(state)
		player.frozen = hud.journal_open
		GameAudio.sfx("page", -4.0, 0.05)


## Leaves for the title screen (the run is saved first if it is still going).
func back_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
	if get_tree().current_scene != self:
		queue_free()


func can_pause() -> bool:
	return not dialogue.open and not stage.active and ended_with == "" \
			and not hud.journal_open and not player.frozen


## Jump the camera to the player without easing (teleports, tests, shots).
func snap_camera() -> void:
	cam.position = _focus_point() + CAM_OFFSET


# ---------------------------------------------------------------------------
# conversations
# ---------------------------------------------------------------------------
func _on_interact(n: Npc) -> void:
	var e := Story.pick(n.npc_id, state)
	if e.is_empty():
		return
	open_entry(e, n)


func open_entry(e: Dictionary, n: Npc) -> void:
	talking_to = n
	current_entry = e
	state.set_flag("seen_" + e.id)
	player.frozen = true
	if n:
		n.turn_to(player.position)
		if not n.is_spot():
			player.face_dir(n.position - player.position)
	player.animate(false, 0.0)
	dialogue.start(e.lines)


func _on_choice(tag: String) -> void:
	_pending.append_array(state.apply(tag))


func _on_dialogue_finished() -> void:
	if current_entry.is_empty():
		return                          # a system dialogue; its caller handles it
	var e := current_entry
	current_entry = {}
	_pending.append_array(state.apply(e.get("after", "")))
	if talking_to:
		talking_to.return_home()
	await run_commands(e.get("cost", GameState.COST_TALK))


## Carries out what the last conversation set in motion, then charges time.
func run_commands(cost: int) -> void:
	var cmds := _pending
	_pending = []
	var duel_id := ""
	var chain := ""
	var rest := false
	for c in cmds:
		match c[0]:
			"end":
				await _end(c[1])
				return
			"duel":
				duel_id = c[1]
			"chain":
				chain = c[1]
			"rest":
				rest = true
			"time":
				cost += int(c[1])
	if chain != "":
		open_entry(Story.entry(chain), talking_to)
		return
	if duel_id != "":
		state.spend(cost)
		talking_to = null
		start_duel(duel_id)
		return
	talking_to = null
	if rest:
		state.heal(1.0)
		await advance_time(true)
		return
	await spend_time(cost)


func spend_time(cost: int) -> void:
	var over := state.spend(cost)
	refresh_world()
	if over:
		await advance_time(false)
	else:
		player.frozen = false
		autosave()


## Next part of the day: fade, title card, new light, people move.
func advance_time(rested: bool) -> void:
	player.frozen = true
	if not state.advance_period():
		await _end("time")
		return
	if not rested:
		state.heal(0.3)
	GameAudio.sfx("bell", -3.0)
	await _fade_to(1.0, 0.6)
	refresh_world()
	snap_camera()
	hud.show_card("Dia %d\n%s" % [state.day, state.period_name()], 0.9 * anim_speed)
	await get_tree().create_timer(1.2 * anim_speed).timeout
	await _fade_to(0.0, 0.8)
	player.frozen = false
	autosave()


func _fade_to(a: float, secs: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", a, secs * anim_speed)
	await t.finished


# ---------------------------------------------------------------------------
# duels
# ---------------------------------------------------------------------------
func start_duel(id: String) -> void:
	var npc: Npc = npcs[id]
	player.frozen = true
	player.set_physics_process(false)
	npc.show_prompt(false)
	stage.seed_value = duel_seed if duel_seed >= 0 else randi()
	stage.start(id, npc, StoryData.CHARS[id].duel_spot, state.make_hero(), state.blade_name())


func _on_duel_finished(result: int, id: String) -> void:
	last_duel_result = result
	var f: Dictionary = Foes.ALL[id]
	var npc: Npc = npcs[id]
	state.hero_hp = maxi(1, stage.duel.hero.hp)
	var cmds: Array = []
	match result:
		Duel.Result.WIN:
			cmds.append_array(state.apply(f.on_win))
			player.frozen = true
			var short_name: String = f.name.get_slice(",", 0)
			dialogue.start([
				["", "%s está de joelhos, à tua mercê." % short_name],
				{"choice": ["Poupá-lo", "Acabar com ele"], "tags": [f.on_spare, f.on_kill]},
			])
			await dialogue.finished
			cmds.append_array(_pending)
			_pending = []
		Duel.Result.SURRENDER:
			cmds.append_array(state.apply(f.on_win))
			cmds.append_array(state.apply(f.on_spare))
		Duel.Result.LOSE:
			cmds.append_array(state.apply(f.on_lose))
	for c in cmds:
		if c[0] == "end":
			await _end(c[1])
			return
	var ev := Endings.on_event(state)
	if ev != "":
		await _end(ev)
		return
	if Story.present(id, state) == null:
		# killed, or fled the valley: gone
		var t := create_tween()
		t.tween_property(npc, "scale", Vector3(1, 0.01, 1), 0.4 * anim_speed)
		await t.finished
		npc.scale = Vector3.ONE
	else:
		var t := create_tween()
		t.tween_property(npc, "position", npc.home, 0.6 * anim_speed)
		await t.finished
	player.snap_to_ground()
	player.set_physics_process(true)
	update_music()
	if result == Duel.Result.LOSE:
		await _wake_at_teahouse()
		return
	await spend_time(GameState.COST_DUEL)


func _wake_at_teahouse() -> void:
	player.frozen = true
	await _fade_to(1.0, 0.6)
	player.position = StoryData.WAKE_POS
	player.face_dir(Vector3.FORWARD)
	state.hero_hp = roundi(state.hero_max_hp() * 0.5)
	var more := state.advance_period()      # out cold for hours
	if not more:
		await _end("time")
		return
	refresh_world()
	snap_camera()
	await get_tree().create_timer(0.5 * anim_speed).timeout
	await _fade_to(0.0, 0.8)
	dialogue.start(StoryData.WAKE_LINES)
	await dialogue.finished
	player.frozen = false
	autosave()


# ---------------------------------------------------------------------------
# endings
# ---------------------------------------------------------------------------
func _end(id: String) -> void:
	if id == "leave" or id == "time":
		id = Endings.evaluate(state, id)
	ended_with = id
	state.ending = id
	SaveGame.erase()                    # the run is over; endings are kept apart
	GameAudio.music("ending", 2.0)
	GameAudio.ambience("", 3.0)
	GameAudio.sfx("ending_gong", -4.0)
	player.frozen = true
	player.set_physics_process(false)
	hint.text = ""
	if is_instance_valid(stage.ui):
		stage.ui.visible = false        # no duel panels behind the ending sheet
	hud.visible = false
	ending_screen = EndingScreen.new()
	add_child(ending_screen)
	ending_screen.restart.connect(back_to_title)
	await ending_screen.show_ending(id, state, anim_speed)


# ---------------------------------------------------------------------------
# overlay: vignette, title, hint, fade
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
	_saved = Label.new()
	_saved.text = "✓ Partida gravada"
	_saved.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_saved.offset_left = -260
	_saved.offset_right = -24
	_saved.offset_top = -52
	_saved.offset_bottom = -20
	_saved.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved.add_theme_font_size_override("font_size", 18)
	_saved.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	_saved.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	_saved.add_theme_constant_override("outline_size", 6)
	_saved.modulate.a = 0.0
	layer.add_child(_saved)
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


func _goto(day: int, period: String) -> void:
	while not (state.day == day and state.period() == period):
		state.advance_period()
	refresh_world()


func _shots(dir: String) -> void:
	# 1. day 1 afternoon: HUD + a conversation
	player.position = Vector3(-7.3, 0, -0.75)
	player.face_dir(Vector3.FORWARD)
	snap_camera()
	await _wait(20)
	_save_shot(dir, "shot_hud.png")
	_on_interact(npcs["oyuki"])
	await _wait(150)
	_save_shot(dir, "shot_dialogue.png")
	while dialogue.open:
		dialogue.advance()
	await _wait(5)
	hud.toggle_journal(state)
	state.set_flag("conhece_tetsu")
	state.set_flag("quer_aco")
	state.add_rep("vila", 15)
	state.add_rep("corvo", -10)
	hud.refresh(state)
	await _wait(10)
	_save_shot(dir, "shot_journal.png")
	hud.toggle_journal(state)
	pause_menu.open()
	await _wait(10)
	_save_shot(dir, "shot_pause.png")
	pause_menu.close()
	_flash_saved()
	await _wait(3)
	_save_shot(dir, "shot_saved.png")
	# 2. night: the Corvo thug harassing Oyuki
	_goto(1, "noite")
	player.position = Vector3(-6.4, 0, 0.4)
	player.face_dir(Vector3.FORWARD)
	snap_camera()
	await _wait(40)
	_save_shot(dir, "shot_night_bandit.png")
	_on_interact(npcs["bandido"])
	while not dialogue.choosing:
		dialogue.advance()
		await _wait(2)
	await _wait(10)
	_save_shot(dir, "shot_night_choice.png")
	dialogue.choose(2)
	await _wait(10)
	# 3. day 2 morning: Kuroda's camp across the bridge
	_goto(2, "manha")
	player.position = Vector3(17.6, 0, 0.6)
	player.face_dir(Vector3.FORWARD)
	snap_camera()
	await _wait(40)
	_save_shot(dir, "shot_camp.png")
	# 4. day 2 afternoon: Akamatsu at the inn
	_goto(2, "tarde")
	player.position = Vector3(3.0, 0, -1.2)
	player.face_dir(Vector3.FORWARD)
	snap_camera()
	await _wait(40)
	_save_shot(dir, "shot_akamatsu.png")
	# 5. a duel against Kuroda
	duel_seed = 7
	start_duel("kuroda")
	await stage.awaiting_input
	await _wait(20)
	_save_shot(dir, "shot_duel_kuroda.png")
	stage._on_picked("boca_menu", 0)
	await _wait(10)
	_save_shot(dir, "shot_duel_boca.png")
	# 6. an ending card
	anim_speed = 0.1
	state.set_flag("espada_forjada")
	await _end("leave")
	await _wait(20)
	_save_shot(dir, "shot_ending.png")
	get_tree().quit(0)


## Store-page screenshots: run windowed with --resolution 1920x1080.
func _promo(dir: String) -> void:
	hud.visible = false
	_saved.visible = false              # no autosave note in store shots
	# 1. golden afternoon on the main street, title card up
	player.position = Vector3(-2.2, 0, 0.6)
	player.face_dir(Vector3.LEFT)
	player.walk_frame = 2
	player._apply_frame()
	player.set_physics_process(false)
	snap_camera()
	_title.text = "My Samurai Way\n— Kurogane-juku —"
	_title.modulate.a = 1.0
	await _wait(60)
	_save_shot(dir, "cover_source.png")
	_title.modulate.a = 0.0
	await _wait(30)
	_save_shot(dir, "01_tarde.png")
	# 2. talking to Oyuki at the tea house
	player.position = Vector3(-7.3, 0, -0.75)
	player.face_dir(Vector3.FORWARD)
	player._apply_frame()
	snap_camera()
	await _wait(10)
	hud.visible = true
	_on_interact(npcs["oyuki"])
	await get_tree().create_timer(2.6).timeout
	_save_shot(dir, "02_dialogo.png")
	while dialogue.open:
		dialogue.advance()
	await _wait(5)
	current_entry = {}
	player.frozen = false
	# 3. night: the Corvo thug harassing Oyuki, lanterns lit
	_goto(1, "noite")
	await _wait(5)
	player.position = Vector3(-5.6, 0, 0.5)
	player.face_dir(Vector3.LEFT)
	snap_camera()
	await _wait(5)
	_on_interact(npcs["bandido"])
	while not dialogue.choosing:
		dialogue.advance()
		await _wait(2)
	await _wait(40)
	_save_shot(dir, "03_noite_escolha.png")
	dialogue.choose(2)
	await _wait(5)
	current_entry = {}
	player.frozen = false
	# 4. misty morning by the bridge
	_goto(2, "manha")
	player.position = Vector3(10.6, 0, 0.3)
	player.face_dir(Vector3.RIGHT)
	snap_camera()
	await _wait(60)
	_save_shot(dir, "04_manha_ponte.png")
	# 5. the journal, in the street
	_goto(2, "tarde")
	player.position = Vector3(1.0, 0, 0.8)
	snap_camera()
	state.set_flag("conhece_tetsu")
	state.set_flag("quer_aco")
	state.set_flag("salvou_oyuki")
	state.add_rep("vila", 25)
	state.add_rep("corvo", -15)
	hud.toggle_journal(state)
	await _wait(40)
	_save_shot(dir, "09_diario.png")
	hud.toggle_journal(state)
	player.frozen = false
	# 6. a duel with Tetsu: the boca and his reply
	duel_seed = 7
	player.position = Vector3(-4.9, 0, -0.6)
	snap_camera()
	await _wait(10)
	start_duel("tetsu")
	await stage.awaiting_input
	await _wait(20)
	_save_shot(dir, "05_duelo_menu.png")
	stage._on_picked("boca_menu", 0)
	await _wait(10)
	stage.pick_boca(Bocas.Cat.INSULTO)
	await get_tree().create_timer(1.0).timeout
	_save_shot(dir, "06_duelo_boca.png")
	await get_tree().create_timer(1.9).timeout
	_save_shot(dir, "07_duelo_reacao.png")
	await stage.awaiting_input
	stage.pick(Duel.Act.HEAVY)
	await get_tree().create_timer(0.66).timeout
	_save_shot(dir, "08_duelo_golpe.png")
	get_tree().quit(0)


## --duelfx <dir>: burst captures through each kind of blow, to judge the
## duel effects frame by frame.
func _duelfx(dir: String) -> void:
	hud.visible = false
	_goto(1, "tarde")
	duel_seed = 3
	player.position = Vector3(-4.9, 0, -0.6)
	snap_camera()
	await _wait(10)
	start_duel("tetsu")
	await stage.awaiting_input
	for step in [["heavy", Duel.Act.HEAVY], ["tech", Duel.Act.TECH], ["light", Duel.Act.LIGHT]]:
		stage.duel.hero.ki = 100
		stage.duel.foe.hp = stage.duel.foe.max_hp      # keep the duel going
		stage.duel.hero.hp = stage.duel.hero.max_hp
		stage.pick(step[1])
		for f in 16:
			await get_tree().create_timer(0.045, true, false, true).timeout
			_save_shot(dir, "%s_%02d.png" % [step[0], f])
		await stage.awaiting_input
	# the final blow (slow motion)
	stage.duel.foe.hp = 1
	stage.duel.hero.ki = 100
	stage.pick(Duel.Act.TECH)
	for f in 24:
		await get_tree().create_timer(0.06, true, false, true).timeout
		_save_shot(dir, "ko_%02d.png" % f)
	print("fx fired: ", stage.fx.fired if is_instance_valid(stage.fx) else "(freed)")
	get_tree().quit(0)


## --night <dir>: the village after dark from four viewpoints (look checks).
func _night(dir: String) -> void:
	hud.visible = false
	_saved.visible = false
	_goto(1, "noite")
	player.set_physics_process(false)
	for v in [["rua", Vector3(-2.0, 0, 0.6)], ["casa_de_cha", Vector3(-8.0, 0, 0.6)],
			["ponte", Vector3(11.4, 0, 0.3)], ["acampamento", Vector3(17.0, 0, 0.6)]]:
		player.position = v[1]
		player.face_dir(Vector3.FORWARD)
		snap_camera()
		await _wait(45)
		_save_shot(dir, "night_%s.png" % v[0])
	get_tree().quit(0)
