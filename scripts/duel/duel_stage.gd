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
var fx: DuelFX
var last_fx: Array[String] = []   # effects of the last finished duel (tests)
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
var _petals_were := false


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
func start(id: String, npc: Actor, spot: Vector3, hero_fighter: Fighter = null, blade := "Lâmina partida") -> void:
	foe_id = id
	foe = npc
	hero = main.player
	active = true
	busy = true
	var data: Dictionary = Foes.ALL[id]
	duel = Duel.new(hero_fighter if hero_fighter else Foes.make_hero(), Foes.make_foe(id), seed_value)
	center = spot
	ui = DuelUI.new()
	ui.blade_name = blade
	add_child(ui)
	ui.picked.connect(_on_picked)
	ui.refresh(duel)
	ui.root.modulate.a = 0.0
	fx = DuelFX.new()
	add_child(fx)
	fx.setup(main.cam, main.anim_speed)

	# walk both fighters to their marks
	await _walk_to([[hero, center + Vector3(-SPACING, 0, 0)], [foe, center + Vector3(SPACING, 0, 0)]])
	hero.enter_combat("hero", false)
	foe.enter_combat(data.sheet, true)

	# camera into duel framing
	# petals drifting past the close duel camera turn into huge blurred squares
	_petals_were = main.village.petals.visible
	main.village.petals.visible = false
	var cam: Camera3D = main.cam
	_cam_from = cam.global_transform
	_attrs_explore = cam.attributes
	var to := Transform3D(Basis(), center + CAM_OFFSET).looking_at(center + CAM_LOOK, Vector3.UP)
	cam.attributes = _attrs_duel
	GameAudio.music("duel", 0.6)
	GameAudio.sfx("duel_start", -2.0)
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
			GameAudio.music("", 0.4)
			GameAudio.sfx("victory", -2.0)
			ui.show_banner("VITÓRIA", Color(1.0, 0.86, 0.45), 1.4)
			await _wait(1.0)
			await _say("foe", duel.foe.name, data.win, 2.4)
		Duel.Result.SURRENDER:
			GameAudio.music("", 0.4)
			GameAudio.sfx("victory", -2.0)
			ui.show_banner("RENDIÇÃO", Color(0.7, 0.95, 0.7), 1.4)
			await _wait(1.6)
		Duel.Result.LOSE:
			GameAudio.music("", 0.4)
			GameAudio.sfx("defeat", -2.0)
			ui.show_banner("DERROTA", Color(1.0, 0.45, 0.4), 1.4)
			await _wait(1.0)
			if data.lose != "":
				await _say("foe", duel.foe.name, data.lose, 2.4)
	create_tween().tween_property(ui.root, "modulate:a", 0.0, 0.3)
	var cam: Camera3D = main.cam
	var back := Transform3D(_cam_from.basis, main._focus_point() + main.CAM_OFFSET)
	await _tween_cam(cam.global_transform, back, 0.6)
	cam.attributes = _attrs_explore
	main.village.petals.visible = _petals_were
	hero.exit_combat()
	foe.exit_combat()
	hero.face_dir(Vector3.RIGHT)
	foe.face_dir(Vector3.LEFT)
	ui.queue_free()
	last_fx = fx.fired.duplicate()
	fx.queue_free()
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
				GameAudio.sfx("boca", -3.0)
				await _say("hero", "Tu", e.line, 2.0)
				if e.mood == Personality.Mood.NONE:
					GameAudio.sfx("mood_none", -4.0)
				elif e.mood in Personality.GOOD_FOR_SPEAKER:
					GameAudio.sfx("mood_good", -3.0)
				else:
					GameAudio.sfx("mood_bad", -3.0)
				if e.mood != Personality.Mood.NONE:
					foe.set_flash(0.5)
					create_tween().tween_method(foe.set_flash, 0.5, 0.0, 0.4)
					ui.float_text(Personality.MOOD_NAMES[e.mood].to_upper() + "!", _screen(foe, 1.2),
						DuelUI.mood_color(e.mood, true), 34, 40.0)
				await _say("foe", duel.foe.name, e.reply, 2.0)
				if e.reveal:
					GameAudio.sfx("reveal", -4.0)
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
				GameAudio.sfx("guard", -4.0, 0.05)
				_actor(e.who).pose("guard")
				ui.float_text("Guarda", _screen(_actor(e.who), 1.6), Color(0.7, 0.85, 1.0), 22)
				await _wait(0.45)
			"parry_stance":
				GameAudio.sfx("guard", -6.0, 0.05, 1.2)
				_actor(e.who).pose("guard")
				ui.float_text("Contra-ataque...", _screen(_actor(e.who), 1.6), Color(0.7, 0.85, 1.0), 22)
				await _wait(0.45)
			"hit":
				await _strike(e.who, e.kind, true, e)
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
				att.pose("windup")
				dfn.pose("guard")
				await _wait(0.1)
				att.pose("raise")
				await _wait(0.2)
				GameAudio.sfx("slash_heavy", -3.0, 0.05)
				att.pose("swing")
				await _lunge(att, 0.55)
				# steel on steel: sparks between the blades, a frozen beat, then the cut back
				GameAudio.sfx("clash", -1.0, 0.04)
				fx.sparks((att.global_position + dfn.global_position) * 0.5 + Vector3(0, 1.05, 0.3), 26, true)
				fx.flash(Color(1, 1, 1), 0.3, 0.18)
				fx.shake(0.12, 0.2)
				await fx.hitstop(0.14)
				ui.float_text("Desviado!", _screen(dfn, 2.0), Color(0.7, 0.85, 1.0), 26)
				dfn.pose("swing")
				await _wait(0.05)
				dfn.pose("slash")
				fx.slash(att, Duel.Act.HEAVY, e.by == "foe")
				fx.impact(att, true)
				_hurt(att)
				GameAudio.sfx("hit_heavy", -2.0, 0.05)
				ui.float_text(str(e.dmg), _screen(att, 1.4), Color(1.0, 0.95, 0.85) if e.by == "hero" else Color(1.0, 0.5, 0.45), 40)
				fx.punch(0.07)
				fx.shake(0.22)
				ui.refresh(duel)
				await _wait(0.5)
				dfn.pose("recover")
				await _return(att)
				att.pose("ready")
				dfn.pose("ready")
			"parry_wasted":
				ui.float_text("...ninguém atacou.", _screen(_actor(e.who), 1.7), Color(0.8, 0.8, 0.85), 20)
				await _wait(0.5)
			"skip":
				GameAudio.sfx("mood_none", -6.0, 0.0, 0.8)
				foe.pose("hurt")
				await _say("foe", duel.foe.name, "...", 0.9)
				ui.float_text("Distraído: perde a vez", _screen(foe, 2.1), DuelUI.GOOD, 22)
				await _wait(0.6)
			"taunt":
				GameAudio.sfx("boca", -4.0, 0.0, 0.85)
				await _say("foe", duel.foe.name, e.line, 2.0)
				if e.mood != Personality.Mood.NONE:
					GameAudio.sfx("mood_bad", -4.0)
					ui.float_text("ABALADO", _screen(hero, 2.1), DuelUI.BAD, 30)
					ui.refresh(duel)
					await _wait(0.6)
			"observe":
				GameAudio.sfx("reveal", -4.0)
				var p: int = e.personality
				ui.refresh(duel)
				ui.show_banner(Personality.NAMES[p].to_upper(), Color(0.9, 0.85, 1.0), 1.3)
				ui.set_intent(Personality.BLURBS[p], true)
				await _wait(1.9)
			"surrender":
				foe.pose("down")
				await _say("foe", duel.foe.name, e.line, 2.2)
			"ko":
				GameAudio.sfx("ko", 0.0)
				var a := _actor(e.who)
				a.pose("fall")
				await _wait(0.16)
				a.pose("down")
				a.set_flash(0.5)
				create_tween().tween_method(a.set_flash, 0.5, 0.0, 0.3)
				fx.flash(Color(0.75, 0.08, 0.06), 0.35, 0.6)
				fx.dust(a.global_position, 16)
				fx.shake(0.32, 0.45)
				fx.punch(0.1)
				fx.slowmo(0.3, 0.7)
				await _wait(0.9)
	ui.clear_bubbles()


func _strike(who: String, kind: int, hits: bool, e := {}) -> void:
	var att := _actor(who)
	var tgt := _actor(_other(who))
	if kind == Duel.Act.LIGHT:
		# tsuki: pull the hands back to the hip, then drive straight in
		att.pose("cock")
		await _wait(0.22)
		GameAudio.sfx("slash_light", -3.0, 0.06)
		att.pose("thrust")
		await _lunge(att, 0.85)
	else:
		# overhead cut: rise through windup into jodan, hold, step in and cut
		att.pose("windup")
		await _wait(0.1)
		att.pose("raise")
		await _wait(0.3)
		if kind == Duel.Act.TECH:
			GameAudio.sfx("tech", -2.0)
			att.set_flash(0.6)
			fx.sparks(att.global_position + Vector3(0, 1.0, 0.2), 18, false)   # ki gathering on the blade
			ui.float_text(Duel.TECH_NAME, _screen(att, 2.2), Color(0.75, 0.9, 1.0), 26)
			await _wait(0.35)
			att.set_flash(0.0)
		else:
			GameAudio.sfx("slash_heavy", -3.0, 0.06)
		fx.dust(att.global_position)                   # the push-off kicks up dirt
		await _anticipate(att)
		att.pose("swing")
		await _lunge(att, 1.0)
		att.pose("slash")
	fx.slash(tgt, kind, who == "foe")
	if hits:
		GameAudio.sfx("hit" if kind == Duel.Act.LIGHT else "hit_heavy", -2.0, 0.06)
		_hurt(tgt)
		var guarded: bool = e.get("guarded", false)
		var crit: bool = e.get("crit", false)
		fx.impact(tgt, kind != Duel.Act.LIGHT or crit)
		if guarded:
			tgt.pose("guard")
			fx.sparks(tgt.global_position + Vector3(0, 1.0, 0.3), 14, false)
		match kind:
			Duel.Act.LIGHT:
				fx.shake(0.07, 0.18)
				await fx.hitstop(0.05)
			Duel.Act.HEAVY:
				fx.punch(0.06)
				fx.shake(0.2, 0.3)
				await fx.hitstop(0.1)
			Duel.Act.TECH:
				fx.flash(Color(0.85, 0.95, 1.0), 0.55, 0.3)
				fx.sparks(tgt.global_position + Vector3(0, 1.0, 0.3), 30, false)
				fx.punch(0.12)
				fx.shake(0.3, 0.4)
				await fx.hitstop(0.14)
		if crit:
			fx.flash(Color(1.0, 0.92, 0.7), 0.3, 0.2)
	else:
		GameAudio.sfx("miss", -4.0, 0.08)
		var side := 1.0 if who == "hero" else -1.0
		tgt.pose("guard")
		var t := create_tween()
		t.tween_property(tgt, "position:x", tgt.position.x + 0.35 * side, 0.1)
		t.tween_property(tgt, "position:x", tgt.position.x, 0.25)
	await _wait(0.3)


## A small step back before a big blow, so the lunge reads.
func _anticipate(a: Actor) -> void:
	var dir := -1.0 if a == hero else 1.0
	var t := create_tween()
	t.tween_property(a, "position:x", a.position.x + 0.12 * dir, 0.08 * main.anim_speed) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished


func _recover(who: String) -> void:
	var att := _actor(who)
	var tgt := _actor(_other(who))
	att.pose("recover")
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
	a.set_flash(0.6)
	create_tween().tween_method(a.set_flash, 0.6, 0.0, 0.3)
	var dir := -1.0 if a == hero else 1.0
	var t := create_tween()
	t.tween_property(a, "position:x", a.position.x + 0.2 * dir, 0.06)
	t.tween_property(a, "position:x", a.position.x, 0.2)


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


var _breath_t := 0.0


func _process(delta: float) -> void:
	for m in _walking:
		m[0].animate(true, delta)
	if not active or hero == null or foe == null:
		return
	# idle breathing: fighters standing in "ready" sink and rise, out of step
	_breath_t += delta
	for a in [hero, foe]:
		if a.current_pose in ["ready", "breathe"] and a.in_combat():
			var phase := 0.0 if a == hero else 0.45
			var down := fmod(_breath_t * 0.85 + phase, 1.0) > 0.5
			var want := "breathe" if down else "ready"
			if a.current_pose != want:
				a.pose(want)
