class_name Duel
extends RefCounted
## Turn-based one-on-one duel. Pure logic: no nodes, seeded RNG, every turn
## returns a list of event dictionaries for the stage to animate.
##
## Turn flow:
##   begin_turn()   - the foe commits to an intent (telegraphed, unless hidden)
##   play_turn(a)   - hero acts first, then the foe carries out its intent
##
## Reading the intent is the core skill: parry a telegraphed attack for a
## counter, guard against a technique, attack into a guard with a heavy blow.
## Bocas change the foe's mood - for better or worse depending on who he is.

enum Act { LIGHT, HEAVY, GUARD, PARRY, TECH, BOCA, OBSERVE }
enum Result { ONGOING, WIN, LOSE, SURRENDER }

const ACT_NAMES := {
	Act.LIGHT: "Golpe rápido", Act.HEAVY: "Golpe forte", Act.GUARD: "Guarda",
	Act.PARRY: "Contra-ataque", Act.TECH: "Técnica", Act.BOCA: "Boca", Act.OBSERVE: "Observar",
}
const TECH_NAME := "Corte do Relâmpago"
const TECH_COST := 60
const BOCA_KI := 15                 # a boca costs breath, not the turn
const POWER := {Act.LIGHT: 1.0, Act.HEAVY: 1.8, Act.TECH: 2.6}
const ACCURACY := {Act.LIGHT: 0.92, Act.HEAVY: 0.74, Act.TECH: 0.95}
## Damage let through a raised guard.
const GUARD_MULT := {Act.LIGHT: 0.35, Act.HEAVY: 0.65, Act.TECH: 0.5}
## A parry only turns aside the big wind-up of a heavy blow; parrying a quick
## cut leaves you caught off-balance, and techniques can't be parried at all.
const PARRY_COUNTER := 1.5
const CAUGHT_MULT := 1.3
const CRIT_CHANCE := 0.08
const KI_PER_TURN := 10
const KI_GUARD := 20
const KI_HIT := 8
const KI_OBSERVE := 10
const FOE_TAUNT_CHANCE := 0.35       # foe's boca rattles the hero
const SURRENDER_HP := 0.35
const MERCENARY_QUIT_HP := 0.2

var hero: Fighter
var foe: Fighter
var rng := RandomNumberGenerator.new()
var intent := Act.LIGHT           # what the foe will really do
var shown_intent := Act.LIGHT     # what he lets you see (may be a feint)
var intent_hidden := false
var boca_used := false
var result := Result.ONGOING
var turn := 0
var _hero_parry_used := false
var _foe_parry_used := false


func _init(h: Fighter, f: Fighter, seed_value := 0) -> void:
	hero = h
	foe = f
	rng.seed = seed_value


# ---------------------------------------------------------------------------
# turn
# ---------------------------------------------------------------------------
func begin_turn() -> void:
	turn += 1
	foe.skip_action = false
	boca_used = false
	intent = _choose_intent()
	shown_intent = intent
	intent_hidden = false
	if foe.mood in Personality.HONEST_MOODS:
		return
	var hide: float = Personality.HIDE_INTENT.get(foe.personality, 0.0)
	intent_hidden = (not foe.revealed) and rng.randf() < hide
	var feint: float = Personality.FEINT.get(foe.personality, 0.0)
	if foe.mood == Personality.Mood.FOCADO:
		feint += 0.25
	if not intent_hidden and intent != Act.TECH and rng.randf() < feint:
		var fakes := [Act.LIGHT, Act.HEAVY, Act.GUARD, Act.PARRY]
		fakes.erase(intent)
		shown_intent = fakes[rng.randi() % fakes.size()]


func can_use(a: int) -> bool:
	if a == Act.TECH:
		return hero.ki >= TECH_COST
	return true


func can_boca() -> bool:
	return result == Result.ONGOING and not boca_used and hero.ki >= BOCA_KI


## The hero mouths off before acting. Resolves at once so the player sees the
## reaction - and the foe's changed plans - before choosing an action.
func say_boca(cat: int) -> Array:
	var ev: Array = []
	if not can_boca():
		return ev
	boca_used = true
	hero.ki -= BOCA_KI
	_boca(cat, ev)
	if foe.mood in Personality.HONEST_MOODS:
		# too rattled or too angry to keep a poker face
		if foe.mood == Personality.Mood.ENFURECIDO and intent in [Act.GUARD, Act.PARRY]:
			intent = Act.HEAVY
		var changed := shown_intent != intent or intent_hidden
		shown_intent = intent
		intent_hidden = false
		if changed:
			ev.append({"t": "intent_change", "who": "foe"})
	_check(ev)
	return ev


func play_turn(a: int) -> Array:
	var ev: Array = []
	if result != Result.ONGOING:
		return ev
	_hero_parry_used = false
	_foe_parry_used = false
	hero.guarding = a == Act.GUARD
	hero.parrying = a == Act.PARRY
	foe.guarding = intent == Act.GUARD and not foe.skip_action
	foe.parrying = intent == Act.PARRY and not foe.skip_action

	# --- the hero acts ---
	match a:
		Act.GUARD:
			hero.ki = mini(100, hero.ki + KI_GUARD)
			ev.append({"t": "guard", "who": "hero"})
		Act.PARRY:
			ev.append({"t": "parry_stance", "who": "hero"})
		Act.LIGHT, Act.HEAVY, Act.TECH:
			if a == Act.TECH:
				hero.ki -= TECH_COST
			_attack(hero, foe, a, ev)
		Act.OBSERVE:
			foe.revealed = true
			hero.ki = mini(100, hero.ki + KI_OBSERVE)
			ev.append({"t": "observe", "who": "hero", "personality": foe.personality, "intent": intent})
	_check(ev)

	# --- the foe carries out its intent ---
	if result == Result.ONGOING:
		if foe.skip_action:
			ev.append({"t": "skip", "who": "foe"})
		else:
			match intent:
				Act.LIGHT, Act.HEAVY, Act.TECH:
					if intent == Act.TECH:
						foe.ki -= TECH_COST
					_attack(foe, hero, intent, ev)
				Act.GUARD:
					foe.ki = mini(100, foe.ki + KI_GUARD)
					ev.append({"t": "guard", "who": "foe"})
				Act.PARRY:
					if not _foe_parry_used:
						ev.append({"t": "parry_wasted", "who": "foe"})
				Act.BOCA:
					_foe_taunt(ev)
		_check(ev)

	if a == Act.PARRY and not _hero_parry_used and result == Result.ONGOING:
		ev.append({"t": "parry_wasted", "who": "hero"})

	# --- end of turn ---
	hero.tick_mood()
	foe.tick_mood()
	hero.ki = mini(100, hero.ki + KI_PER_TURN)
	foe.ki = mini(100, foe.ki + KI_PER_TURN)
	hero.guarding = false
	hero.parrying = false
	foe.guarding = false
	foe.parrying = false
	return ev


# ---------------------------------------------------------------------------
# attacks
# ---------------------------------------------------------------------------
func _who(f: Fighter) -> String:
	return "hero" if f == hero else "foe"


func damage_of(att: Fighter, dfn: Fighter, kind: int, roll := 1.0) -> int:
	var power: float = POWER[kind]
	var raw: float = float(att.atk) * att.atk_mult() * power * roll
	raw -= float(dfn.def) * dfn.def_mult() * 0.7
	return maxi(1, roundi(raw))


func _attack(att: Fighter, dfn: Fighter, kind: int, ev: Array) -> void:
	var caught := false
	if dfn.parrying and kind == Act.LIGHT:
		caught = true                 # waited for a big swing, got a quick cut
		dfn.parrying = false
		if dfn == hero:
			_hero_parry_used = true
		else:
			_foe_parry_used = true
	if dfn.parrying and kind == Act.HEAVY:
		# read it: the defender turns the blow aside and cuts back
		var counter: int = roundi(damage_of(dfn, att, Act.LIGHT, rng.randf_range(0.9, 1.1)) * PARRY_COUNTER)
		att.hp = maxi(0, att.hp - counter)
		dfn.ki = mini(100, dfn.ki + KI_HIT)
		if dfn == hero:
			_hero_parry_used = true
		else:
			_foe_parry_used = true
		dfn.parrying = false
		ev.append({"t": "parried", "who": _who(att), "by": _who(dfn), "kind": kind, "dmg": counter})
		return
	var base_acc: float = ACCURACY[kind]
	var acc: float = base_acc + att.acc_bonus()
	if rng.randf() > acc:
		ev.append({"t": "miss", "who": _who(att), "kind": kind})
		return
	var dmg := float(damage_of(att, dfn, kind, rng.randf_range(0.9, 1.1)))
	var crit := rng.randf() < CRIT_CHANCE
	if crit:
		dmg *= 1.5
	if caught:
		dmg *= CAUGHT_MULT
	var guarded := dfn.guarding
	if guarded:
		var gm: float = GUARD_MULT[kind]
		dmg *= gm
	var d := maxi(1, roundi(dmg))
	dfn.hp = maxi(0, dfn.hp - d)
	att.ki = mini(100, att.ki + KI_HIT)
	ev.append({"t": "hit", "who": _who(att), "kind": kind, "dmg": d, "crit": crit, "guarded": guarded, "caught": caught})


# ---------------------------------------------------------------------------
# bocas
# ---------------------------------------------------------------------------
## [mood if it lands, chance] for a boca of this category against the foe,
## including the "já ouvi essa" penalty for repeats.
func boca_odds(cat: int) -> Array:
	var r: Array = Personality.reaction(foe.personality, cat)
	var mood: int = r[0]
	if mood == Personality.Mood.NONE:
		return [mood, 0.0]
	var chance: float = r[1] - Bocas.REPEAT_PENALTY * foe.times_heard(cat)
	return [mood, clampf(chance, 0.0, 1.0)]


func _boca(cat: int, ev: Array) -> void:
	var pool: Array = Bocas.LINES[cat]
	var line: String = pool[rng.randi() % pool.size()]
	var odds := boca_odds(cat)
	var landed: bool = odds[0] != Personality.Mood.NONE and rng.randf() < float(odds[1])
	var mood: int = odds[0] if landed else Personality.Mood.NONE
	foe.heard[cat] = foe.times_heard(cat) + 1
	var revealed_now := false
	if landed:
		foe.set_mood(mood)
		if not foe.revealed:
			foe.revealed = true          # a reaction tells you who he is
			revealed_now = true
		if mood == Personality.Mood.DESCONCENTRADO:
			foe.skip_action = true
			foe.guarding = false
			foe.parrying = false
		elif mood == Personality.Mood.FOCADO:
			foe.ki = mini(100, foe.ki + 25)
	var reply := Personality.line_for(foe.personality, mood, rng)
	ev.append({"t": "boca", "who": "hero", "cat": cat, "line": line, "mood": mood,
		"reply": reply, "reveal": revealed_now, "repeat": foe.times_heard(cat) > 1})


func _foe_taunt(ev: Array) -> void:
	var pool: Array = Personality.TAUNTS[foe.personality]
	var line: String = pool[rng.randi() % pool.size()]
	var rattled := rng.randf() < FOE_TAUNT_CHANCE
	if rattled:
		hero.set_mood(Personality.Mood.ABALADO)
	ev.append({"t": "taunt", "who": "foe", "line": line,
		"mood": Personality.Mood.ABALADO if rattled else Personality.Mood.NONE})


# ---------------------------------------------------------------------------
# AI + outcome
# ---------------------------------------------------------------------------
func _choose_intent() -> int:
	if foe.ki >= TECH_COST and rng.randf() < 0.45:
		return Act.TECH
	var w: Array = (Personality.AI_WEIGHTS[foe.personality] as Array).duplicate()
	match foe.mood:
		Personality.Mood.ENFURECIDO:
			w[1] *= 2.0
			w[2] = 0.0
			w[3] = 0.0
		Personality.Mood.INTIMIDADO:
			w[2] *= 2.0
			w[1] *= 0.4
		Personality.Mood.ABALADO:
			w[3] *= 0.5
	var acts := [Act.LIGHT, Act.HEAVY, Act.GUARD, Act.PARRY, Act.BOCA]
	var total := 0.0
	for x in w:
		total += x
	var roll := rng.randf() * total
	for i in w.size():
		roll -= w[i]
		if roll <= 0.0:
			return acts[i]
	return Act.LIGHT


func _check(ev: Array) -> void:
	if result != Result.ONGOING:
		return
	if foe.hp > 0 and not foe.surrendered:
		var quits := false
		if foe.mood == Personality.Mood.INTIMIDADO and foe.hp_ratio() <= SURRENDER_HP:
			quits = Personality.SURRENDER_LINES.has(foe.personality)
		if foe.personality == Personality.Id.GANANCIOSO and foe.hp_ratio() <= MERCENARY_QUIT_HP:
			quits = true
		if quits:
			foe.surrendered = true
			result = Result.SURRENDER
			ev.append({"t": "surrender", "who": "foe", "line": Personality.SURRENDER_LINES[foe.personality]})
			return
	if foe.hp <= 0:
		result = Result.WIN
		ev.append({"t": "ko", "who": "foe"})
	elif hero.hp <= 0:
		result = Result.LOSE
		ev.append({"t": "ko", "who": "hero"})


## What the hero can read of the foe's plan this turn.
func intent_text() -> String:
	var n := foe.name
	if intent_hidden:
		return "%s observa-te, impassível. Não consegues ler a intenção." % n
	match shown_intent:
		Act.LIGHT:
			return "%s avança o pé da frente: vem aí um golpe rápido." % n
		Act.HEAVY:
			return "%s ergue a espada acima da cabeça: golpe forte!" % n
		Act.GUARD:
			return "%s recua e fecha a guarda." % n
		Act.PARRY:
			return "%s baixa a lâmina e espera... está a convidar-te." % n
		Act.TECH:
			return "%s concentra o ki: técnica perigosa!" % n
		Act.BOCA:
			return "%s endireita-se e abre a boca para falar." % n
	return ""
