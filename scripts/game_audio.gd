class_name GameAudio
extends Node
## Music (crossfaded loops), ambience and sound effects.
## One instance lives under the main scene; everything else calls the static
## helpers, which are silent no-ops when no instance exists (headless tests).
##
## Web note: the HTML5 build plays audio as pre-registered "samples". A sound
## whose stream is swapped onto a player at play time is silent there, and
## loop flags changed at runtime are ignored. So every sound gets its own
## player with its stream set (and registered) at startup, and loops are set
## in the .wav.import files (edit/loop_mode=2), never in code.

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const MUSIC_DIR := "res://assets/audio/music/%s.wav"
const SFX := ["slash_light", "slash_heavy", "hit", "hit_heavy", "clash", "guard", "miss", "ko",
	"tech", "duel_start", "boca", "mood_good", "mood_bad", "mood_none", "reveal", "victory",
	"defeat", "step_1", "step_2", "step_3", "step_wood_1", "step_wood_2", "bell", "ui_move",
	"ui_select", "ui_back", "blip", "page", "choice", "ending_gong"]
const MUSIC := ["town_day", "town_night", "duel", "ending"]
const AMB := ["amb_day", "amb_night"]
const LOOPS := ["town_day", "town_night", "duel", "amb_day", "amb_night"]
const MUSIC_DB := -9.0
const AMB_DB := -6.0
const SILENT_DB := -60.0
## Sounds that may overlap themselves get a few voices.
const VOICES := {"step_1": 2, "step_2": 2, "step_3": 2, "blip": 3, "ui_move": 2, "hit": 2, "slash_light": 2}

static var inst: GameAudio

var current_music := ""
var current_amb := ""
var history: Array[String] = []          # last sfx played, newest last (tests read this)
var _sfx := {}                           # name -> Array[AudioStreamPlayer]
var _sfx_next := {}
var _tracks := {}                        # music/amb name -> AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	inst = self


func _exit_tree() -> void:
	if inst == self:
		inst = null


func _ready() -> void:
	_rng.seed = 99
	for bus in ["Music", "Amb", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for n in SFX:
		var voices: Array = []
		for v in VOICES.get(n, 1):
			var p := _player("SFX", SFX_DIR % n)
			if p:
				voices.append(p)
		_sfx[n] = voices
		_sfx_next[n] = 0
	for n in MUSIC:
		var p := _player("Music", MUSIC_DIR % n)
		if p:
			_tracks[n] = p
	for n in AMB:
		var p := _player("Amb", MUSIC_DIR % n)
		if p:
			_tracks[n] = p


func _player(bus: String, path: String) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		push_warning("audio missing: " + path)
		return null
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	var s: AudioStream = load(path)
	p.stream = s
	if OS.has_feature("web") and AudioServer.has_method("register_stream_as_sample"):
		AudioServer.register_stream_as_sample(s)
	return p


## Loads a stream as the game will (used by tests).
static func load_stream(path: String) -> AudioStream:
	return load(path) if ResourceLoader.exists(path) else null


# ---------------------------------------------------------------------------
# static helpers (safe without an instance)
# ---------------------------------------------------------------------------
static func sfx(name: String, db := 0.0, pitch_var := 0.0, pitch := 1.0) -> void:
	if inst:
		inst.play_sfx(name, db, pitch_var, pitch)


static func music(name: String, fade := 1.5) -> void:
	if inst:
		inst.play_music(name, fade)


static func ambience(name: String, fade := 2.0) -> void:
	if inst:
		inst.play_amb(name, fade)


# ---------------------------------------------------------------------------
# playback
# ---------------------------------------------------------------------------
func play_sfx(name: String, db := 0.0, pitch_var := 0.0, pitch := 1.0) -> void:
	history.append(name)
	if history.size() > 200:
		history.remove_at(0)
	var voices: Array = _sfx.get(name, [])
	if voices.is_empty():
		return
	var i: int = _sfx_next[name]
	_sfx_next[name] = (i + 1) % voices.size()
	var p: AudioStreamPlayer = voices[i]
	p.volume_db = db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


func play_music(name: String, fade := 1.5) -> void:
	if name == current_music:
		return
	_swap(current_music, name, MUSIC_DB, fade)
	current_music = name


func play_amb(name: String, fade := 2.0) -> void:
	if name == current_amb:
		return
	_swap(current_amb, name, AMB_DB, fade)
	current_amb = name


## Fades `old` out and `new` in ("" = silence).
func _swap(old: String, new: String, db: float, fade: float) -> void:
	if _tracks.has(old):
		var o: AudioStreamPlayer = _tracks[old]
		var t := create_tween()
		t.tween_property(o, "volume_db", SILENT_DB, fade)
		t.tween_callback(o.stop)
	if _tracks.has(new):
		var n: AudioStreamPlayer = _tracks[new]
		n.volume_db = SILENT_DB
		n.play()
		create_tween().tween_property(n, "volume_db", db, fade)


func played(name: String) -> bool:
	return history.has(name)
