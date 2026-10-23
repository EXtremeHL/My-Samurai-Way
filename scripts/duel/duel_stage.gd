class_name DuelStage
extends Node
## Runs a duel inside the living village: the two fighters square off where
## they stand, the camera drops into a closer side framing, and every event
## the Duel logic returns is played back as animation + text.

signal finished(result: int, foe_id: String)
signal awaiting_input

const SPACING := 1.55            # each fighter stands this far from centre
const CAM_OFFSET := Vector3(0.0, 2.3, 7.6)
const CAM_LOOK := Vector3(0.0, 0.85, 0.0)

var main: Node
var duel: Duel
var ui: DuelUI
var hero: Actor
var foe: Actor
var foe_id := ""
var center := Vector3.ZERO
var active := false
var busy := false                # animating: input ignored
var in_boca_menu := false
var seed_value := 0
var _cam_from: Transform3D
var _attrs_explore: CameraAttributes
var _attrs_duel: CameraAttributesPractical
var _walking: Array = []


func _init(m: Node) -> void:
	main = m


func _ready() -> void:
	_attrs_duel = CameraAttributesPractical.new()
	_attrs_duel.dof_blur_far_enabled = true
	_attrs_duel.dof_blur_far_distance = 10.5
	_attrs_duel.dof_blur_far_transition = 7.0
	_attrs_duel.dof_blur_near_enabled = true
	_attrs_duel.dof_blur_near_distance = 4.0
	_attrs_duel.dof_blur_near_transition = 2.0
	_attrs_duel.dof_blur_amount = 0.14


# ---------------------------------------------------------------------------
# enter / exit
# ---------------------------------------------------------------------------
func start(id: String, npc: Actor, spot: Vector3) -> void:
	foe_id = id
	foe = npc
	hero = main.player
	active = true
	busy = true
	var data: Dictionary = Foes.ALL[id]
	duel = Duel.new(Foes.make_hero(), Foes.make_foe(id), seed_value)
	center = spot
	ui = DuelUI.new()
	add_child(ui)
	ui.picked.connect(_on_picked)
	ui.refresh(duel)
	ui.root.modulate.a = 0.0

	# walk both fighters to their marks
	await _walk_to([[hero, center + Vector3(-SPACING, 0, 0)], [foe, center + Vector3(SPACING, 0, 0)]])
	hero.enter_combat("hero", false)
	foe.enter_combat(data.sheet, true)

	# camera into duel framing
	var cam: Camera3D = main.cam
	_cam_from = cam.global_transform
	_attrs_explore = cam.attributes
	var to := Transform3D(Basis(), center + CAM_OFFSET).looking_at(center + CAM_LOOK, Vector3.UP)
	cam.attributes = _attrs_duel
	await _tween_cam(_cam_from, to, 0.7)
	create_tween().tween_property(ui.root, "modulate:a", 1.0, 0.3)
	ui.show_banner("DUELO", Color(1.0, 0.85, 0.5), 0.9)
	await _wait(0.6)
	await _say("foe", duel.foe.name, data.intro, 2.4)
	_next_turn()


func _finish() -> void:
	ui.show_menu(false)
	var data: Dictionary = Foes.ALL[foe_id]
	match duel.result:
		Duel.Result.WIN:
			ui.show_banner("VITÓRIA", Color(1.0, 0.86, 0.45), 1.4)
			await _wait(1.0)
			await _say("foe", duel.foe.name, data.win, 2.4)
		Duel.Result.SURRENDER:
			ui.show_banner("RENDIÇÃO", Color(0.7, 0.95, 0.7), 1.4)
			await _wait(1.6)
		Duel.Result.LOSE:
			ui.show_banner("DERROTA", Color(1.0, 0.45, 0.4), 1.4)
			await _wait(1.0)
			await _say("foe", duel.foe.name, data.lose, 2.4)
	create_tween().tween_property(ui.root, "modulate:a", 0.0, 0.3)
	var cam: Camera3D = main.cam
	var back := Transform3D(_cam_from.basis, main._focus_point() + main.CAM_OFFSET)
	await _tween_cam(cam.global_transform, back, 0.6)
	cam.attributes = _attrs_explore
	hero.exit_combat()
	foe.exit_combat()
	hero.face_dir(Vector3.RIGHT)
	foe.face_dir(Vector3.LEFT)
	ui.queue_free()
	active = false
	busy = false
	finished.emit(duel.result, foe_id)


# ---------------------------------------------------------------------------
# turn loop + input
# ---------------------------------------------------------------------------
func _next_turn() -> void:
	if duel.result != Duel.Result.ONGOING:
		_finish()
		return
	duel.begin_turn()
	ui.refresh(duel)
	ui.set_intent(duel.intent_text())
	hero.pose("ready")
	foe.pose("ready")
	_open_main_menu()


func _open_main_menu() -> void:
	in_boca_menu = false
	busy = false
	ui.build_main_menu(duel)
	awaiting_input.emit()


## Public entry points (UI buttons and automated tests both land here).
func pick(a: int) -> void:
	if busy or not active:
		return
	if a == Duel.Act.TECH and not duel.can_use(a):
		return
	busy = true
	ui.show_menu(false)
	var ev := duel.play_turn(a)
	await _play_events(ev)
	ui.refresh(duel)
	_next_turn()


func pick_boca(cat: int) -> void:
	if busy or not active or not duel.can_boca():
		return
	busy = true
	ui.show_menu(false)
	var ev := duel.say_boca(cat)
	await _play_events(ev)
	ui.refresh(duel)
	if duel.result != Duel.Result.ONGOING:
		_finish()
		return
	ui.set_intent(duel.intent_text(), true)
	_open_main_menu()


func _on_picked(kind: String, value: int) -> void:
	if busy:
		return
	match kind:
		"act":
			pick(value)
		"boca":
			pick_boca(value)
		"boca_menu":
			in_boca_menu = true
			ui.build_boca_menu(duel)
		"back":
			_open_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not active or busy:
		return
	if event.is_action_pressed("interact"):
		var b := ui.focused_button()
		if b and not b.disabled:
			get_viewport().set_input_as_handled()
			b.pressed.emit()
	elif event.is_action_pressed("cancel") and in_boca_menu:
		get_viewport().set_input_as_handled()
		_open_main_menu()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		# WASD navigates the menu too
		var b := ui.focused_button()
		if b:
			get_viewport().set_input_as_handled()
			var nb := b.find_valid_focus_neighbor(SIDE_TOP if event.is_action_pressed("move_up") else SIDE_BOTTOM)
			if nb:
				nb.grab_focus()


# ---------------------------------------------------------------------------
# event playback
# ---------------------------------------------------------------------------
func _actor(who: String) -> Actor:
	return hero if who == "hero" else foe


func _other(who: String) -> String:
	return "foe" if who == "hero" else "hero"


func _fighter(who: String) -> Fighter:
	return duel.hero if who == "hero" else duel.foe


func _screen(a: Actor, h := 1.9) -> Vector2:
	return main.cam.unproject_position(a.global_position + Vector3(0, h, 0))


func _play_events(ev: Array) -> void:
	for e in ev:
		match e.t:
			"boca":
				await _say("hero", "Tu", e.line, 2.0)
				if e.mood != Personality.Mood.NONE:
					foe.set_flash(0.5)
					create_tween().tween_method(foe.set_flash, 0.5, 0.0, 0.4)
					ui.float_text(Personality.MOOD_NAMES[e.mood].to_upper() + "!", _screen(foe, 1.2),
						DuelUI.mood_color(e.mood, true), 34, 40.0)
				await _say("foe", duel.foe.name, e.reply, 2.0)
				if e.reveal:
					var p: int = duel.foe.personality
					ui.refresh(duel)
					ui.show_banner(Personality.NAMES[p].to_upper(), Color(0.9, 0.85, 1.0), 1.3)
					ui.set_intent(Personality.BLURBS[p], true)
					await _wait(1.8)
				if e.repeat and e.mood == Personality.Mood.NONE:
					ui.float_text("Já ouvi essa.", _screen(foe, 2.3), Color(0.8, 0.8, 0.85), 22)
			"intent_change":
				ui.set_intent(duel.intent_text(), true)
				await _wait(0.6)
			"guard":
				_actor(e.who).pose("guard")
				ui.float_text("Guarda", _screen(_actor(e.who), 1.6), Color(0.7, 0.85, 1.0), 22)
				await _wait(0.45)
			"parry_stance":
				_actor(e.who).pose("guard")
				ui.float_text("Contra-ataque...", _screen(_actor(e.who), 1.6), Color(0.7, 0.85, 1.0), 22)
				await _wait(0.45)
			"hit":
				await _strike(e.who, e.kind, true)
				var tgt := _actor(_other(e.who))
				var col := Color(1.0, 0.95, 0.85) if e.who == "hero" else Color(1.0, 0.5, 0.45)
				var txt := str(e.dmg)
				ui.float_text(txt, _screen(tgt, 1.4), col, 40 if (e.crit or e.kind != Duel.Act.LIGHT) else 32)
				if e.crit:
					ui.float_text("CRÍTICO!", _screen(tgt, 2.0), Color(1.0, 0.8, 0.3), 24)
				if e.guarded:
					ui.float_text("Bloqueado", _screen(tgt, 2.0), Color(0.7, 0.85, 1.0), 22)
				if e.get("caught", false):
					ui.float_text("Em contrapé!", _screen(tgt, 2.0), Color(1.0, 0.6, 0.4), 24)
				ui.refresh(duel)
				await _recover(e.who)
			"miss":
				await _strike(e.who, e.kind, false)
				ui.float_text("Falhou", _screen(_actor(_other(e.who)), 1.6), Color(0.85, 0.85, 0.9), 24)
				await _recover(e.who)
			"parried":
				# attacker swings, defender turns it and cuts back
				var att := _actor(e.who)
				var dfn := _actor(e.by)
				att.pose("raise")
				dfn.pose("guard")
				await _wait(0.25)
				await _lunge(att, 0.55)
				ui.float_text("Desviado!", _screen(dfn, 2.0), Color(0.7, 0.85, 1.0), 26)
				dfn.pose("slash")
				_slash_fx(att, e.by == "foe")
				_hurt(att)
				ui.float_text(str(e.dmg), _screen(att, 1.4), Color(1.0, 0.95, 0.85) if e.by == "hero" else Color(1.0, 0.5, 0.45), 40)
				_shake(0.18)
				ui.refresh(duel)
				await _wait(0.5)
				await _return(att)
			"parry_wasted":
				ui.float_text("...ninguém atacou.", _screen(_actor(e.who), 1.7), Color(0.8, 0.8, 0.85), 20)
				await _wait(0.5)
			"skip":
				foe.pose("hurt")
				await _say("foe", duel.foe.name, "...", 0.9)
				ui.float_text("Distraído: perde a vez", _screen(foe, 2.1), DuelUI.GOOD, 22)
				await _wait(0.6)
			"taunt":
				await _say("foe", duel.foe.name, e.line, 2.0)
				if e.mood != Personality.Mood.NONE:
					ui.float_text("ABALADO", _screen(hero, 2.1), DuelUI.BAD, 30)
					ui.refresh(duel)
					await _wait(0.6)
			"observe":
				var p: int = e.personality
				ui.refresh(duel)
				ui.show_banner(Personality.NAMES[p].to_upper(), Color(0.9, 0.85, 1.0), 1.3)
				ui.set_intent(Personality.BLURBS[p], true)
				await _wait(1.9)
			"surrender":
				foe.pose("down")
				await _say("foe", duel.foe.name, e.line, 2.2)
			"ko":
				var a := _actor(e.who)
				a.pose("down")
				a.set_flash(0.8)
				create_tween().tween_method(a.set_flash, 0.8, 0.0, 0.6)
				_shake(0.3)
				await _wait(0.9)
	ui.clear_bubbles()


func _strike(who: String, kind: int, hits: bool) -> void:
	var att := _actor(who)
	var tgt := _actor(_other(who))
	att.pose("raise")
	await _wait(0.28 if kind == Duel.Act.LIGHT else 0.45)
	if kind == Duel.Act.TECH:
		att.set_flash(0.6)
		ui.float_text(Duel.TECH_NAME, _screen(att, 2.2), Color(0.75, 0.9, 1.0), 26)
		await _wait(0.35)
		att.set_flash(0.0)
	await _lunge(att, 0.85 if kind == Duel.Act.LIGHT else 1.0)
	att.pose("slash")
	_slash_fx(tgt, who == "foe")
	if hits:
		_hurt(tgt)
		_shake(0.12 if kind == Duel.Act.LIGHT else 0.25)
	else:
		var side := 1.0 if who == "hero" else -1.0
		var t := create_tween()
		t.tween_property(tgt, "position:x", tgt.position.x + 0.35 * side, 0.1)
		t.tween_property(tgt, "position:x", tgt.position.x, 0.25)
	await _wait(0.4)


func _recover(who: String) -> void:
	var att := _actor(who)
	var tgt := _actor(_other(who))
	await _return(att)
	att.pose("ready")
	if _fighter(_other(who)).alive():
		tgt.pose("ready")


func _lunge(a: Actor, dist: float) -> void:
	var dir := 1.0 if a == hero else -1.0
	a.set_meta("home_x", a.position.x)
	var t := create_tween()
	t.tween_property(a, "position:x", a.position.x + dist * dir, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func _return(a: Actor) -> void:
	if not a.has_meta("home_x"):
		return
	var t := create_tween()
	t.tween_property(a, "position:x", float(a.get_meta("home_x")), 0.22).set_trans(Tween.TRANS_QUAD)
	await t.finished


func _hurt(a: Actor) -> void:
	a.pose("hurt")
	a.set_flash(0.85)
	create_tween().tween_method(a.set_flash, 0.85, 0.0, 0.35)
	var dir := -1.0 if a == hero else 1.0
	var t := create_tween()
	t.tween_property(a, "position:x", a.position.x + 0.2 * dir, 0.06)
	t.tween_property(a, "position:x", a.position.x, 0.2)


func _slash_fx(target: Actor, from_right: bool) -> void:
	var s := Sprite3D.new()
	s.texture = load("res://assets/sprites/fx_slash.png")
	s.pixel_size = 1.0 / 30.0
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.flip_h = from_right
	s.position = target.global_position + Vector3(0.0, 0.85, 0.12)
	s.modulate = Color(1, 1, 1, 0.95)
	main.add_child(s)
	var hit := Sprite3D.new()
	hit.texture = load("res://assets/sprites/fx_hit.png")
	hit.pixel_size = 1.0 / 30.0
	hit.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hit.shaded = false
	hit.position = target.global_position + Vector3(0.0, 0.95, 0.15)
	main.add_child(hit)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(s, "modulate:a", 0.0, 0.3)
	t.tween_property(s, "scale", Vector3(1.25, 1.25, 1.0), 0.3)
	t.tween_property(hit, "scale", Vector3(1.8, 1.8, 1.0), 0.2)
	t.tween_property(hit, "modulate:a", 0.0, 0.25)
	t.chain().tween_callback(s.queue_free)
	t.chain().tween_callback(hit.queue_free)


func _shake(strength: float) -> void:
	var cam: Camera3D = main.cam
	var t := create_tween()
	for i in 5:
		var k := strength * (1.0 - i / 5.0)
		t.tween_property(cam, "h_offset", randf_range(-k, k), 0.03)
		t.tween_property(cam, "v_offset", randf_range(-k, k), 0.03)
	t.tween_property(cam, "h_offset", 0.0, 0.03)
	t.tween_property(cam, "v_offset", 0.0, 0.03)


func _say(who: String, speaker: String, text: String, secs: float) -> void:
	var a := _actor(who)
	ui.bubble(who, speaker, text, _screen(a, 2.15))
	await _wait(secs)
	ui.clear_bubble(who)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
func _wait(secs: float) -> void:
	await get_tree().create_timer(secs * main.anim_speed).timeout


func _tween_cam(from: Transform3D, to: Transform3D, secs: float) -> void:
	var cam: Camera3D = main.cam
	var t := create_tween()
	t.tween_method(func(k: float): cam.global_transform = from.interpolate_with(to, k), 0.0, 1.0, secs * main.anim_speed)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _walk_to(moves: Array) -> void:
	var t := create_tween()
	t.set_parallel(true)
	var secs := 0.0
	for m in moves:
		var a: Actor = m[0]
		var target: Vector3 = m[1]
		var d := a.position.distance_to(target)
		secs = maxf(secs, d / 3.0)
	secs = maxf(0.2, secs) * main.anim_speed
	for m in moves:
		var a: Actor = m[0]
		a.face_dir(m[1] - a.position)
		t.tween_property(a, "position", m[1], secs)
	_walking = moves
	await t.finished
	_walking = []
	for m in moves:
		m[0].animate(false, 0.0)


func _process(delta: float) -> void:
	for m in _walking:
		m[0].animate(true, delta)
