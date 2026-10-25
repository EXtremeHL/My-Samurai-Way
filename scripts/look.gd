class_name Look
## Lighting / post-processing presets. HD-2D lives or dies here: the same
## diorama goes from storybook afternoon to moody night by changing only sun,
## sky, fog, bloom and depth of field.

const VARIANTS := ["dourado", "neblina", "noite"]
const COMPAT_EXPOSURE := {"dourado": 0.78, "neblina": 0.8, "noite": 1.0}
const COMPAT_BRIGHTNESS := {"dourado": 0.86, "neblina": 0.88, "noite": 1.0}
const COMPAT_SATURATION := {"dourado": 0.92, "neblina": 0.85, "noite": 0.85}


static func make_camera_attributes() -> CameraAttributesPractical:
	var a := CameraAttributesPractical.new()
	a.dof_blur_far_enabled = true
	a.dof_blur_far_distance = 24.0
	a.dof_blur_far_transition = 14.0
	a.dof_blur_near_enabled = true
	a.dof_blur_near_distance = 12.5
	a.dof_blur_near_transition = 3.5
	a.dof_blur_amount = 0.16
	return a


static func apply(variant: String, env: Environment, sun: DirectionalLight3D, village: Village) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.3)
	env.fog_enabled = true
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.6

	var lantern := 0.0
	var lantern_emit := 0.4
	var petals := false
	var flies := false

	match variant:
		"dourado":
			# late-afternoon gold, long warm shadows, falling sakura
			sun.rotation_degrees = Vector3(-32, -38, 0)
			sun.light_color = Color(1.0, 0.84, 0.62)
			sun.light_energy = 1.45
			sun.shadow_opacity = 0.82
			sky_mat.sky_top_color = Color(0.32, 0.5, 0.82)
			sky_mat.sky_horizon_color = Color(0.98, 0.8, 0.6)
			sky_mat.ground_horizon_color = Color(0.85, 0.7, 0.55)
			sky_mat.ground_bottom_color = Color(0.3, 0.26, 0.22)
			env.ambient_light_color = Color(0.62, 0.52, 0.48)
			env.ambient_light_energy = 0.75
			env.fog_light_color = Color(0.95, 0.78, 0.6)
			env.fog_density = 0.0025
			env.fog_sun_scatter = 0.2
			env.volumetric_fog_enabled = false
			env.glow_intensity = 0.45
			env.glow_bloom = 0.02
			env.glow_hdr_threshold = 1.1
			env.adjustment_saturation = 1.15
			env.adjustment_contrast = 1.12
			env.adjustment_brightness = 1.0
			lantern = 0.25
			petals = true
		"neblina":
			# cold dawn mist, soft low light, muted palette
			sun.rotation_degrees = Vector3(-16, 48, 0)
			sun.light_color = Color(0.86, 0.92, 1.0)
			sun.light_energy = 0.95
			sun.shadow_opacity = 0.6
			sky_mat.sky_top_color = Color(0.55, 0.64, 0.76)
			sky_mat.sky_horizon_color = Color(0.86, 0.88, 0.9)
			sky_mat.ground_horizon_color = Color(0.8, 0.82, 0.84)
			sky_mat.ground_bottom_color = Color(0.3, 0.32, 0.34)
			env.ambient_light_color = Color(0.6, 0.66, 0.75)
			env.ambient_light_energy = 0.9
			env.fog_light_color = Color(0.78, 0.82, 0.88)
			env.fog_density = 0.0035
			env.fog_sun_scatter = 0.4
			env.fog_height = 0.4
			env.fog_height_density = 0.22
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.0065
			env.volumetric_fog_albedo = Color(0.85, 0.88, 0.95)
			env.volumetric_fog_length = 40.0
			env.glow_intensity = 0.5
			env.glow_bloom = 0.12
			env.glow_hdr_threshold = 1.0
			env.adjustment_saturation = 0.95
			env.adjustment_contrast = 1.06
			env.adjustment_brightness = 1.0
			lantern = 0.0
			lantern_emit = 0.15
		"noite":
			# moonlit blue with warm lantern pools and fireflies
			sun.rotation_degrees = Vector3(-50, 30, 0)
			sun.light_color = Color(0.5, 0.6, 0.95)
			sun.light_energy = 0.38
			sun.shadow_opacity = 0.75
			sky_mat.sky_top_color = Color(0.03, 0.05, 0.14)
			sky_mat.sky_horizon_color = Color(0.12, 0.16, 0.3)
			sky_mat.ground_horizon_color = Color(0.08, 0.1, 0.18)
			sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
			env.ambient_light_color = Color(0.2, 0.26, 0.45)
			env.ambient_light_energy = 0.55
			env.fog_light_color = Color(0.1, 0.14, 0.26)
			env.fog_density = 0.012
			env.fog_sun_scatter = 0.0
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.012
			env.volumetric_fog_albedo = Color(0.7, 0.75, 1.0)
			env.volumetric_fog_length = 30.0
			env.glow_intensity = 1.0
			env.glow_bloom = 0.15
			env.glow_hdr_threshold = 0.7
			env.adjustment_saturation = 1.1
			env.adjustment_contrast = 1.08
			env.adjustment_brightness = 1.0
			lantern = 2.4
			lantern_emit = 3.2
			flies = true
		_:
			push_error("unknown look variant %s" % variant)

	for l in village.lantern_lights:
		l.light_energy = lantern
		l.visible = lantern > 0.0
		l.light_volumetric_fog_energy = 2.0
	village.lantern_mat.emission_energy_multiplier = lantern_emit
	if village.campfire:
		village.campfire.base_energy = 2.6 if variant == "noite" else 1.6
	village.petals.emitting = petals
	village.petals.visible = petals
	village.fireflies.emitting = flies
	village.fireflies.visible = flies

	# The web build always runs the Compatibility renderer, which has no SSAO
	# and lights the day presets noticeably brighter and flatter. Measured
	# against Forward+ captures (tools: --capture with both renderers) and
	# pulled back so the browser version looks like the desktop one.
	env.tonemap_exposure = 1.0
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		env.tonemap_exposure = COMPAT_EXPOSURE.get(variant, 1.0)
		env.adjustment_saturation *= COMPAT_SATURATION.get(variant, 1.0)
		env.adjustment_brightness *= COMPAT_BRIGHTNESS.get(variant, 1.0)
