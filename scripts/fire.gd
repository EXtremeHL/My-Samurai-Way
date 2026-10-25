class_name Campfire
extends Node3D
## A campfire: stone ring and logs are built by the village; this node adds
## the animated flame card, rising embers and a flickering warm light.

const STRIP := preload("res://assets/sprites/fx_fire.png")
const SHADER := preload("res://shaders/fire.gdshader")

var light: OmniLight3D
var base_energy := 1.8
var _t := 0.0


func _ready() -> void:
	for k in 2:                         # two cards, offset in time, for a fuller fire
		var card := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(24, 34) * PixelSprite.PIXEL * (1.0 - 0.25 * k)
		q.center_offset = Vector3(0, q.size.y * 0.5, 0)
		card.mesh = q
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("strip", STRIP)
		m.set_shader_parameter("phase", 3.0 * k)
		m.set_shader_parameter("fps", 10.0 + 2.0 * k)
		card.material_override = m
		card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		card.position = Vector3(0.12 * (k * 2 - 1), 0.12, 0.05 * k)
		add_child(card)

	var embers := CPUParticles3D.new()
	embers.amount = 14
	embers.lifetime = 1.8
	embers.preprocess = 2.0
	embers.position = Vector3(0, 0.5, 0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.18
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0, 0.6, 0)
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 0.9
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	embers.scale_amount_curve = curve
	var em := QuadMesh.new()
	em.size = Vector2.ONE * PixelSprite.PIXEL * 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.2)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.15)
	mat.emission_energy_multiplier = 3.0
	em.material = mat
	embers.mesh = em
	add_child(embers)

	light = OmniLight3D.new()
	light.position = Vector3(0, 0.8, 0)
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = 6.0
	light.light_energy = base_energy
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	# layered sines read as a flicker without per-frame randomness
	var f := 0.82 + 0.1 * sin(_t * 9.1) + 0.06 * sin(_t * 23.7 + 1.3) + 0.04 * sin(_t * 41.0)
	light.light_energy = base_energy * f
