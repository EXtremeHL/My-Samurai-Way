class_name Player
extends Actor
## The wandering ronin. Reads move_* / run / interact actions.

signal interact_requested(target: Npc)

const WALK_SPEED := 3.0
const RUN_SPEED := 5.2
const TALK_RANGE := 1.7

var frozen := false           # true while a dialogue is open
var npcs: Array[Npc] = []
var focus: Npc = null         # NPC currently in talking range
var _last_frame := 0


func _ready() -> void:
	setup_actor("hero")


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if not frozen:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		dir = Vector3(v.x, 0.0, v.y)
	var running := Input.is_action_pressed("run")
	var speed := RUN_SPEED if running else WALK_SPEED
	velocity = dir.normalized() * speed if dir.length() > 0.1 else Vector3.ZERO
	move_and_slide()
	snap_to_ground()
	if dir.length() > 0.1:
		face_dir(dir)
	animate(velocity.length() > 0.1, delta, 1.5 if running else 1.0)
	_footsteps()
	_update_focus()


## A step sound each time a foot lands (frames 1 and 3 of the walk cycle).
func _footsteps() -> void:
	if walk_frame != _last_frame and (walk_frame == 1 or walk_frame == 3):
		if position.y > 0.05:
			GameAudio.sfx("step_wood_%d" % (1 + walk_frame / 3), -8.0, 0.08)
		else:
			GameAudio.sfx("step_%d" % (1 + (walk_frame + int(position.x * 3.0)) % 3), -10.0, 0.1)
	_last_frame = walk_frame


func _update_focus() -> void:
	var best: Npc = null
	var best_d := TALK_RANGE
	if not frozen:
		for n in npcs:
			if not n.visible:
				continue
			var d := Vector2(n.position.x - position.x, n.position.z - position.z).length()
			if d < best_d:
				best_d = d
				best = n
	if best != focus:
		if focus:
			focus.show_prompt(false)
		focus = best
		if focus:
			focus.show_prompt(true)


func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return
	if event.is_action_pressed("interact") and focus:
		get_viewport().set_input_as_handled()
		interact_requested.emit(focus)
