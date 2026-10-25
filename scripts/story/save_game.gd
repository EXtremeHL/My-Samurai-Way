class_name SaveGame
## One save slot, written automatically (each new part of the day, after each
## conversation or duel) and from the pause menu. Finishing a run (any ending)
## deletes it; discovered endings are kept separately in Endings.
##
## On the web build user:// lives in the browser's IndexedDB, so the save
## survives closing the tab (same browser, same itch.io page).

static var path := "user://partida.cfg"


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func write(state: GameState, pos: Vector3, facing: Vector3) -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "state", state.to_dict())
	cfg.set_value("run", "pos", pos)
	cfg.set_value("run", "facing", facing)
	cfg.set_value("run", "saved_at", Time.get_datetime_string_from_system(false, true))
	return cfg.save(path) == OK


## {"state": Dictionary, "pos": Vector3, "facing": Vector3, "saved_at": String},
## or {} when there is no readable save.
static func read() -> Dictionary:
	if not exists():
		return {}
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section_key("run", "state"):
		return {}
	var st = cfg.get_value("run", "state", null)
	if not (st is Dictionary):
		return {}
	return {"state": st, "pos": cfg.get_value("run", "pos", StoryData.PLAYER_START),
		"facing": cfg.get_value("run", "facing", Vector3.BACK),
		"saved_at": cfg.get_value("run", "saved_at", "")}


## "Dia 2 · Manhã", for the title screen ("" when nothing usable is saved).
static func summary() -> String:
	var d := read()
	if d.is_empty():
		return ""
	var s := GameState.new()
	if not s.from_dict(d.state):
		return ""
	return s.clock_text()


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
