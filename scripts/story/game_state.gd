class_name GameState
extends RefCounted
## Everything the valley remembers: the clock, faction standing, flags and
## the hero's condition. Pure data + rules, so the story can be tested headless.

const PERIODS := ["manha", "tarde", "noite"]
const PERIOD_NAMES := {"manha": "Manhã", "tarde": "Tarde", "noite": "Noite"}
const LOOKS := {"manha": "neblina", "tarde": "dourado", "noite": "noite"}
const UNITS_PER_PERIOD := 8
const LAST_DAY := 3
const FACTIONS := ["corvo", "magistrado", "vila"]
const FACTION_NAMES := {"corvo": "Bando do Corvo", "magistrado": "Magistrado", "vila": "Gente da vila"}

const COST_TALK := 1
const COST_DUEL := 3

var day := 1
var period_i := 1            # the hero arrives in the afternoon
var units := 0
var rep := {"corvo": 0, "magistrado": 0, "vila": 0}
var flags := {}
var marks := {}              # name -> absolute period when it was set
var hero_hp := 110
var ending := ""


func period() -> String:
	return PERIODS[period_i]


func period_name() -> String:
	return PERIOD_NAMES[period()]


func look() -> String:
	return LOOKS[period()]


func units_left() -> int:
	return maxi(0, UNITS_PER_PERIOD - units)


func is_last_period() -> bool:
	return day == LAST_DAY and period_i == PERIODS.size() - 1


func clock_text() -> String:
	return "Dia %d · %s" % [day, period_name()]


## Spend time. Returns true when the current part of the day is used up.
func spend(n: int) -> bool:
	units += n
	return units >= UNITS_PER_PERIOD


## Move to the next part of the day. Returns false when time has run out.
func advance_period() -> bool:
	if is_last_period():
		return false
	units = 0
	period_i += 1
	if period_i >= PERIODS.size():
		period_i = 0
		day += 1
	return true


## Periods elapsed since the start (Day 1 morning = 0).
func abs_period() -> int:
	return (day - 1) * PERIODS.size() + period_i


func has(flag: String) -> bool:
	return flags.get(flag, false)


func set_flag(flag: String, on := true) -> void:
	if on:
		flags[flag] = true
	else:
		flags.erase(flag)


func add_rep(faction: String, delta: int) -> void:
	rep[faction] = clampi(rep[faction] + delta, -100, 100)


# ---------------------------------------------------------------------------
# hero
# ---------------------------------------------------------------------------
func hero_atk() -> int:
	return 24 if has("espada_forjada") else 18


func hero_max_hp() -> int:
	return 110


func heal(ratio: float) -> void:
	hero_hp = mini(hero_max_hp(), hero_hp + roundi(hero_max_hp() * ratio))


func make_hero() -> Fighter:
	var f := Fighter.make("Tu", {"hp": hero_max_hp(), "atk": hero_atk(), "def": 10, "ki": 20})
	f.hp = maxi(1, hero_hp)
	return f


func blade_name() -> String:
	return "Lâmina de aço negro" if has("espada_forjada") else "Lâmina partida"


# ---------------------------------------------------------------------------
# conditions
# ---------------------------------------------------------------------------
## A condition dictionary; every key present must hold.
##   period: [names]   day_min / day_max: int
##   flags: [all set]  noflags: [none set]  anyflags: [at least one set]
##   rep_min / rep_max: {faction: n}
##   since: {mark: n}  at least n parts of the day passed since mark:x
func check(c: Dictionary) -> bool:
	if c.has("period") and not (period() in c.period):
		return false
	if c.has("day_min") and day < c.day_min:
		return false
	if c.has("day_max") and day > c.day_max:
		return false
	for f in c.get("flags", []):
		if not has(f):
			return false
	for f in c.get("noflags", []):
		if has(f):
			return false
	if c.has("anyflags"):
		var any := false
		for f in c.anyflags:
			any = any or has(f)
		if not any:
			return false
	for k in c.get("rep_min", {}):
		if rep[k] < c.rep_min[k]:
			return false
	for k in c.get("rep_max", {}):
		if rep[k] > c.rep_max[k]:
			return false
	for k in c.get("since", {}):
		if not marks.has(k) or abs_period() - marks[k] < c.since[k]:
			return false
	return true


# ---------------------------------------------------------------------------
# effects
# ---------------------------------------------------------------------------
## Applies a tag string ("flag:x;rep:vila:+10;duel:tetsu") and returns the
## commands the scene has to carry out: [["duel", id], ["end", id], ...].
func apply(tags: String) -> Array:
	var cmds: Array = []
	for raw in tags.split(";", false):
		var t := raw.strip_edges()
		var parts := t.split(":")
		match parts[0]:
			"flag":
				set_flag(parts[1])
			"unflag":
				set_flag(parts[1], false)
			"mark":
				marks[parts[1]] = abs_period()
			"rep":
				add_rep(parts[1], int(parts[2]))
			"time":
				cmds.append(["time", int(parts[1])])
			"heal":
				heal(float(parts[1]) if parts.size() > 1 else 1.0)
			"duel", "end", "rest", "chain":
				cmds.append([parts[0], parts[1] if parts.size() > 1 else ""])
			_:
				push_error("unknown story tag: " + t)
	return cmds
