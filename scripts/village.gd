class_name Village
extends Node3D
## Builds the first valley location - the post town of Kurogane-juku - out of
## textured boxes (architecture) and lit pixel cards (people, trees).
## All placement is hand-authored or seeded so every run is identical.

var lantern_lights: Array[OmniLight3D] = []
var lantern_mat: StandardMaterial3D
var water_mat: ShaderMaterial
var shoji_mat: StandardMaterial3D        # glows from inside after dark
var roof_mats: Array[StandardMaterial3D] = []
var halo_mat: StandardMaterial3D         # soft additive halo around every lantern
var petals: CPUParticles3D
var fireflies: CPUParticles3D
var campfire: Campfire
var fires: Array[Campfire] = []          # campfire + braziers
## Lights mirrored in the stream: [world position, strength]
var reflected: Array = []
var night := 0.0


func build() -> void:
	lantern_mat = Mat.glow(Color(1.0, 0.45, 0.25), 1.0)
	halo_mat = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = preload("res://assets/sprites/fx_halo.png")
	halo_mat.albedo_color = Color(1.0, 0.62, 0.32, 0.0)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.disable_receive_shadows = true
	shoji_mat = Mat.tex("shoji").duplicate()
	shoji_mat.emission_enabled = true
	shoji_mat.emission_texture = shoji_mat.albedo_texture
	shoji_mat.emission = Color(1.0, 0.7, 0.4)
	shoji_mat.emission_energy_multiplier = 0.0
	_ground()
	_stream_and_bridge()
	_backdrop()
	_house(Vector3(-8.5, 0, -5.5), Vector3(5.0, 2.6, 4.0), Color(0.86, 0.80, 0.84), "teahouse")
	_house(Vector3(1.5, 0, -5.5), Vector3(5.0, 2.8, 4.0), Color(0.80, 0.86, 1.0), "inn")
	_house(Vector3(7.9, 0, -5.2), Vector3(4.2, 2.4, 3.6), Color(1.0, 0.95, 0.9), "shop")
	_house(Vector3(-13.5, 0, 3.0), Vector3(4.0, 2.4, 5.0), Color(0.9, 0.9, 0.95), "side", true)
	_torii(Vector3(-3.0, 0, -13.0))
	_teahouse_front(Vector3(-8.5, 0, -2.3))
	_stone_lantern(Vector3(-4.4, 0, -2.4))
	_stone_lantern(Vector3(-1.6, 0, -2.4))
	# lanterns on both banks, upstream: they shine in the water at night
	_stone_lantern(Vector3(10.55, 0, -4.4))
	_stone_lantern(Vector3(14.45, 0, -7.2))
	reflected.append([Vector3(11.5, 0, -4.4), 0.9])
	reflected.append([Vector3(13.5, 0, -7.2), 0.8])
	_well(Vector3(5.2, 0, 3.4))
	_camp()
	_props()
	_foliage()
	_bounds()
	_particles()


## Day -> night: 0 .. 1. Everything that changes after dark (besides the
## light rig in Look) goes through here.
func set_night(k: float) -> void:
	night = k
	water_mat.set_shader_parameter("night", k)
	var arr := []
	for i in 6:
		if i < reflected.size():
			var r: Array = reflected[i]
			arr.append(Vector4(r[0].x, r[0].y, r[0].z, r[1]))
		else:
			arr.append(Vector4.ZERO)
	water_mat.set_shader_parameter("lights", arr)
	shoji_mat.emission_energy_multiplier = 0.75 * k
	halo_mat.albedo_color.a = 0.55 * k
	for m in roof_mats:
		# moonlight sheen on the glazed tiles
		m.roughness = lerpf(1.0, 0.42, k)
		m.metallic_specular = lerpf(0.15, 0.6, k)
	for f in fires:
		f.base_energy = lerpf(1.4, 2.6, k)


# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------
func box(pos: Vector3, size: Vector3, mat: Material, rot_deg := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot_deg
	(parent if parent else self).add_child(m)
	return m


func cyl(pos: Vector3, r_top: float, r_bot: float, h: float, mat: Material, segs := 10, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	m.mesh = c
	m.material_override = mat
	m.position = pos
	(parent if parent else self).add_child(m)
	return m


## Invisible collider; footprint `size` (x, z) centred at `pos`, 2 m tall.
func solid(pos: Vector3, size: Vector2, parent: Node3D = null, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 2.0, size.y)
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3(pos.x, 1.0, pos.z)
	body.rotation_degrees.y = rot_y
	(parent if parent else self).add_child(body)
	return body


## Walkable surface height: flat ground, except the arched bridge deck.
static func ground_height(p: Vector3) -> float:
	if p.z < -1.2 or p.z > 1.7:
		return 0.0
	var dx := absf(p.x - 12.5)
	if dx > 2.3:
		return 0.0
	var t := clampf((p.x - 12.5) / 1.8, -1.0, 1.0)
	var deck := 0.34 - t * t * 0.18
	if dx > 1.9:
		deck *= (2.3 - dx) / 0.4      # ramp down onto the road
	return deck


func sprite(path: String, pos: Vector3, scale_f := 1.0, fw := 0, fh := 0) -> PixelSprite:
	var s := PixelSprite.make(path, fw, fh)
	s.position = pos
	s.scale = Vector3.ONE * scale_f
	add_child(s)
	return s


# ---------------------------------------------------------------------------
# terrain
# ---------------------------------------------------------------------------
## Soft additive glow card around a light source (visible at night only).
func halo(pos: Vector3, size: float, parent: Node3D = null) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	m.mesh = q
	m.material_override = halo_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	(parent if parent else self).add_child(m)


## A box split into tiles of about `tile` metres. The web build's
## Compatibility renderer lights each object with at most a few lights, so one
## huge ground mesh silently loses most of the lantern pools; small tiles each
## only meet the lanterns near them. Triplanar world UVs keep it seamless.
func tiled_box(pos: Vector3, size: Vector3, mat: Material, tile := 6.0) -> void:
	var nx := maxi(1, ceili(size.x / tile))
	var nz := maxi(1, ceili(size.z / tile))
	var sx := size.x / nx
	var sz := size.z / nz
	for ix in nx:
		for iz in nz:
			var c := pos + Vector3(-size.x * 0.5 + sx * (ix + 0.5), 0, -size.z * 0.5 + sz * (iz + 0.5))
			box(c, Vector3(sx, size.y, sz), mat)


func _ground() -> void:
	var grass := Mat.tex("grass")
	# split around the stream channel (x 11.25 .. 13.75); the lit town area is
	# tiled finely, the far fields stay single boxes
	tiled_box(Vector3(-2.0, -0.5, -2.0), Vector3(26.5, 1.0, 20.0), grass)          # x -15.25..11.25, z -12..8
	box(Vector3(-37.25, -0.5, -10.0), Vector3(44.0, 1.0, 80.0), grass)                 # x -59.25..-15.25
	box(Vector3(-2.0, -0.5, -31.0), Vector3(26.5, 1.0, 38.0), grass)
	box(Vector3(-2.0, -0.5, 19.0), Vector3(26.5, 1.0, 22.0), grass)
	tiled_box(Vector3(19.75, -0.5, -2.0), Vector3(12.0, 1.0, 20.0), grass)        # far bank x 13.75..25.75
	box(Vector3(36.0, -0.5, -10.0), Vector3(20.5, 1.0, 80.0), grass)                   # x 25.75..46.25
	box(Vector3(19.75, -0.5, -31.0), Vector3(12.0, 1.0, 38.0), grass)
	box(Vector3(19.75, -0.5, 19.0), Vector3(12.0, 1.0, 22.0), grass)
	var dirt := Mat.tex("dirt")
	tiled_box(Vector3(-2.0, 0.005, 0.25), Vector3(26.5, 0.02, 3.6), dirt)        # main street
	tiled_box(Vector3(-3.0, 0.004, -7.5), Vector3(2.2, 0.02, 12.0), dirt)        # shrine path
	tiled_box(Vector3(18.0, 0.005, 0.25), Vector3(8.5, 0.02, 3.6), dirt)         # road past the bridge


func _stream_and_bridge() -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = preload("res://shaders/water.gdshader")
	var wt: Texture2D = load("res://assets/textures/water.png")
	water_mat.set_shader_parameter("water_tex", wt)
	water_mat.set_shader_parameter("tex_size", float(wt.get_width()))
	water_mat.set_shader_parameter("texels_per_metre", Mat.TEXELS_PER_METRE)
	water_mat.set_shader_parameter("pixel", 1.0 / Mat.TEXELS_PER_METRE)
	box(Vector3(12.5, -0.35, -10.0), Vector3(2.6, 0.1, 80.0), water_mat)
	box(Vector3(12.5, -0.9, -10.0), Vector3(2.6, 1.0, 80.0), Mat.col(Color(0.15, 0.25, 0.3)))
	var stone := Mat.tex("stone")
	for side in [-1.0, 1.0]:
		box(Vector3(12.5 + side * 1.35, -0.15, -10.0), Vector3(0.3, 0.4, 80.0), stone)
	# the channel is impassable except over the bridge (z -1.2 .. 1.7)
	solid(Vector3(12.5, 0, -25.6), Vector2(2.4, 48.8))
	solid(Vector3(12.5, 0, 16.2), Vector2(2.4, 29.0))
	for zz in [-1.35, 1.85]:
		solid(Vector3(12.5, 0, zz), Vector2(3.8, 0.2))
	# vermilion arched bridge: deck + rails + posts
	var wood := Mat.tex("wood")
	var red := Mat.col(Color(0.72, 0.18, 0.12))
	for i in 7:
		var t := (i - 3) / 3.0
		var y := 0.28 - t * t * 0.18
		box(Vector3(10.7 + i * 0.6, y, 0.25), Vector3(0.62, 0.12, 3.0), wood)
	for zz in [-1.25, 1.75]:
		for i in 5:
			box(Vector3(10.9 + i * 0.8, 0.55, zz), Vector3(0.12, 0.7, 0.12), red)
		box(Vector3(12.5, 0.88, zz), Vector3(3.6, 0.1, 0.12), red)
		for cap_x in [10.9, 14.1]:
			cyl(Vector3(cap_x, 0.98, zz), 0.0, 0.1, 0.18, Mat.col(Color(0.2, 0.18, 0.16)), 6)
	# two paper lanterns hung over the downstream rail; one light for both
	for lx in [11.7, 13.3]:
		var lp := Vector3(lx, 1.32, 1.75)
		box(lp + Vector3(0, 0.3, 0), Vector3(0.03, 0.28, 0.03), Mat.col(Color(0.1, 0.08, 0.08)))
		cyl(lp, 0.12, 0.12, 0.32, lantern_mat, 8)
		halo(lp, 1.0)
		reflected.append([Vector3(lx, 0, 1.75), 1.2])
	var bl := OmniLight3D.new()
	bl.position = Vector3(12.5, 1.4, 1.9)
	bl.light_color = Color(1.0, 0.6, 0.32)
	bl.omni_range = 4.5
	add_child(bl)
	lantern_lights.append(bl)


func _backdrop() -> void:
	var hill := Mat.tex("grass", Color(0.78, 0.86, 0.78))
	for h in [[-18.0, -26.0, 12.0], [2.0, -30.0, 16.0], [22.0, -27.0, 13.0], [-34.0, -18.0, 10.0]]:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = h[2]
		s.height = h[2] * 2.0
		s.radial_segments = 12
		s.rings = 6
		m.mesh = s
		m.material_override = hill
		m.position = Vector3(h[0], -h[2] * 0.62, h[1])
		add_child(m)
	var far := Mat.col(Color(0.36, 0.44, 0.52))
	var snow := Mat.col(Color(0.92, 0.94, 0.98))
	for mt in [[-30.0, -60.0, 20.0, 22.0], [-4.0, -70.0, 26.0, 30.0], [26.0, -62.0, 22.0, 24.0], [48.0, -55.0, 16.0, 16.0]]:
		cyl(Vector3(mt[0], mt[3] * 0.5 - 2.0, mt[1]), 0.0, mt[2], mt[3], far, 7)
		cyl(Vector3(mt[0], mt[3] - 2.0 - mt[3] * 0.12, mt[1]), 0.0, mt[2] * 0.24, mt[3] * 0.24, snow, 7)
	# pine forest line on the hills
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 34:
		var x := rng.randf_range(-30.0, 30.0)
		var z := rng.randf_range(-20.0, -14.0)
		if absf(x + 3.0) < 2.0:
			continue
		var s := sprite("res://assets/sprites/tree_pine.png", Vector3(x, 0, z), rng.randf_range(1.2, 1.7))
		s.set_tint(Color(0.85, 0.9, 0.95))


# ---------------------------------------------------------------------------
# architecture
# ---------------------------------------------------------------------------
func _house(center: Vector3, size: Vector3, roof_tint: Color, kind: String, side_facing := false) -> void:
	var root := Node3D.new()
	root.position = center
	if side_facing:
		root.rotation_degrees.y = 90.0      # front faces +X
	add_child(root)
	var w := size.x
	var h := size.y
	var d := size.z
	var plaster := Mat.tex("plaster")
	var wood := Mat.tex("wood")
	var dark := Mat.col(Color(0.18, 0.13, 0.11))
	var stone := Mat.tex("stone")
	# stone plinth, walls
	box(Vector3(0, 0.15, 0), Vector3(w + 0.2, 0.3, d + 0.2), stone, Vector3.ZERO, root)
	solid(Vector3.ZERO, Vector2(w + 0.2, d + 0.2), root)
	box(Vector3(0, 0.3 + h * 0.5, 0), Vector3(w, h, d), plaster, Vector3.ZERO, root)
	var fz := d * 0.5
	# lower wooden wainscot (koshi-ita) all round the front
	box(Vector3(0, 0.3 + 0.45, fz + 0.03), Vector3(w + 0.04, 0.9, 0.08), wood, Vector3.ZERO, root)
	# posts
	var n := int(w / 1.6) + 1
	for i in n + 1:
		var x := -w * 0.5 + w * float(i) / n
		box(Vector3(x, 0.3 + h * 0.5, fz + 0.06), Vector3(0.16, h, 0.14), dark, Vector3.ZERO, root)
	for side in [-1.0, 1.0]:
		box(Vector3(side * w * 0.5, 0.3 + h * 0.5, 0), Vector3(0.18, h, d + 0.04), dark, Vector3.ZERO, root)
	# beams
	box(Vector3(0, 0.3 + h - 0.08, fz + 0.06), Vector3(w + 0.1, 0.18, 0.16), dark, Vector3.ZERO, root)
	box(Vector3(0, 0.3 + h * 0.62, fz + 0.06), Vector3(w + 0.1, 0.1, 0.12), dark, Vector3.ZERO, root)
	# sliding shoji doors in the middle bays + upper lattice windows
	var shoji := shoji_mat
	box(Vector3(0, 0.3 + 0.95, fz + 0.04), Vector3(w * 0.45, 1.3, 0.06), shoji, Vector3.ZERO, root)
	box(Vector3(-w * 0.3, 0.3 + h * 0.8, fz + 0.04), Vector3(w * 0.2, 0.45, 0.06), shoji, Vector3.ZERO, root)
	box(Vector3(w * 0.3, 0.3 + h * 0.8, fz + 0.04), Vector3(w * 0.2, 0.45, 0.06), shoji, Vector3.ZERO, root)
	# noren curtain over the entrance (colour per shop)
	var noren_col := {"teahouse": Color(0.75, 0.2, 0.25), "inn": Color(0.18, 0.24, 0.45),
		"shop": Color(0.3, 0.42, 0.3), "side": Color(0.45, 0.32, 0.2)}[kind] as Color
	for k in 3:
		box(Vector3((k - 1) * w * 0.15, 0.3 + 1.75, fz + 0.12), Vector3(w * 0.14, 0.55, 0.03),
			Mat.col(noren_col), Vector3.ZERO, root)
	# gabled tiled roof, ridge along X, generous eaves
	var roof := Mat.tex("roof", roof_tint)
	if not roof in roof_mats:
		roof_mats.append(roof)
	var pitch := 24.0
	var half_d := d * 0.5 + 0.7
	var slope := half_d / cos(deg_to_rad(pitch))
	var rise := half_d * tan(deg_to_rad(pitch))
	var top := 0.3 + h
	for side in [-1.0, 1.0]:
		box(Vector3(0, top + rise * 0.5 + 0.05, side * half_d * 0.5),
			Vector3(w + 1.0, 0.16, slope), roof, Vector3(side * pitch, 0, 0), root)
	box(Vector3(0, top + rise + 0.12, 0), Vector3(w + 1.1, 0.22, 0.34), Mat.col(Color(0.22, 0.24, 0.3)), Vector3.ZERO, root)
	# gable ends (plaster triangles via a prism)
	var gm := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(d, rise - 0.12, w - 0.02)
	gm.mesh = prism
	gm.material_override = plaster
	gm.position = Vector3(0, top + (rise - 0.12) * 0.5, 0)
	gm.rotation_degrees.y = 90.0
	root.add_child(gm)
	# eave-hung paper lanterns
	for lx in [-w * 0.36, w * 0.36]:
		_paper_lantern(root, Vector3(lx, top - 0.55, fz + 0.75))
	# wooden sign board on the shop / inn
	if kind in ["inn", "shop", "teahouse"]:
		box(Vector3(0, top + 0.05, fz + 0.55), Vector3(1.4, 0.4, 0.08), wood, Vector3(-10, 0, 0), root)
		box(Vector3(0, top + 0.05, fz + 0.6), Vector3(1.2, 0.26, 0.02), Mat.col(Color(0.92, 0.86, 0.7)), Vector3(-10, 0, 0), root)


func _paper_lantern(parent: Node3D, pos: Vector3) -> void:
	box(pos + Vector3(0, 0.38, 0), Vector3(0.03, 0.3, 0.03), Mat.col(Color(0.1, 0.08, 0.08)), Vector3.ZERO, parent)
	cyl(pos, 0.15, 0.15, 0.4, lantern_mat, 8, parent)
	halo(pos, 1.1, parent)
	cyl(pos + Vector3(0, 0.22, 0), 0.1, 0.1, 0.05, Mat.col(Color(0.1, 0.08, 0.08)), 8, parent)
	cyl(pos - Vector3(0, 0.22, 0), 0.1, 0.1, 0.05, Mat.col(Color(0.1, 0.08, 0.08)), 8, parent)
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.6, 0.32)
	l.omni_range = 5.5
	l.shadow_enabled = false
	parent.add_child(l)
	lantern_lights.append(l)


func _torii(pos: Vector3) -> void:
	var red := Mat.col(Color(0.8, 0.2, 0.12))
	var black := Mat.col(Color(0.12, 0.1, 0.1))
	for side in [-1.0, 1.0]:
		cyl(pos + Vector3(side * 1.4, 1.7, 0), 0.14, 0.17, 3.4, red, 8)
		solid(pos + Vector3(side * 1.4, 0, 0), Vector2(0.45, 0.45))
		cyl(pos + Vector3(side * 1.4, 0.15, 0), 0.22, 0.22, 0.3, black, 8)
	box(pos + Vector3(0, 2.75, 0), Vector3(3.6, 0.2, 0.24), red)
	box(pos + Vector3(0, 3.45, 0), Vector3(4.4, 0.22, 0.32), red)
	box(pos + Vector3(0, 3.62, 0), Vector3(4.7, 0.14, 0.4), black)
	box(pos + Vector3(0, 3.1, 0), Vector3(0.22, 0.55, 0.22), red)


func _stone_lantern(pos: Vector3) -> void:
	var stone := Mat.tex("stone", Color(0.95, 0.95, 0.9))
	box(pos + Vector3(0, 0.1, 0), Vector3(0.6, 0.2, 0.6), stone)
	solid(pos, Vector2(0.6, 0.6))
	cyl(pos + Vector3(0, 0.55, 0), 0.12, 0.14, 0.7, stone, 6)
	box(pos + Vector3(0, 0.95, 0), Vector3(0.5, 0.12, 0.5), stone)
	box(pos + Vector3(0, 1.15, 0), Vector3(0.38, 0.3, 0.38), stone)
	box(pos + Vector3(0, 1.15, 0.0), Vector3(0.2, 0.18, 0.4), lantern_mat)
	halo(pos + Vector3(0, 1.15, 0.25), 0.8)
	cyl(pos + Vector3(0, 1.43, 0), 0.05, 0.42, 0.26, stone, 6)
	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 1.15, 0.3)
	l.light_color = Color(1.0, 0.62, 0.3)
	l.omni_range = 3.5
	add_child(l)
	lantern_lights.append(l)


func _teahouse_front(pos: Vector3) -> void:
	# red-clothed bench and a big paper parasol: the tea-house signature
	var red := Mat.col(Color(0.78, 0.16, 0.16))
	var wood := Mat.tex("wood")
	box(pos + Vector3(-0.6, 0.42, 0.2), Vector3(1.8, 0.08, 0.6), red)
	solid(pos + Vector3(-0.6, 0, 0.2), Vector2(1.8, 0.6))
	solid(pos + Vector3(0.9, 0, 0.3), Vector2(0.2, 0.2))
	for lx in [-1.3, 0.1]:
		box(pos + Vector3(lx, 0.2, 0.2), Vector3(0.08, 0.4, 0.5), wood)
	cyl(pos + Vector3(0.9, 1.1, 0.3), 0.03, 0.03, 2.2, Mat.col(Color(0.3, 0.2, 0.15)), 6)
	var para := cyl(pos + Vector3(0.9, 2.3, 0.3), 0.06, 1.25, 0.45, Mat.col(Color(0.82, 0.2, 0.18)), 12)
	para.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _well(pos: Vector3) -> void:
	var stone := Mat.tex("stone")
	var wood := Mat.tex("wood")
	cyl(pos + Vector3(0, 0.35, 0), 0.6, 0.65, 0.7, stone, 10)
	solid(pos, Vector2(1.4, 1.3))
	cyl(pos + Vector3(0, 0.66, 0), 0.45, 0.45, 0.05, Mat.col(Color(0.08, 0.1, 0.14)), 10)
	for sx in [-0.55, 0.55]:
		box(pos + Vector3(sx, 1.0, 0), Vector3(0.1, 1.9, 0.1), wood)
	box(pos + Vector3(0, 1.95, 0), Vector3(1.4, 0.1, 0.12), wood)
	for side in [-1.0, 1.0]:
		box(pos + Vector3(0, 2.12, side * 0.32), Vector3(1.5, 0.06, 0.75), Mat.tex("roof"), Vector3(side * 28, 0, 0))
	box(pos + Vector3(0.2, 1.3, 0), Vector3(0.22, 0.25, 0.22), wood)


## The Corvo camp on the far bank: tents, a war banner and a campfire.
func _camp() -> void:
	var canvas := Mat.tex("canvas")
	var dark := Mat.col(Color(0.2, 0.15, 0.12))
	for t in [[Vector3(19.0, 0, -3.7), 0.0, 2.6], [Vector3(20.6, 0, -1.9), 90.0, 2.2]]:
		var root := Node3D.new()
		root.position = t[0]
		root.rotation_degrees.y = t[1]
		add_child(root)
		var m := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(t[2], 1.7, 2.6)
		m.mesh = pr
		m.material_override = canvas
		m.position.y = 0.85
		root.add_child(m)
		box(Vector3(0, 0.6, 1.31), Vector3(0.7, 1.2, 0.02), Mat.col(Color(0.08, 0.06, 0.06)), Vector3.ZERO, root)
		box(Vector3(0, 1.72, 0), Vector3(0.08, 0.08, 2.8), dark, Vector3.ZERO, root)
		solid(Vector3.ZERO, Vector2(t[2], 2.6), root)
	# war banner on a tall pole
	var pole := Vector3(15.7, 0, -2.6)
	cyl(pole + Vector3(0, 1.9, 0), 0.05, 0.06, 3.8, dark, 6)
	box(pole + Vector3(0.45, 3.55, 0), Vector3(0.9, 0.06, 0.06), dark)
	var flag := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.85, 1.7)
	flag.mesh = q
	var fm := Mat.tex("banner").duplicate() as StandardMaterial3D
	fm.uv1_triplanar = false
	fm.uv1_scale = Vector3.ONE
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.material_override = fm
	flag.position = pole + Vector3(0.48, 2.67, 0.02)
	add_child(flag)
	solid(pole, Vector2(0.3, 0.3))
	# campfire: stone ring, logs, flame, warm light
	var fire := Vector3(14.8, 0, 3.0)      # off the duel camera's line to Kuroda's spot
	var stone := Mat.tex("stone")
	for k in 8:
		var a := TAU * k / 8.0
		box(fire + Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(0.25, 0.2, 0.22), stone, Vector3(0, -rad_to_deg(a), 0))
	for k in 3:
		box(fire + Vector3(0, 0.12, 0), Vector3(0.9, 0.1, 0.1), Mat.tex("wood"), Vector3(0, k * 60.0, 0))
	campfire = Campfire.new()
	campfire.position = fire
	add_child(campfire)
	fires.append(campfire)
	solid(fire, Vector2(1.2, 1.2))
	# kagaribi: iron fire baskets on tripods flanking the tents
	for bp in [Vector3(15.6, 0, -3.6), Vector3(22.6, 0, -0.4)]:
		var iron := Mat.col(Color(0.12, 0.11, 0.12), 0.6)
		for k in 3:
			var a := TAU * k / 3.0
			box(bp + Vector3(cos(a) * 0.18, 0.6, sin(a) * 0.18), Vector3(0.05, 1.25, 0.05), iron,
				Vector3(sin(a) * 9.0, 0, -cos(a) * 9.0))
		cyl(bp + Vector3(0, 1.28, 0), 0.26, 0.16, 0.22, iron, 8)
		var b := Campfire.new()
		b.scale_factor = 0.6
		b.light_range = 4.5
		b.position = bp + Vector3(0, 1.32, 0)
		add_child(b)
		fires.append(b)
		solid(bp, Vector2(0.5, 0.5))
	# crates and a weapon rack
	for p in [Vector3(20.2, 0, 1.9), Vector3(20.5, 0.5, 2.0)]:
		box(p + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Mat.tex("wood"))
	solid(Vector3(20.3, 0, 1.95), Vector2(0.6, 0.6))


func _props() -> void:
	var wood := Mat.tex("wood")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# barrels and crates by the tea house and the shop
	for p in [Vector3(-11.6, 0, -2.6), Vector3(-11.0, 0, -2.2), Vector3(10.5, 0, -2.6)]:
		cyl(p + Vector3(0, 0.4, 0), 0.32, 0.28, 0.8, wood, 10)
		solid(p, Vector2(0.6, 0.6))
		cyl(p + Vector3(0, 0.62, 0), 0.33, 0.33, 0.06, Mat.col(Color(0.2, 0.2, 0.22)), 10)
	solid(Vector3(9.7, 0, -2.45), Vector2(0.6, 0.6))
	for p in [Vector3(9.6, 0, -2.4), Vector3(9.8, 0.5, -2.5)]:
		box(p + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), wood, Vector3(0, rng.randf_range(-15, 15), 0))
	# bamboo fence along the front of the side house
	var bamboo := Mat.col(Color(0.62, 0.66, 0.38))
	for i in 9:
		cyl(Vector3(-11.2, 0.55, 0.6 + i * 0.6 + 2.2), 0.05, 0.05, 1.1, bamboo, 6)
	for y in [0.35, 0.85]:
		box(Vector3(-11.2, y, 4.8), Vector3(0.06, 0.06, 5.2), Mat.col(Color(0.35, 0.28, 0.2)))
	solid(Vector3(-11.2, 0, 5.0), Vector2(0.2, 5.4))


func _tree(path: String, pos: Vector3, s: float, flip := false) -> void:
	sprite(path, pos, s).set_flip(flip)
	solid(pos, Vector2(0.5, 0.4) * s)


func _foliage() -> void:
	_tree("res://assets/sprites/tree_sakura.png", Vector3(-6.0, 0, -2.1), 1.15)
	_tree("res://assets/sprites/tree_sakura.png", Vector3(16.5, 0, -3.5), 1.0, true)
	_tree("res://assets/sprites/tree_maple.png", Vector3(10.2, 0, -3.2), 1.0)
	_tree("res://assets/sprites/tree_pine.png", Vector3(-15.5, 0, -4.5), 1.4)
	_tree("res://assets/sprites/tree_pine.png", Vector3(5.2, 0, -8.6), 1.5)
	_tree("res://assets/sprites/tree_pine.png", Vector3(-10.0, 0, -9.4), 1.6, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for p in [Vector3(-5.2, 0, -3.4), Vector3(4.6, 0, -3.2), Vector3(-1.0, 0, -3.3), Vector3(6.5, 0, 2.9),
			Vector3(-7.0, 0, 3.4), Vector3(21.3, 0, 3.5), Vector3(-2.5, 0, 4.2), Vector3(9.6, 0, 3.6)]:
		var b := sprite("res://assets/sprites/bush.png", p, rng.randf_range(0.9, 1.25))
		b.set_flip(rng.randf() < 0.5)


## Walkable area of the post town: invisible walls around it.
const BOUNDS := Rect2(-16.0, -12.5, 37.0, 18.0)   # x, z, width, depth


func _bounds() -> void:
	var b := BOUNDS
	var cx := b.position.x + b.size.x * 0.5
	var cz := b.position.y + b.size.y * 0.5
	solid(Vector3(cx, 0, b.position.y - 0.5), Vector2(b.size.x + 2.0, 1.0))
	solid(Vector3(cx, 0, b.end.y + 0.5), Vector2(b.size.x + 2.0, 1.0))
	solid(Vector3(b.position.x - 0.5, 0, cz), Vector2(1.0, b.size.y + 2.0))
	solid(Vector3(b.end.x + 0.5, 0, cz), Vector2(1.0, b.size.y + 2.0))


func _particles() -> void:
	petals = CPUParticles3D.new()
	petals.amount = 160
	petals.lifetime = 9.0
	petals.preprocess = 9.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(16, 0.5, 9)
	petals.position = Vector3(-2, 6.5, -2)
	petals.direction = Vector3(1, -0.4, 0.3)
	petals.spread = 30.0
	petals.gravity = Vector3(0.35, -0.55, 0.1)
	petals.initial_velocity_min = 0.2
	petals.initial_velocity_max = 0.7
	petals.angular_velocity_min = -90
	petals.angular_velocity_max = 90
	var q := QuadMesh.new()
	q.size = Vector2(0.11, 0.08)
	q.material = Mat.unshaded(Color(1.0, 0.78, 0.86))
	petals.mesh = q
	add_child(petals)

	fireflies = CPUParticles3D.new()
	fireflies.amount = 70
	fireflies.lifetime = 6.0
	fireflies.preprocess = 6.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(14, 0.8, 6)
	fireflies.position = Vector3(2, 1.2, -1)
	fireflies.gravity = Vector3.ZERO
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.05
	fireflies.initial_velocity_max = 0.25
	var fq := QuadMesh.new()
	fq.size = Vector2(0.06, 0.06)
	var fm := Mat.unshaded(Color(0.85, 1.0, 0.45))
	fq.material = fm
	fireflies.mesh = fq
	add_child(fireflies)
