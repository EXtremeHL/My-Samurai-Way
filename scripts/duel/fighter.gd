class_name Fighter
extends RefCounted
## One side of a duel: stats, ki, mood and what it has heard.

var name := ""
var max_hp := 100
var hp := 100
var atk := 18
var def := 10
var ki := 20
var personality := -1          # Personality.Id, -1 for the player
var revealed := false          # player knows this foe's personality
var mood := Personality.Mood.NONE
var mood_turns := 0
var heard := {}                # Bocas.Cat -> times heard
var guarding := false
var parrying := false
var skip_action := false       # lost this turn's action (distracted)
var surrendered := false


static func make(n: String, stats: Dictionary, p := -1) -> Fighter:
	var f := Fighter.new()
	f.name = n
	f.max_hp = stats.hp
	f.hp = stats.hp
	f.atk = stats.atk
	f.def = stats.def
	f.ki = stats.get("ki", 20)
	f.personality = p
	return f


func alive() -> bool:
	return hp > 0 and not surrendered


func atk_mult() -> float:
	return Personality.MOOD_STATS[mood][0]


func def_mult() -> float:
	return Personality.MOOD_STATS[mood][1]


func acc_bonus() -> float:
	return Personality.MOOD_STATS[mood][2]


func set_mood(m: int) -> void:
	mood = m
	mood_turns = Personality.MOOD_TURNS.get(m, 0)


func tick_mood() -> void:
	if mood == Personality.Mood.NONE:
		return
	mood_turns -= 1
	if mood_turns <= 0:
		mood = Personality.Mood.NONE
		mood_turns = 0


func times_heard(cat: int) -> int:
	return heard.get(cat, 0)


func hp_ratio() -> float:
	return float(hp) / float(max_hp)
