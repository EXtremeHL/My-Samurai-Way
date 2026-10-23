class_name PixelSprite
extends MeshInstance3D
## A camera-facing pixel-art card that is lit, casts and receives shadows.
## The HD-2D camera has a fixed yaw, so cards stay aligned to the XY plane
## (facing +Z) instead of billboarding - that keeps shadows stable.

const PIXEL := 1.0 / 30.0            # metres per texel (48 px character ~ 1.6 m)
const SHADER := preload("res://shaders/sprite_lit.gdshader")

var cols := 1
var rows := 1
var frame_w := 0
var frame_h := 0
var _mat: ShaderMaterial


static func make(path: String, fw := 0, fh := 0) -> PixelSprite:
	var s := PixelSprite.new()
	s.setup(load(path) as Texture2D, fw, fh)
	return s


func setup(tex: Texture2D, fw: int, fh: int) -> void:
	frame_w = fw if fw > 0 else tex.get_width()
	frame_h = fh if fh > 0 else tex.get_height()
	cols = tex.get_width() / frame_w
	rows = tex.get_height() / frame_h
	var q := QuadMesh.new()
	q.size = Vector2(frame_w, frame_h) * PIXEL
	q.center_offset = Vector3(0.0, frame_h * PIXEL * 0.5, 0.0)
	mesh = q
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("sheet", tex)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	set_frame(0, 0)


func set_frame(col: int, row: int) -> void:
	_mat.set_shader_parameter("region", Vector4(
		float(col) / cols, float(row) / rows, 1.0 / cols, 1.0 / rows))


func set_flip(on: bool) -> void:
	_mat.set_shader_parameter("flip_h", 1.0 if on else 0.0)


func set_flash(v: float) -> void:
	_mat.set_shader_parameter("flash", v)


func set_tint(c: Color) -> void:
	_mat.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
