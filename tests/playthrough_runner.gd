extends Node
## Integration test: boots the real game (`-- --playthrough`) and drives it
## through the same input actions the player uses.

var main: Node
var ok := true


func check(cond: bool, msg: String) -> void:
	if cond:
		print("ok:   ", msg)
	else:
		print("FAIL: ", msg)
		ok = false


func physics(frames: int) -> void:
	for _f in frames:
		await get_tree().physics_frame


func frames(n: int) -> void:
	for _f in n:
		await get_tree().process_frame


func hold(action: String, n: int) -> Array:
	## Holds an action; returns the walk frames seen while it was held.
	var seen := []
	Input.action_press(action)
	for _f in n:
		await get_tree().physics_frame
		if not seen.has(main.player.walk_frame):
			seen.append(main.player.walk_frame)
	Input.action_release(action)
	await physics(2)
	return seen


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	get_tree().root.push_input(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	get_tree().root.push_input(up)
	await get_tree().process_frame


## Waits until nothing is animating: no fade, dialogue may be open.
func settle(max_frames := 3000) -> void:
	for _f in max_frames:
		await get_tree().process_frame
		if main.stage.active and not main.stage.busy:
			return
		if not main.stage.active and (not main.player.frozen or main.dialogue.open or main.ended_with != ""):
			return


## Talk to whoever is in range and click through; `choice` picks an option.
func talk(choice := -1) -> void:
	await press("interact")
	var n := 0
	while main.dialogue.open and n < 60:
		if main.dialogue.choosing:
			if choice < 0:
				choice = main.dialogue._choice_tags.size() - 1
			main.dialogue.choice_index = choice
			await press("interact")
		else:
			await press("interact")
		n += 1
	await settle()


func to_choice() -> void:
	var n := 0
	while main.dialogue.open and not main.dialogue.choosing and n < 30:
		await press("interact")
		n += 1


func teleport(p: Vector3) -> void:
	main.player.position = p
	main.player.velocity = Vector3.ZERO
	main.snap_camera()
	await physics(3)


func present(id: String) -> bool:
	return main.npcs[id].visible


func run(m: Node) -> void:
	main = m
	await physics(5)
	var pl: Player = main.player
	var st: GameState = main.state

	# =====================================================================
	# arrival: day 1, afternoon
	# =====================================================================
	check(st.clock_text() == "Dia 1 · Tarde", "arrive on day 1, afternoon")
	check(main.hud.clock_label.text == "Dia 1 · Tarde", "HUD shows the clock")
	var expected := []
	for id in Story.ids():
		if Story.present(id, st) != null:
			expected.append(id)
	var shown: Array = main.npcs.keys().filter(func(id): return present(id))
	check(shown.size() == expected.size() and shown.size() >= 6, "the right people are about (%s)" % [shown])
	check(not present("bandido") and not present("kuroda") and not present("akamatsu"), "night thugs and bosses not here yet")
	check(pl.position.distance_to(StoryData.PLAYER_START) < 0.05, "player at start position")
	var au: GameAudio = GameAudio.inst
	check(au != null and au.current_music == "town_day" and au.current_amb == "amb_day", "afternoon: town music + day ambience")

	# =====================================================================
	# walking
	# =====================================================================
	var x0 := pl.position.x
	var seen_frames := await hold("move_right", 40)
	check(pl.position.x > x0 + 1.5, "walking right moves player (%.2f -> %.2f)" % [x0, pl.position.x])
	check(seen_frames.size() >= 3, "walk cycle animates (frames seen %s)" % [seen_frames])
	check(au.played("step_1") or au.played("step_2") or au.played("step_3"), "footsteps on the dirt road")
	check(pl.facing == "side" and not pl.flip, "faces right after walking right")
	await hold("move_left", 10)
	check(pl.facing == "side" and pl.flip, "faces left (flipped)")
	await teleport(Vector3(0.0, 0, 0.0))
	await hold("move_down", 10)
	check(pl.facing == "down", "faces down after walking down")
	await teleport(Vector3(-2.0, 0, 0.5))
	await hold("move_right", 30)
	var walked := pl.position.x + 2.0
	await teleport(Vector3(-2.0, 0, 0.5))
	Input.action_press("run")
	await hold("move_right", 30)
	Input.action_release("run")
	check(pl.position.x + 2.0 > walked * 1.4, "running covers more ground")
	await teleport(Vector3(-0.5, 0, 0.0))
	await hold("move_up", 150)
	check(pl.position.z > -3.75 and pl.position.z < -2.5, "inn wall blocks the player (z=%.2f)" % pl.position.z)
	await teleport(Vector3(10.0, 0, 3.6))
	await hold("move_right", 90)
	check(pl.position.x < 11.3, "stream blocks the player off the bridge (x=%.2f)" % pl.position.x)
	await teleport(Vector3(9.6, 0, 0.25))
	var max_y := 0.0
	Input.action_press("move_right")
	for _f in 120:
		await get_tree().physics_frame
		max_y = maxf(max_y, pl.position.y)
	Input.action_release("move_right")
	await physics(2)
	check(pl.position.x > 14.8 and max_y > 0.25, "player crosses the arched bridge (x=%.2f, max y=%.2f)" % [pl.position.x, max_y])
	check(au.played("step_wood_1") or au.played("step_wood_2"), "footsteps sound wooden on the bridge")
	await teleport(Vector3(0.0, 0, 4.0))
	await hold("move_down", 120)
	check(pl.position.z < Village.BOUNDS.end.y, "southern bound holds")
	await teleport(Vector3(-6.0, 0, 0.5))
	await physics(90)
	check(main.cam.position.distance_to(main._focus_point() + main.CAM_OFFSET) < 0.3, "camera follows the player")

	# =====================================================================
	# conversations cost time
	# =====================================================================
	var oyuki: Npc = main.npcs["oyuki"]
	await teleport(Vector3(-7.3, 0, -0.7))
	await physics(2)
	check(pl.focus == oyuki and oyuki._prompt.visible, "Oyuki in range, marker shown")
	await frames(1)
	check(main.hint.text.contains("Oyuki"), "HUD hint names Oyuki")
	var u0 := st.units
	await press("interact")
	check(main.dialogue.open and main.current_entry.id == "oyuki_1", "first talk with Oyuki")
	check(oyuki.facing == "down", "Oyuki turns toward the player")
	var before := pl.position
	await hold("move_left", 20)
	check(pl.position.distance_to(before) < 0.01, "player can't walk during dialogue")
	var presses := 0
	while main.dialogue.open and presses < 40:
		await press("interact")
		presses += 1
	await settle()
	check(not main.dialogue.open and not pl.frozen, "dialogue closes, player free")
	check(st.units == u0 + GameState.COST_TALK, "talking costs time (%d -> %d)" % [u0, st.units])
	check(main.hud.pips.text.count("○") == st.units, "HUD pips show time spent")
	await press("interact")
	check(main.current_entry.get("id", "") == "oyuki_dica", "second talk: something new to say")
	while main.dialogue.open:
		await press("interact")
	await settle()

	# --- interact far from anyone does nothing ---
	await teleport(Vector3(2.0, 0, 3.0))
	await physics(2)
	await press("interact")
	check(not main.dialogue.open and pl.focus == null, "interact with nobody nearby does nothing")

	# --- journal ---
	await press("journal")
	check(main.hud.journal_open and pl.frozen, "Tab opens the journal and pauses the hero")
	check(main.hud.journal_body.text.contains("Reputação"), "journal shows reputation")
	check(au.history.back() == "page", "journal rustles like paper")
	await press("journal")
	check(not main.hud.journal_open and not pl.frozen, "Tab closes it")

	# =====================================================================
	# duel with Tetsu: choice -> duel -> mercy choice -> consequences
	# =====================================================================
	main.anim_speed = 0.02
	main.duel_seed = 4242
	st.units = 0
	var stage: DuelStage = main.stage
	var tetsu: Npc = main.npcs["tetsu"]
	await teleport(Vector3(-4.9, 0, -0.6))
	await talk()
	check(st.has("conhece_tetsu") and tetsu.display_name == "Tetsu", "Tetsu introduces himself; name now known")
	await press("interact")
	var guard := 0
	while main.dialogue.open and not main.dialogue.choosing and guard < 30:
		await press("interact")
		guard += 1
	check(main.dialogue.choosing, "Tetsu's challenge ends in a choice")
	await press("move_down")
	check(main.dialogue.choice_index == 1, "choice cursor moves down")
	await press("move_up")
	await press("interact")
	await settle()
	check(stage.active, "choosing 'Desembainhar' starts the duel")
	check(au.played("choice") and au.played("ui_select"), "choices have their own sounds")
	check(au.current_music == "duel" and au.played("duel_start"), "duel music + kabuki clappers")
	check(pl.in_combat() and tetsu.in_combat(), "both fighters switch to combat sprites")
	check(not main.hud.clock_panel.visible, "exploration HUD hidden in the duel")
	var turn0 := stage.duel.turn
	await press("interact")
	await settle()
	check(stage.duel.turn == turn0 + 1, "pressing E on the menu plays a turn")
	stage.duel.hero.ki = 50
	var t1 := stage.duel.turn
	stage._on_picked("boca_menu", 0)
	check(stage.ui.menu_box.get_child_count() == Bocas.ORDER.size() + 1, "boca submenu lists every boca + back")
	await press("cancel")
	check(not stage.in_boca_menu, "Esc backs out of the boca menu")
	stage.pick_boca(Bocas.Cat.TROCA)
	await settle()
	check(stage.duel.turn == t1 and stage.duel.hero.ki == 50 - Duel.BOCA_KI, "boca: same turn, -%d ki" % Duel.BOCA_KI)
	check(au.played("boca") and (au.played("mood_good") or au.played("mood_bad") or au.played("mood_none")), "a boca has a stinger and a reaction sound")
	stage.duel.foe.hp = 1
	var n := 0
	while stage.active and n < 20:
		stage.pick(Duel.Act.TECH if stage.duel.can_use(Duel.Act.TECH) else Duel.Act.LIGHT)
		await settle()
		n += 1
	var fx_seen := stage.last_fx
	check(main.last_duel_result == Duel.Result.WIN, "won the duel")
	check(au.played("victory") and au.played("ko"), "victory fanfare and the fall")
	check(au.played("slash_light") or au.played("slash_heavy") or au.played("tech"), "blades swish")
	check(au.played("hit") or au.played("hit_heavy") or au.played("miss"), "blows land (or whiff)")
	check(fx_seen.has("slash_%d" % Duel.Act.TECH) or fx_seen.has("slash_%d" % Duel.Act.LIGHT), "a sword trail is drawn")
	check(fx_seen.has("hitstop") and fx_seen.has("shake") and fx_seen.has("impact"), "blows land with hit-stop, shake and an impact star")
	check(fx_seen.has("slowmo"), "the final blow goes into slow motion")
	await to_choice()
	check(is_equal_approx(Engine.time_scale, 1.0), "hit-stop / slow motion always give time back")
	check(main.cam.h_offset == 0.0 and main.cam.v_offset == 0.0, "camera shake fully settles")
	check(main.dialogue.open and main.dialogue.choosing, "victory: spare him or finish him?")
	var hp_after := stage.duel.hero.hp
	main.dialogue.choose(0)
	await settle()
	check(st.has("venceu_tetsu") and not st.has("dead_tetsu"), "Tetsu beaten and spared")
	check(st.hero_hp == hp_after, "the hero keeps his wounds (%d hp)" % st.hero_hp)
	check(present("tetsu") and not pl.in_combat(), "Tetsu still about; sprites back to normal")
	check(present("kuroda"), "beating Tetsu draws Kuroda to the camp")
	check(st.rep.corvo < 0 and st.rep.vila > 0, "reputation moved (corvo %d, vila %d)" % [st.rep.corvo, st.rep.vila])
	check(not pl.frozen, "player free after the duel")
	check(au.current_music == "town_day", "town music comes back after the duel")

	# =====================================================================
	# losing: wake at the tea house, hours later
	# =====================================================================
	st.units = 0
	await teleport(Vector3(-3.0, 0, -10.2))
	await talk()                                   # guarda_1
	await press("interact")
	while main.dialogue.open and not main.dialogue.choosing:
		await press("interact")
	main.dialogue.choose(0)
	await settle()
	check(stage.active and stage.foe == main.npcs["guarda"], "forcing the shrine path starts a duel")
	stage.duel.hero.hp = 1
	stage.duel.foe.atk = 99
	n = 0
	while stage.active and n < 30:
		stage.pick(Duel.Act.OBSERVE)
		await settle()
		n += 1
	check(main.last_duel_result == Duel.Result.LOSE, "lost the duel")
	check(au.played("defeat"), "a mournful phrase for the defeat")
	await settle()
	check(main.dialogue.open and main.dialogue.lines == StoryData.WAKE_LINES, "waking up at the tea house")
	check(st.clock_text() == "Dia 1 · Noite", "out cold until nightfall")
	check(pl.position.distance_to(StoryData.WAKE_POS) < 0.1, "player moved to the tea house")
	while main.dialogue.open:
		await press("interact")
	await settle()
	check(not pl.frozen, "free again")

	# =====================================================================
	# night: the world changes
	# =====================================================================
	check(not present("guarda") and not present("genzo") and present("bandido"), "night: guard and Genzō gone, a thug at the tea house")
	check(main.sun.light_energy < 0.6, "night lighting (sun %.2f)" % main.sun.light_energy)
	check(au.current_music == "town_night" and au.current_amb == "amb_night", "night music and crickets")
	# sneak past the empty shrine path, up to the mine
	st.units = 0
	await teleport(Vector3(-3.0, 0, -11.5))
	await physics(2)
	check(pl.focus == main.npcs["santuario"], "the shrine path is in reach")
	await talk(0)
	check(st.has("aco_negro"), "the mine gives up its black steel")
	check(st.units == 3, "the climb took time (%d units)" % st.units)

	# rest at the inn: next morning
	await teleport(Vector3(1.5, 0, -2.6))
	await physics(2)
	check(pl.focus == main.npcs["estalagem"], "the inn door is in reach")
	await talk(0)
	await settle()
	check(st.clock_text() == "Dia 2 · Manhã" and st.units == 0, "resting moves on to the next morning")
	check(au.played("bell") and au.current_music == "town_day", "a temple bell marks the new day; day music back")
	check(st.hero_hp == st.hero_max_hp(), "rested: full health")
	check(present("akamatsu") and present("guarda") and not present("bandido"), "day 2: the magistrate is in town")
	check(main.sun.light_energy < 1.2, "morning mist lighting")

	# a part of the day runs out by itself
	st.units = GameState.UNITS_PER_PERIOD - 1
	await teleport(Vector3(4.2, 0, 1.3))
	await physics(2)
	await talk()
	await settle()
	check(st.clock_text() == "Dia 2 · Tarde", "spending the last moment rolls on to the afternoon")

	# =====================================================================
	# saving: automatic, and it resumes exactly here
	# =====================================================================
	check(SaveGame.path.ends_with("_teste.cfg"), "tests never touch the player's real save")
	check(SaveGame.exists() and SaveGame.summary() == "Dia 2 · Tarde", "the run was saved automatically (%s)" % SaveGame.summary())
	var saved := SaveGame.read()
	check(saved.state.flags == st.flags and saved.state.rep == st.rep and saved.state.hero_hp == st.hero_hp,
			"the save holds flags, reputation and wounds")
	check((saved.pos as Vector3).distance_to(pl.position) < 0.3, "the save holds where the hero stands")
	check(main._saved.modulate.a > 0.0, "a 'partida gravada' note flashes")
	# the pause menu
	var ev := InputEventAction.new()
	ev.action = "cancel"
	ev.pressed = true
	get_tree().root.push_input(ev)
	await frames(2)
	check(main.pause_menu.is_open and get_tree().paused, "Esc opens the pause menu and pauses the game")
	var px := pl.position
	Input.action_press("move_right")
	for _i in 10:
		await get_tree().process_frame
	Input.action_release("move_right")
	check(pl.position.is_equal_approx(px), "nothing moves while paused")
	main.pause_menu._activate(1)
	check(main.pause_menu._note.text.begins_with("✓"), "'Gravar partida' saves from the menu")
	main.pause_menu._activate(0)
	await frames(2)
	check(not main.pause_menu.is_open and not get_tree().paused, "'Continuar' closes the menu")
	# a fresh state loaded from the save equals the live one
	var copy := GameState.new()
	check(copy.from_dict(SaveGame.read().state) and copy.to_dict() == st.to_dict(), "loading the save restores the same state")

	# =====================================================================
	# an ending: walk out east
	# =====================================================================
	await teleport(Vector3(20.0, 0, 0.25))
	await physics(2)
	check(pl.focus == main.npcs["estrada"], "the east road is in reach")
	await talk(0)
	for _f in 400:
		if main.ending_screen and main.ending_screen._ready_for_input:
			break
		await get_tree().process_frame
	var expect := Endings.evaluate(st, "leave")
	check(main.ended_with == expect and expect != "", "leaving the valley ends the story: %s" % main.ended_with)
	check(Endings.discovered().has(main.ended_with), "the ending is remembered between runs")
	check(main.ending_screen and main.ending_screen._ready_for_input, "the ending card is up")
	check(au.current_music == "ending" and au.current_amb == "" and au.played("ending_gong"), "the ending theme plays")
	check(not SaveGame.exists(), "a finished run leaves no save to continue")

	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
