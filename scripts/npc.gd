class_name Npc
extends Actor
## A townsperson: stands (or paces) at a post and has dialogue.

var npc_id := ""
var display_name := ""
var data: Dictionary = {}
var state := ""                 # "" | "vencido"
var home := Vector3.ZERO
var lines_first: Array = []
var lines_again: Array = []
var times_talked := 0
var home_facing := "down"
var home_flip := false
var _prompt: Label3D


func setup(id: String, data: Dictionary) -> void:
	npc_id = id
	name = "Npc_" + id
	self.data = data
	display_name = data.name
	home = data.pos
	lines_first = data.first
	lines_again = data.get("again", data.first)
	position = data.pos
	setup_actor(data.sheet)
	home_facing = data.get("facing", "down")
	home_flip = data.get("flip", false)
	facing = home_facing
	flip = home_flip
	_apply_frame()
	# collide as a solid obstacle but never get pushed
	set_collision_layer_value(1, true)
	_prompt = Label3D.new()
	_prompt.text = "▼"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.pixel_size = 0.006
	_prompt.font_size = 40
	_prompt.outline_size = 12
	_prompt.modulate = Color(1.0, 0.82, 0.35)
	_prompt.outline_modulate = Color(0.08, 0.05, 0.12)
	_prompt.position = Vector3(0, 1.9, 0)
	_prompt.visible = false
	add_child(_prompt)


func lines() -> Array:
	if state == "vencido" and data.has("beaten"):
		return data.beaten
	return lines_first if times_talked == 0 else lines_again


func show_prompt(on: bool) -> void:
	_prompt.visible = on


func _process(_delta: float) -> void:
	if _prompt and _prompt.visible:
		_prompt.position.y = 1.9 + sin(Time.get_ticks_msec() * 0.006) * 0.06


func turn_to(p: Vector3) -> void:
	face_dir(p - position)


func return_home() -> void:
	facing = home_facing
	flip = home_flip
	_apply_frame()
