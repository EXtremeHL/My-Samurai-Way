class_name GameAudio
extends Node
## Music (crossfaded loops), ambience and pooled sound effects.
## One instance lives under the main scene; everything else calls the static
## helpers, which are silent no-ops when no instance exists (headless tests).

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const MUSIC_DIR := "res://assets/audio/music/%s.wav"
const LOOPS := ["town_day", "town_night", "duel", "amb_day", "amb_night"]
const POOL := 12
const MUSIC_DB := -9.0
const AMB_DB := -6.0
const SILENT_DB := -60.0

static var inst: GameAudio

var current_music := ""
var current_amb := ""
var history: Array[String] = []          # last sfx played, newest last (tests read this)
var _music: Array[AudioStreamPlayer] = []
var _music_i := 0
var _amb: Array[AudioStreamPlayer] = []
var _amb_i := 0
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _cache := {}
var _missing := {}
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
	for i in 2:
		_music.append(_player("Music"))
		_amb.append(_player("Amb"))
	for i in POOL:
		_pool.append(_player("SFX"))


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# ---------------------------------------------------------------------------
# loading
# ---------------------------------------------------------------------------
func stream(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		if not _missing.has(path):
			_missing[path] = true
			push_warning("audio missing: " + path)
		return null
	var s: AudioStream = load(path)
	if loop and s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
	_cache[path] = s
	return s


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
	var s := stream(SFX_DIR % name, false)
	if s == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch * (1.0 + _rng.randf_range(-pitch_var, pitch_var))
	p.play()


func play_music(name: String, fade := 1.5) -> void:
	if name == current_music:
		return
	current_music = name
	_music_i = _crossfade(_music, _music_i, name, name in LOOPS, MUSIC_DB, fade)


func play_amb(name: String, fade := 2.0) -> void:
	if name == current_amb:
		return
	current_amb = name
	_amb_i = _crossfade(_amb, _amb_i, name, true, AMB_DB, fade)


## Fades the active player out and the other one in with the new track.
## Returns the index of the now-active player. name "" = fade to silence.
func _crossfade(players: Array[AudioStreamPlayer], active: int, name: String, loop: bool, db: float, fade: float) -> int:
	var old := players[active]
	var nxt_i := (active + 1) % players.size()
	var nxt := players[nxt_i]
	if old.playing:
		var t := create_tween()
		t.tween_property(old, "volume_db", SILENT_DB, fade)
		t.tween_callback(old.stop)
	var s: AudioStream = null
	if name != "":
		s = stream(MUSIC_DIR % name, loop)
	if s == null:
		nxt.stop()
		return nxt_i
	nxt.stream = s
	nxt.volume_db = SILENT_DB
	nxt.play()
	create_tween().tween_property(nxt, "volume_db", db, fade)
	return nxt_i


func played(name: String) -> bool:
	return history.has(name)
