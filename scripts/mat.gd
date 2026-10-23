class_name Mat
## Shared material helpers. World-space triplanar mapping means any box,
## at any size, gets textures at a constant 32 texels per metre - the same
## density as the sprites, which is what makes HD-2D scenes feel cohesive.

const TEXELS_PER_METRE := 32.0

static var _cache := {}


static func tex(name: String, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "t|%s|%s" % [name, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = load("res://assets/textures/%s.png" % name)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 12.0
	m.uv1_scale = Vector3.ONE * (TEXELS_PER_METRE / t.get_width())
	m.roughness = 1.0
	m.metallic_specular = 0.15
	_cache[key] = m
	return m


static func col(c: Color, rough := 1.0) -> StandardMaterial3D:
	var key := "c|%s|%s" % [c.to_html(), rough]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.15
	_cache[key] = m
	return m


static func glow(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 1.0
	return m


static func unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
