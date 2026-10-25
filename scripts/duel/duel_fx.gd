class_name DuelFX
extends Node
## Duel juice: animated sword trails, steel sparks, hit-stop, camera punch
## and shake, screen flashes and a slow-motion KO. Pure presentation, owned by
## DuelStage; every effect is fire-and-forget and cleans up after itself.
##
## All timings go through `speed` (main.anim_speed) so the fast-forwarded
## tests stay fast, and hit-stop/slow-mo always restore Engine.time_scale.

const PIXEL := 1.0 / 30.0
const SLASH := {
	Duel.Act.LIGHT: preload("res://assets/sprites/fx_slash_light.png"),
	Duel.Act.HEAVY: preload("res://assets/sprites/fx_slash_heavy.png"),
	Duel.Act.TECH: preload("res://assets/sprites/fx_slash_tech.png"),
}
const SLASH_FRAMES := 5
const SPARK := preload("res://assets/sprites/fx_spark.png")
const HIT := preload("res://assets/sprites/fx_hit.png")

var cam: Camera3D
var speed := 1.0
var base_fov := 34.0
var fired: Array[String] = []        # effects fired, newest last (tests read it)
var _flash: ColorRect
var _shake_left := 0.0
var _shake_amp := 0.0
var _stop_token := 0


func setup(camera: Camera3D, anim_speed: float) -> void:
	cam = camera
	speed = anim_speed
	base_fov = camera.fov
	var layer := CanvasLayer.new()
	layer.layer = 3                   # over the 3D scene, under the duel UI (5)
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.fov = base_fov


# ---------------------------------------------------------------------------
# sword trail
# ---------------------------------------------------------------------------
## Sweeping arc on `target`, coming from the left (hero) or right (foe).
func slash(target: Node3D, kind: int, from_right: bool) -> void:
	fired.append("slash_%d" % kind)
	var s := Sprite3D.new()
	s.texture = SLASH.get(kind, SLASH[Duel.Act.LIGHT])
	s.hframes = SLASH_FRAMES
	s.pixel_size = PIXEL * (1.55 if kind == Duel.Act.TECH else 1.3)
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 2
	s.flip_h = from_right
	# HDR-bright so it blooms (heavier blows glow more)
	var glow := {Duel.Act.LIGHT: 1.15, Duel.Act.HEAVY: 1.35, Duel.Act.TECH: 1.6}.get(kind, 1.15) as float
	s.modulate = Color(glow, glow, glow, 1.0)
	s.position = target.global_position + Vector3(0.25 if from_right else -0.25, 0.95, 0.35)
	add_child(s)
	var t := create_tween()
	t.tween_method(func(f: float): s.frame = mini(SLASH_FRAMES - 1, int(f)), 0.0, float(SLASH_FRAMES), 0.2 * speed)
	t.tween_property(s, "modulate:a", 0.0, 0.12 * speed)
	t.tween_callback(s.queue_free)


## Impact star on contact.
func impact(target: Node3D, big: bool) -> void:
	fired.append("impact")
	var hit := Sprite3D.new()
	hit.texture = HIT
	hit.pixel_size = PIXEL
	hit.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	hit.shaded = false
	hit.no_depth_test = true
	hit.render_priority = 3
	hit.modulate = Color(2.2, 2.0, 1.6)
	hit.position = target.global_position + Vector3(0.0, 0.95, 0.25)
	add_child(hit)
	var t := create_tween().set_parallel(true)
	var k := 2.4 if big else 1.6
	t.tween_property(hit, "scale", Vector3(k, k, 1.0), 0.16 * speed).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(hit, "modulate:a", 0.0, 0.22 * speed)
	t.chain().tween_callback(hit.queue_free)


# ---------------------------------------------------------------------------
# particles
# ---------------------------------------------------------------------------
## A one-shot burst of pixel sparks. `steel` = orange-white clash sparks,
## otherwise cold blue-white (a block / the technique).
func sparks(at: Vector3, amount: int, steel := true, up := 1.0) -> void:
	fired.append("sparks")
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45
	p.position = at
	p.direction = Vector3(0, up, 0)
	p.spread = 70.0
	p.initial_velocity_min = 2.2
	p.initial_velocity_max = 4.6
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	if steel:
		grad.set_color(0, Color(3.0, 2.8, 2.2))
		grad.set_color(1, Color(2.0, 0.7, 0.2, 0.0))
	else:
		grad.set_color(0, Color(2.6, 2.9, 3.2))
		grad.set_color(1, Color(0.5, 0.9, 2.0, 0.0))
	p.color_ramp = grad
	var m := QuadMesh.new()
	m.size = Vector2.ONE * PIXEL * 4.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = SPARK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 4
	m.material = mat
	p.mesh = m
	p.speed_scale = 1.0 / maxf(speed, 0.01)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0 * speed + 0.1, true, false, true).timeout.connect(p.queue_free)


## Dust kicked up at the feet (heavy lunges, a body hitting the ground).
func dust(at: Vector3, amount := 10) -> void:
	fired.append("dust")
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.position = at + Vector3(0, 0.05, 0.1)
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.6
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.62, 0.5, 0.75))
	grad.set_color(1, Color(0.72, 0.62, 0.5, 0.0))
	p.color_ramp = grad
	var m := QuadMesh.new()
	m.size = Vector2.ONE * PIXEL * 3.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	p.speed_scale = 1.0 / maxf(speed, 0.01)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2 * speed + 0.1, true, false, true).timeout.connect(p.queue_free)


# ---------------------------------------------------------------------------
# time and camera
# ---------------------------------------------------------------------------
## Freeze the action for a heartbeat on contact, so the blow lands.
func hitstop(secs: float) -> void:
	fired.append("hitstop")
	_stop_token += 1
	var token := _stop_token
	Engine.time_scale = 0.05
	await get_tree().create_timer(secs * speed, true, false, true).timeout
	if token == _stop_token:
		Engine.time_scale = 1.0


## Slow motion (the final blow).
func slowmo(scale: float, secs: float) -> void:
	fired.append("slowmo")
	_stop_token += 1
	var token := _stop_token
	Engine.time_scale = scale
	await get_tree().create_timer(secs * speed, true, false, true).timeout
	if token == _stop_token:
		Engine.time_scale = 1.0


## Decaying, frame-rate independent shake (replaces any weaker one running).
func shake(amp: float, secs := 0.3) -> void:
	fired.append("shake")
	if amp >= _shake_amp * (_shake_left / maxf(secs, 0.001)):
		_shake_amp = amp
		_shake_left = secs * speed


## Quick zoom in and back out on a heavy blow.
func punch(strength := 0.08) -> void:
	fired.append("punch")
	var t := create_tween()
	t.tween_property(cam, "fov", base_fov * (1.0 - strength), 0.05 * speed).set_trans(Tween.TRANS_QUAD)
	t.tween_property(cam, "fov", base_fov, 0.35 * speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Full-screen flash (white for the technique, red for a crushing blow).
func flash(color: Color, strength := 0.45, secs := 0.25) -> void:
	fired.append("flash")
	_flash.color = Color(color, strength)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, secs * speed)


func _process(delta: float) -> void:
	if not cam:
		return
	if _shake_left > 0.0:
		# real time, so the shake still decays during hit-stop
		var d := delta / maxf(Engine.time_scale, 0.001)
		_shake_left = maxf(0.0, _shake_left - d)
		var k := _shake_amp * (_shake_left / maxf(0.3 * speed, 0.001))
		var tm := Time.get_ticks_msec() * 0.001
		cam.h_offset = k * sin(tm * 71.0) * 0.6
		cam.v_offset = k * sin(tm * 53.0 + 1.7) * 0.6
		if _shake_left == 0.0:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			_shake_amp = 0.0
