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


func hold(action: String, frames: int) -> Array:
	## Holds an action; returns the walk frames seen while it was held.
	var seen := []
	Input.action_press(action)
	for _f in frames:
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


func talk_through() -> void:
	await press("interact")
	var n := 0
	while main.dialogue.open and n < 40:
		await press("interact")
		n += 1
	await physics(2)


func wait_duel_input() -> void:
	## Waits until the duel wants input again (or is over).
	var stage: DuelStage = main.stage
	for _f in 4000:
		await get_tree().process_frame
		if not stage.active and (not main.player.frozen or main.dialogue.open):
			return
		if stage.active and not stage.busy:
			return


func teleport(p: Vector3) -> void:
	main.player.position = p
	main.player.velocity = Vector3.ZERO
	main.snap_camera()
	await physics(3)


func run(m: Node) -> void:
	main = m
	await physics(5)
	var pl: Player = main.player

	# --- the town is populated ---
	check(main.npcs.size() == NpcData.TOWN.size(), "all %d NPCs spawned" % NpcData.TOWN.size())
	check(pl.position.distance_to(NpcData.PLAYER_START) < 0.05, "player at start position")

	# --- walking right moves the player, animates, faces side ---
	var x0 := pl.position.x
	var frames := await hold("move_right", 40)
	check(pl.position.x > x0 + 1.5, "walking right moves player (%.2f -> %.2f)" % [x0, pl.position.x])
	check(frames.size() >= 3, "walk cycle animates (frames seen %s)" % [frames])
	check(pl.facing == "side" and not pl.flip, "faces right after walking right")
	check(pl.walk_frame == 0, "returns to idle frame when stopping")

	# --- walking left flips the side sprite ---
	await hold("move_left", 10)
	check(pl.facing == "side" and pl.flip, "faces left (flipped) after walking left")

	# --- walking down faces the camera ---
	await teleport(Vector3(0.0, 0, 0.0))
	await hold("move_down", 10)
	check(pl.facing == "down", "faces down after walking down")

	# --- running is faster than walking ---
	await teleport(Vector3(-2.0, 0, 0.5))
	await hold("move_right", 30)
	var walked := pl.position.x + 2.0
	await teleport(Vector3(-2.0, 0, 0.5))
	Input.action_press("run")
	await hold("move_right", 30)
	Input.action_release("run")
	var ran := pl.position.x + 2.0
	check(ran > walked * 1.4, "running covers more ground (%.2f vs %.2f)" % [ran, walked])

	# --- houses are solid: walking into the inn stops at its wall ---
	await teleport(Vector3(1.5, 0, 0.0))
	await hold("move_up", 150)
	check(pl.position.z > -3.75, "inn wall blocks the player (z=%.2f)" % pl.position.z)
	check(pl.position.z < -2.5, "player actually reached the inn wall (z=%.2f)" % pl.position.z)

	# --- the stream blocks, except on the bridge ---
	await teleport(Vector3(10.0, 0, 3.6))
	await hold("move_right", 90)
	check(pl.position.x < 11.3, "stream blocks the player off the bridge (x=%.2f)" % pl.position.x)

	await teleport(Vector3(9.6, 0, 0.25))
	var max_y := 0.0
	Input.action_press("move_right")
	for _f in 150:
		await get_tree().physics_frame
		max_y = maxf(max_y, pl.position.y)
	Input.action_release("move_right")
	await physics(2)
	check(pl.position.x > 14.8, "player crosses the bridge (x=%.2f)" % pl.position.x)
	check(max_y > 0.25, "player climbs the bridge arch (max y=%.2f)" % max_y)
	check(absf(pl.position.y) < 0.01, "player back on the ground after the bridge")

	# --- world bounds hold ---
	await teleport(Vector3(0.0, 0, 4.0))
	await hold("move_down", 120)
	check(pl.position.z < Village.BOUNDS.end.y, "southern bound holds (z=%.2f)" % pl.position.z)

	# --- camera follows the player ---
	await teleport(Vector3(-6.0, 0, 0.5))
	await physics(90)
	var expect: Vector3 = main._focus_point() + main.CAM_OFFSET
	check(main.cam.position.distance_to(expect) < 0.3, "camera settles on the player")

	# --- talking to Oyuki ---
	var oyuki: Npc = main.npcs["oyuki"]
	await teleport(Vector3(-7.3, 0, -0.7))
	await physics(2)
	check(pl.focus == oyuki, "Oyuki is in talking range")
	check(oyuki._prompt.visible, "talk marker shown over Oyuki")
	await get_tree().process_frame
	check(main.hint.text.contains("Oyuki"), "HUD hint names Oyuki ('%s')" % main.hint.text)
	await press("interact")
	check(main.dialogue.open, "interact opens the dialogue")
	check(main.dialogue.current_speaker() == "Oyuki", "first speaker is Oyuki")
	check(not oyuki._prompt.visible, "prompt hidden while talking")
	await get_tree().process_frame
	check(main.hint.text == "", "HUD hint hidden while talking")
	check(oyuki.facing == "down", "Oyuki turns toward the player")
	var before := pl.position
	await hold("move_left", 20)
	check(pl.position.distance_to(before) < 0.01, "player can't walk during dialogue")
	var presses := 0
	while main.dialogue.open and presses < 40:
		await press("interact")
		presses += 1
	check(not main.dialogue.open, "dialogue closes after its lines (%d presses)" % presses)
	check(presses >= oyuki.lines_first.size(), "typewriter: a press finishes a line before advancing")
	check(oyuki.times_talked == 1, "talk counted")
	check(not pl.frozen, "player unfrozen after dialogue")

	# --- second conversation uses the 'again' lines ---
	await physics(3)
	await press("interact")
	check(main.dialogue.open and main.dialogue.lines == oyuki.lines_again, "second talk uses follow-up lines")
	while main.dialogue.open:
		await press("interact")

	# --- interact far from anyone does nothing ---
	await teleport(Vector3(2.0, 0, 3.0))
	await physics(2)
	await press("interact")
	check(not main.dialogue.open and pl.focus == null, "interact with nobody nearby does nothing")

	# --- NPCs are solid ---
	await teleport(Vector3(-4.9, 0, 0.2))
	await hold("move_up", 60)
	check(pl.position.z > -1.4 + 0.3, "can't walk through the ronin (z=%.2f)" % pl.position.z)


	# =====================================================================
	# DUELS
	# =====================================================================
	main.anim_speed = 0.02
	main.duel_seed = 4242
	var stage: DuelStage = main.stage
	var tetsu: Npc = main.npcs["tetsu"]

	# --- the challenge comes through a dialogue choice ---
	await teleport(Vector3(-4.9, 0, -0.6))
	await talk_through()                       # first conversation
	check(tetsu.times_talked == 1, "talked to Tetsu once")
	await press("interact")                    # second: ends in a choice
	var guard_presses := 0
	while main.dialogue.open and not main.dialogue.choosing and guard_presses < 30:
		await press("interact")
		guard_presses += 1
	check(main.dialogue.choosing, "Tetsu's second talk ends in a choice")
	await press("move_down")
	check(main.dialogue.choice_index == 1, "choice cursor moves down")
	await press("move_up")
	check(main.dialogue.choice_index == 0, "choice cursor moves up")
	await press("interact")
	await wait_duel_input()
	check(stage.active, "choosing 'Desembainhar' starts the duel")
	check(pl.in_combat() and tetsu.in_combat(), "both fighters switch to combat sprites")
	check(main.cam.global_position.distance_to(stage.center) < 9.0, "camera moves in to frame the duel")
	check(absf(pl.position.x - (stage.center.x - DuelStage.SPACING)) < 0.05, "hero walked to his mark")
	check(main.hint.text == "", "exploration hint hidden during the duel")

	# --- real input on the menu: first item is a quick strike ---
	var turn0 := stage.duel.turn
	await press("interact")
	await wait_duel_input()
	check(stage.duel.turn == turn0 + 1, "pressing E on the menu plays a turn")

	# --- a boca resolves without ending the turn and costs ki ---
	stage.duel.hero.ki = 50
	var t1 := stage.duel.turn
	stage._on_picked("boca_menu", 0)
	check(stage.in_boca_menu, "boca submenu opens")
	check(stage.ui.menu_box.get_child_count() == Bocas.ORDER.size() + 1, "submenu lists every boca + back")
	await press("cancel")
	check(not stage.in_boca_menu, "Esc backs out of the boca menu")
	stage.pick_boca(Bocas.Cat.TROCA)
	await wait_duel_input()
	check(stage.duel.turn == t1 and stage.duel.hero.ki == 50 - Duel.BOCA_KI, "boca: same turn, -%d ki" % Duel.BOCA_KI)
	check(stage.duel.foe.times_heard(Bocas.Cat.TROCA) == 1, "Tetsu heard the troça")
	check(not stage.duel.can_boca(), "boca option locked for the rest of the turn")
	var boca_btn: Button = stage.ui.menu_box.get_child(5)
	check(boca_btn.disabled, "Boca button greyed out after use")

	# --- finish him ---
	stage.duel.foe.hp = 1
	var guard_turns := 0
	while stage.active and guard_turns < 20:
		stage.pick(Duel.Act.TECH if stage.duel.can_use(Duel.Act.TECH) else Duel.Act.LIGHT)
		await wait_duel_input()
		guard_turns += 1
	check(not stage.active, "duel ends")
	check(main.last_duel_result == Duel.Result.WIN, "won the duel (result %d)" % main.last_duel_result)
	await physics(10)
	check(not pl.in_combat() and not tetsu.in_combat(), "fighters back to walking sprites")
	check(tetsu.state == "vencido" and tetsu.lines() == NpcData.TOWN.tetsu.beaten, "beaten Tetsu has new lines")
	check(tetsu.display_name == "Tetsu", "Tetsu's name is now known")
	check(not pl.frozen, "player free after the duel")
	var px := pl.position.x
	await hold("move_left", 15)
	check(pl.position.x < px - 0.3, "player can walk after the duel")

	# --- losing: wake up at the tea house ---
	var guarda: Npc = main.npcs["guarda"]
	await teleport(Vector3(-3.0, 0, -10.2))
	await talk_through()
	await press("interact")
	while main.dialogue.open and not main.dialogue.choosing:
		await press("interact")
	main.dialogue.choose(0)
	await wait_duel_input()
	check(stage.active and stage.foe == guarda, "forcing the shrine path starts a duel with the guard")
	stage.duel.hero.hp = 1
	stage.duel.foe.atk = 99
	var lose_turns := 0
	while stage.active and lose_turns < 30:
		stage.pick(Duel.Act.OBSERVE)
		await wait_duel_input()
		lose_turns += 1
	check(main.last_duel_result == Duel.Result.LOSE, "lost the duel (result %d)" % main.last_duel_result)
	for _f in 400:
		if main.dialogue.open:
			break
		await get_tree().process_frame
	check(main.dialogue.open and main.dialogue.lines == NpcData.WAKE_LINES, "waking up at the tea house")
	check(pl.position.distance_to(NpcData.WAKE_POS) < 0.1, "player moved to the tea house")
	while main.dialogue.open:
		await press("interact")
	for _f in 60:
		await get_tree().process_frame
	check(not pl.frozen and guarda.state == "", "free again; the guard still stands")

	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
