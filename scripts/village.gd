class_name Village
extends Node3D
## Builds the first valley location - the post town of Kurogane-juku - out of
## textured boxes (architecture) and lit pixel cards (people, trees).
## All placement is hand-authored or seeded so every run is identical.

const CHAR_W := 32
const CHAR_H := 48
const ROW := {"down": 0, "up": 1, "side": 2}

var lantern_lights: Array[OmniLight3D] = []
var lantern_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var petals: CPUParticles3D
var fireflies: CPUParticles3D
var characters := {}


func build() -> void:
	lantern_mat = Mat.glow(Color(1.0, 0.45, 0.25), 1.0)
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
	_well(Vector3(5.2, 0, 3.4))
	_props()
	_foliage()
	_people()
	_particles()


func _process(delta: float) -> void:
	if water_mat:
		water_mat.uv1_offset.z -= delta * 0.12


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


func sprite(path: String, pos: Vector3, scale_f := 1.0, fw := 0, fh := 0) -> PixelSprite:
	var s := PixelSprite.make(path, fw, fh)
	s.position = pos
	s.scale = Vector3.ONE * scale_f
	add_child(s)
	return s


# ---------------------------------------------------------------------------
# terrain
# ---------------------------------------------------------------------------
func _ground() -> void:
	var grass := Mat.tex("grass")
	# split around the stream channel (x 11.25 .. 13.75)
	box(Vector3(-24.0, -0.5, -10.0), Vector3(70.5, 1.0, 80.0), grass)
	box(Vector3(30.0, -0.5, -10.0), Vector3(32.5, 1.0, 80.0), grass)
	var dirt := Mat.tex("dirt")
	box(Vector3(-2.0, 0.005, 0.25), Vector3(26.5, 0.02, 3.6), dirt)        # main street
	box(Vector3(-3.0, 0.004, -7.5), Vector3(2.2, 0.02, 12.0), dirt)        # shrine path
	box(Vector3(18.0, 0.005, 0.25), Vector3(8.5, 0.02, 3.6), dirt)         # road past the bridge


func _stream_and_bridge() -> void:
	water_mat = Mat.tex("water").duplicate()
	water_mat.roughness = 0.12
	water_mat.metallic_specular = 0.7
	box(Vector3(12.5, -0.35, -10.0), Vector3(2.6, 0.1, 80.0), water_mat)
	box(Vector3(12.5, -0.9, -10.0), Vector3(2.6, 1.0, 80.0), Mat.col(Color(0.15, 0.25, 0.3)))
	var stone := Mat.tex("stone")
	for side in [-1.0, 1.0]:
		box(Vector3(12.5 + side * 1.35, -0.15, -10.0), Vector3(0.3, 0.4, 80.0), stone)
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
	var shoji := Mat.tex("shoji")
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
		cyl(pos + Vector3(side * 1.4, 0.15, 0), 0.22, 0.22, 0.3, black, 8)
	box(pos + Vector3(0, 2.75, 0), Vector3(3.6, 0.2, 0.24), red)
	box(pos + Vector3(0, 3.45, 0), Vector3(4.4, 0.22, 0.32), red)
	box(pos + Vector3(0, 3.62, 0), Vector3(4.7, 0.14, 0.4), black)
	box(pos + Vector3(0, 3.1, 0), Vector3(0.22, 0.55, 0.22), red)


func _stone_lantern(pos: Vector3) -> void:
	var stone := Mat.tex("stone", Color(0.95, 0.95, 0.9))
	box(pos + Vector3(0, 0.1, 0), Vector3(0.6, 0.2, 0.6), stone)
	cyl(pos + Vector3(0, 0.55, 0), 0.12, 0.14, 0.7, stone, 6)
	box(pos + Vector3(0, 0.95, 0), Vector3(0.5, 0.12, 0.5), stone)
	box(pos + Vector3(0, 1.15, 0), Vector3(0.38, 0.3, 0.38), stone)
	box(pos + Vector3(0, 1.15, 0.0), Vector3(0.2, 0.18, 0.4), lantern_mat)
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
	for lx in [-1.3, 0.1]:
		box(pos + Vector3(lx, 0.2, 0.2), Vector3(0.08, 0.4, 0.5), wood)
	cyl(pos + Vector3(0.9, 1.1, 0.3), 0.03, 0.03, 2.2, Mat.col(Color(0.3, 0.2, 0.15)), 6)
	var para := cyl(pos + Vector3(0.9, 2.3, 0.3), 0.06, 1.25, 0.45, Mat.col(Color(0.82, 0.2, 0.18)), 12)
	para.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _well(pos: Vector3) -> void:
	var stone := Mat.tex("stone")
	var wood := Mat.tex("wood")
	cyl(pos + Vector3(0, 0.35, 0), 0.6, 0.65, 0.7, stone, 10)
	cyl(pos + Vector3(0, 0.66, 0), 0.45, 0.45, 0.05, Mat.col(Color(0.08, 0.1, 0.14)), 10)
	for sx in [-0.55, 0.55]:
		box(pos + Vector3(sx, 1.0, 0), Vector3(0.1, 1.9, 0.1), wood)
	box(pos + Vector3(0, 1.95, 0), Vector3(1.4, 0.1, 0.12), wood)
	for side in [-1.0, 1.0]:
		box(pos + Vector3(0, 2.12, side * 0.32), Vector3(1.5, 0.06, 0.75), Mat.tex("roof"), Vector3(side * 28, 0, 0))
	box(pos + Vector3(0.2, 1.3, 0), Vector3(0.22, 0.25, 0.22), wood)


func _props() -> void:
	var wood := Mat.tex("wood")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# barrels and crates by the tea house and the shop
	for p in [Vector3(-11.6, 0, -2.6), Vector3(-11.0, 0, -2.2), Vector3(10.5, 0, -2.6)]:
		cyl(p + Vector3(0, 0.4, 0), 0.32, 0.28, 0.8, wood, 10)
		cyl(p + Vector3(0, 0.62, 0), 0.33, 0.33, 0.06, Mat.col(Color(0.2, 0.2, 0.22)), 10)
	for p in [Vector3(9.6, 0, -2.4), Vector3(9.8, 0.5, -2.5)]:
		box(p + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), wood, Vector3(0, rng.randf_range(-15, 15), 0))
	# bamboo fence along the front of the side house
	var bamboo := Mat.col(Color(0.62, 0.66, 0.38))
	for i in 9:
		cyl(Vector3(-11.2, 0.55, 0.6 + i * 0.6 + 2.2), 0.05, 0.05, 1.1, bamboo, 6)
	for y in [0.35, 0.85]:
		box(Vector3(-11.2, y, 4.8), Vector3(0.06, 0.06, 5.2), Mat.col(Color(0.35, 0.28, 0.2)))


func _foliage() -> void:
	sprite("res://assets/sprites/tree_sakura.png", Vector3(-6.0, 0, -2.1), 1.15)
	sprite("res://assets/sprites/tree_sakura.png", Vector3(16.5, 0, -3.5), 1.0).set_flip(true)
	sprite("res://assets/sprites/tree_maple.png", Vector3(10.2, 0, -3.2), 1.0)
	sprite("res://assets/sprites/tree_pine.png", Vector3(-15.5, 0, -4.5), 1.4)
	sprite("res://assets/sprites/tree_pine.png", Vector3(5.2, 0, -8.6), 1.5)
	sprite("res://assets/sprites/tree_pine.png", Vector3(-10.0, 0, -9.4), 1.6).set_flip(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for p in [Vector3(-5.2, 0, -3.4), Vector3(4.6, 0, -3.2), Vector3(-1.0, 0, -3.3), Vector3(6.5, 0, 2.9),
			Vector3(-7.0, 0, 3.4), Vector3(14.6, 0, 3.4), Vector3(-2.5, 0, 4.2), Vector3(9.6, 0, 3.6)]:
		var b := sprite("res://assets/sprites/bush.png", p, rng.randf_range(0.9, 1.25))
		b.set_flip(rng.randf() < 0.5)


func _people() -> void:
	_person("hero", Vector3(0.6, 0, 0.7), "down", 0, false)
	_person("ronin", Vector3(-4.9, 0, -1.4), "side", 0, false)
	_person("girl", Vector3(-7.3, 0, -1.9), "down", 0, false)
	_person("elder", Vector3(-9.4, 0, -1.7), "down", 0, false)
	_person("villager", Vector3(4.2, 0, 0.2), "side", 1, true)
	_person("guard", Vector3(-1.7, 0, -11.6), "down", 0, false)


func _person(id: String, pos: Vector3, facing: String, frame: int, flip: bool) -> PixelSprite:
	var s := sprite("res://assets/sprites/char_%s.png" % id, pos, 1.0, CHAR_W, CHAR_H)
	s.set_frame(frame, ROW[facing])
	s.set_flip(flip)
	characters[id] = s
	return s


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
