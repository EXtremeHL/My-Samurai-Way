class_name Actor
extends CharacterBody3D
## Anything that walks: the player and NPCs. Owns a PixelSprite with the
## 5x3 character sheet (cols: idle, walk1..4 / rows: down, up, side).

const ROW := {"down": 0, "up": 1, "side": 2}
const WALK_FPS := 9.0

var sprite: PixelSprite
var facing := "down"
var flip := false
var walk_frame := 0          # 0 idle, 1..4 walking
var _anim_t := 0.0


func setup_actor(sheet_id: String) -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.4
	cs.shape = cap
	cs.position.y = 0.75
	add_child(cs)
	sprite = PixelSprite.make("res://assets/sprites/char_%s.png" % sheet_id, 32, 48)
	add_child(sprite)
	_apply_frame()


## Face a world direction (x/z). Side frames face right; flip for left.
func face_dir(d: Vector3) -> void:
	if d.length_squared() < 0.0001:
		return
	if absf(d.x) > absf(d.z) * 1.15:
		facing = "side"
		flip = d.x < 0.0
	else:
		facing = "down" if d.z > 0.0 else "up"
		flip = false
	_apply_frame()


func animate(moving: bool, delta: float, speed_scale := 1.0) -> void:
	if moving:
		_anim_t += delta * WALK_FPS * speed_scale
		walk_frame = 1 + int(_anim_t) % 4
	else:
		_anim_t = 0.0
		walk_frame = 0
	_apply_frame()


func snap_to_ground() -> void:
	position.y = Village.ground_height(position)


func _apply_frame() -> void:
	if sprite:
		sprite.set_frame(walk_frame, ROW[facing])
		sprite.set_flip(flip)
