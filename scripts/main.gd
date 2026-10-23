extends Node3D
## Entry scene. Builds the diorama, camera and post FX.
##
## Command-line hooks (after a bare `--`):
##   --look <dourado|neblina|noite>     choose lighting preset
##   --capture <dir>                    render every preset to PNGs and quit

var village: Village
var env: Environment
var sun: DirectionalLight3D
var cam: Camera3D


func _ready() -> void:
	village = Village.new()
	add_child(village)
	village.build()

	sun = DirectionalLight3D.new()
	add_child(sun)

	var we := WorldEnvironment.new()
	env = Environment.new()
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0.0, 9.0, 14.5)
	cam.attributes = Look.make_camera_attributes()
	add_child(cam)
	cam.look_at(Vector3(0.0, 0.6, -4.2), Vector3.UP)
	cam.current = true

	var layer := CanvasLayer.new()
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vm
	layer.add_child(vignette)
	add_child(layer)

	var args := OS.get_cmdline_user_args()
	var look := "dourado"
	var i := args.find("--look")
	if i >= 0 and i + 1 < args.size():
		look = args[i + 1]
	Look.apply(look, env, sun, village)

	i = args.find("--capture")
	if i >= 0 and i + 1 < args.size():
		_capture(args[i + 1])


func _capture(dir: String) -> void:
	var abs_dir := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	for v in Look.VARIANTS:
		Look.apply(v, env, sun, village)
		for _f in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := abs_dir.path_join("look_%s.png" % v)
		img.save_png(path)
		print("captured: ", path)
	get_tree().quit(0)
