extends SceneTree
## Audio wiring tests: godot --headless --path . -s tests/test_audio.gd
## Every sound the code asks for must exist; loops must be set to loop.

var ok := true
var count := 0


func check(cond: bool, msg: String) -> void:
	count += 1
	if cond:
		print("ok:   ", msg)
	else:
		print("FAIL: ", msg)
		ok = false


func _init() -> void:
	var refs := _referenced_sounds()
	var missing := []
	for n in refs.sfx:
		if not ResourceLoader.exists(GameAudio.SFX_DIR % n):
			missing.append("sfx/" + n)
	for n in refs.music:
		if not ResourceLoader.exists(GameAudio.MUSIC_DIR % n):
			missing.append("music/" + n)
	check(refs.sfx.size() >= 20, "code references %d sound effects" % refs.sfx.size())
	check(missing.is_empty(), "every referenced sound exists %s" % [missing])

	var listed := []
	for n in refs.sfx:
		if not (n in GameAudio.SFX):
			listed.append(n)
	check(listed.is_empty(), "every sfx the code plays is pre-registered in GameAudio.SFX %s" % [listed])
	for n in GameAudio.LOOPS:
		var s := GameAudio.load_stream(GameAudio.MUSIC_DIR % n)
		if s == null:
			check(false, "loop %s loads" % n)
			continue
		var w := s as AudioStreamWAV
		check(w != null and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and w.loop_end > w.mix_rate * 5,
			"%s loops (set at import, works on the web) over %.1f s" % [n, s.get_length()])
	var e := GameAudio.load_stream(GameAudio.MUSIC_DIR % "ending")
	check(e != null and (e as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED, "the ending theme plays once")
	for n in GameAudio.SFX:
		var s := GameAudio.load_stream(GameAudio.SFX_DIR % n) as AudioStreamWAV
		if s == null or s.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			check(false, "sfx %s loads and does not loop" % n)
	check(true, "all %d sfx load as one-shots" % GameAudio.SFX.size())
	print("RESULT: ", "PASS" if ok else "FAIL", " (%d checks)" % count)
	quit(0 if ok else 1)


## Greps the scripts for GameAudio.sfx("x") / music("x") / ambience("x").
func _referenced_sounds() -> Dictionary:
	var sfx := {}
	var music := {}
	var re_sfx := RegEx.create_from_string("GameAudio\\.sfx\\(\"([a-z_]+)\"")
	var re_mus := RegEx.create_from_string("GameAudio\\.(?:music|ambience)\\(\"([a-z_]+)\"")
	var re_alt := RegEx.create_from_string("\"([a-z_]+)\" if [^\\n]+ else \"([a-z_]+)\"")
	for path in _scripts("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		for m in re_sfx.search_all(src):
			sfx[m.get_string(1)] = true
		for m in re_mus.search_all(src):
			music[m.get_string(1)] = true
		for line in src.split("\n"):
			if not line.contains("GameAudio."):
				continue
			for m in re_alt.search_all(line):
				var bucket := sfx if line.contains(".sfx(") else music
				bucket[m.get_string(1)] = true
				bucket[m.get_string(2)] = true
	# formatted names
	for n in ["step_1", "step_2", "step_3", "step_wood_1", "step_wood_2"]:
		sfx[n] = true
	sfx.erase("step_")
	sfx.erase("step_wood_")
	return {"sfx": sfx.keys(), "music": music.keys()}


func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
