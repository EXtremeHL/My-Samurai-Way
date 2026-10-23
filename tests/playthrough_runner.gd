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

	print("RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
