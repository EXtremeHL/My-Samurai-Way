class_name Npc
extends Actor
## Someone (or somewhere) you can talk to. What they say and where they
## stand comes from Story/StoryData; this node only presents it.

var npc_id := ""
var display_name := ""
var data: Dictionary = {}
var home := Vector3.ZERO
var home_facing := "down"
var home_flip := false
var _prompt: Label3D


func setup(id: String, d: Dictionary) -> void:
	npc_id = id
	name = "Npc_" + id
	data = d
	display_name = d.name
	setup_actor(d.sheet)
	home_facing = d.get("facing", "down")
	home_flip = d.get("flip", false)
	facing = home_facing
	flip = home_flip
	_apply_frame()
	_prompt = Label3D.new()
	_prompt.text = "▼"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.pixel_size = 0.006
	_prompt.font_size = 40
	_prompt.outline_size = 12
	_prompt.modulate = Color(1.0, 0.82, 0.35)
	_prompt.outline_modulate = Color(0.08, 0.05, 0.12)
	_prompt.position = Vector3(0, _prompt_height(), 0)
	_prompt.visible = false
	add_child(_prompt)


func is_spot() -> bool:
	return sprite == null


func _prompt_height() -> float:
	return 1.1 if is_spot() else 1.9


## Put the NPC at `pos`, or take him off the map when pos is null.
func place(pos: Variant) -> void:
	var here := pos != null
	visible = here
	if body_shape:
		body_shape.set_deferred("disabled", not here)
	if here:
		home = pos
		position = pos
		return_home()
	else:
		show_prompt(false)


func show_prompt(on: bool) -> void:
	_prompt.visible = on


func _process(_delta: float) -> void:
	if _prompt and _prompt.visible:
		_prompt.position.y = _prompt_height() + sin(Time.get_ticks_msec() * 0.006) * 0.06


func turn_to(p: Vector3) -> void:
	if not is_spot():
		face_dir(p - position)


func return_home() -> void:
	facing = home_facing
	flip = home_flip
	_apply_frame()
