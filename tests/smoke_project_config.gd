extends SceneTree
## Headless config smoke test:
##   godot --headless --path . -s tests/smoke_project_config.gd

const EXPECTED_APP_NAME := "My Samurai Way"
const EXPECTED_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "interact", "cancel", "run", "journal"]


func _init() -> void:
	var ok := true
	var app_name = ProjectSettings.get_setting("application/config/name")
	if app_name != EXPECTED_APP_NAME:
		push_error("FAIL: app name '%s'" % app_name)
		ok = false
	var main_scene = ProjectSettings.get_setting("application/run/main_scene")
	if not ResourceLoader.exists(main_scene):
		push_error("FAIL: main scene missing " + str(main_scene))
		ok = false
	for action in EXPECTED_ACTIONS:
		var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
		print(action, " -> ", events.size(), " event(s)")
		if events.is_empty():
			push_error("FAIL: action '%s' has no events" % action)
			ok = false
	print("RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
