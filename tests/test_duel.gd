extends SceneTree
## Duel logic tests (no autoloads needed):
##   godot --headless --path . -s tests/test_duel.gd

var ok := true
var count := 0


func check(cond: bool, msg: String) -> void:
	count += 1
	if cond:
		print("ok:   ", msg)
	else:
		print("FAIL: ", msg)
		ok = false


func new_duel(foe_id: String, seed_value: int) -> Duel:
	return Duel.new(Foes.make_hero(), Foes.make_foe(foe_id), seed_value)


func _init() -> void:
	if new_duel("tetsu", 0) == null:
		print("RESULT: FAIL (duel scripts failed to compile)")
		quit(1)
		return
	test_determinism()
	test_boca_tables()
	test_boca_is_free_but_costs_ki()
	test_repeat_penalty()
	test_distraction_cancels_action()
	test_rage_breaks_guard()
	test_feints_and_honesty()
	test_parry_and_guard()
	test_cowards_surrender()
	test_tech_cost()
	test_moods_shift_damage()
	test_policies()
	print("RESULT: ", "PASS" if ok else "FAIL", " (%d checks)" % count)
	quit(0 if ok else 1)


# --- helpers ---------------------------------------------------------------
func force_intent(d: Duel, a: int) -> void:
	d.turn += 1
	d.foe.skip_action = false
	d.boca_used = false
	d.intent = a
	d.shown_intent = a
	d.intent_hidden = false


func boca_until(foe_id: String, intent: int, cat: int, mood: int, tries := 60) -> Array:
	## Returns [duel, events] for the first seed where `cat` provokes `mood`.
	for i in tries:
		var d := new_duel(foe_id, 700 + i)
		force_intent(d, intent)
		var ev := d.say_boca(cat)
		if not ev.is_empty() and ev[0].mood == mood:
			return [d, ev]
	return []


# --- tests -----------------------------------------------------------------
func test_determinism() -> void:
	var a := new_duel("tetsu", 7)
	var b := new_duel("tetsu", 7)
	DuelPolicies.play(a, DuelPolicies.talker)
	DuelPolicies.play(b, DuelPolicies.talker)
	check(a.result == b.result and a.turn == b.turn and a.hero.hp == b.hero.hp, "same seed, same duel")


func test_boca_tables() -> void:
	var d := new_duel("tetsu", 1)
	check(d.boca_odds(Bocas.Cat.INSULTO)[0] == Personality.Mood.ENFURECIDO, "insulting a proud man enrages him")
	check(d.boca_odds(Bocas.Cat.AMEACA)[0] == Personality.Mood.MOTIVADO, "threatening a proud man fires him up")
	check(d.boca_odds(Bocas.Cat.TENTACAO)[0] == Personality.Mood.NONE, "bribing a proud man does nothing")
	var g := new_duel("guarda", 1)
	check(g.boca_odds(Bocas.Cat.AMEACA)[0] == Personality.Mood.INTIMIDADO, "threatening a coward intimidates him")
	check(g.boca_odds(Bocas.Cat.LISONJA)[0] == Personality.Mood.MOTIVADO, "flattering a coward emboldens him")
	var complete := true
	for p in Personality.Id.values():
		for c in Bocas.ORDER:
			complete = complete and Personality.REACTIONS[p].has(c)
		complete = complete and Personality.REACTION_LINES[p].has(Personality.Mood.NONE) and Personality.FEINT.has(p)
	check(complete, "tables cover every personality x category")
	var landed := 0
	for i in 400:
		var t := new_duel("tetsu", 500 + i)
		force_intent(t, Duel.Act.GUARD)
		if t.say_boca(Bocas.Cat.INSULTO)[0].mood == Personality.Mood.ENFURECIDO:
			landed += 1
	var rate := landed / 400.0
	check(absf(rate - 0.8) < 0.07, "insult lands on Tetsu ~80%% of the time (%.2f)" % rate)


func test_boca_is_free_but_costs_ki() -> void:
	var d := new_duel("tetsu", 2)
	force_intent(d, Duel.Act.GUARD)
	var turn0 := d.turn
	var ki0 := d.hero.ki
	d.say_boca(Bocas.Cat.TROCA)
	check(d.hero.ki == ki0 - Duel.BOCA_KI, "a boca costs %d ki" % Duel.BOCA_KI)
	check(d.turn == turn0 and d.result == Duel.Result.ONGOING, "a boca doesn't end the turn")
	check(not d.can_boca(), "only one boca per turn")
	check(d.say_boca(Bocas.Cat.INSULTO).is_empty(), "second boca in the same turn is refused")
	var poor := new_duel("tetsu", 2)
	poor.hero.ki = 10
	force_intent(poor, Duel.Act.GUARD)
	check(not poor.can_boca(), "no breath, no boca (ki < %d)" % Duel.BOCA_KI)


func test_repeat_penalty() -> void:
	var d := new_duel("tetsu", 3)
	var first: float = d.boca_odds(Bocas.Cat.TROCA)[1]
	force_intent(d, Duel.Act.GUARD)
	d.say_boca(Bocas.Cat.TROCA)
	var second: float = d.boca_odds(Bocas.Cat.TROCA)[1]
	check(second <= first - Bocas.REPEAT_PENALTY + 0.001, "'já ouvi essa': repeating a boca lowers its odds (%.2f -> %.2f)" % [first, second])


func test_distraction_cancels_action() -> void:
	var r := boca_until("guarda", Duel.Act.HEAVY, Bocas.Cat.TENTACAO, Personality.Mood.DESCONCENTRADO)
	check(not r.is_empty(), "bribing the guard can distract him")
	if r.is_empty():
		return
	var d: Duel = r[0]
	var hp0 := d.hero.hp
	var ev := d.play_turn(Duel.Act.OBSERVE)
	check(d.hero.hp == hp0, "a distracted foe loses his attack")
	check(ev.any(func(e): return e.t == "skip"), "skip event emitted")
	var r2 := boca_until("guarda", Duel.Act.GUARD, Bocas.Cat.TENTACAO, Personality.Mood.DESCONCENTRADO)
	var g: Duel = r2[0]
	var ev2 := g.play_turn(Duel.Act.HEAVY)
	var hit = ev2.filter(func(e): return e.t == "hit" and e.who == "hero")
	check(hit.is_empty() or not hit[0].guarded, "a distracted foe drops his guard")


func test_rage_breaks_guard() -> void:
	var r := boca_until("tetsu", Duel.Act.PARRY, Bocas.Cat.INSULTO, Personality.Mood.ENFURECIDO)
	check(not r.is_empty(), "insult can enrage Tetsu")
	var d: Duel = r[0]
	check(d.intent == Duel.Act.HEAVY and d.shown_intent == Duel.Act.HEAVY, "enraged, he drops the parry and charges")
	check(r[1].any(func(e): return e.t == "intent_change"), "intent change is announced")


func test_feints_and_honesty() -> void:
	var feints := 0
	for i in 400:
		var d := new_duel("guarda", 900 + i)
		d.begin_turn()
		if d.shown_intent != d.intent:
			feints += 1
	check(feints > 20, "cowards feint sometimes (%d/400)" % feints)
	var lies := 0
	for i in 200:
		var d := new_duel("guarda", 900 + i)
		d.foe.set_mood(Personality.Mood.ABALADO)
		d.begin_turn()
		if d.shown_intent != d.intent or d.intent_hidden:
			lies += 1
	check(lies == 0, "a shaken foe can't feint")
	var hot := new_duel("tetsu", 4)
	var never := 0
	for i in 200:
		var d := Duel.new(Foes.make_hero(), Fighter.make("x", {"hp": 100, "atk": 10, "def": 5}, Personality.Id.COLERICO), i)
		d.begin_turn()
		if d.shown_intent != d.intent:
			never += 1
	check(never == 0, "hotheads never feint")


func test_parry_and_guard() -> void:
	var d := new_duel("tetsu", 11)
	force_intent(d, Duel.Act.HEAVY)
	var hp_h := d.hero.hp
	var hp_f := d.foe.hp
	var ev := d.play_turn(Duel.Act.PARRY)
	check(d.hero.hp == hp_h, "parrying a heavy blow takes no damage")
	check(d.foe.hp < hp_f - 12, "parry counter hurts (%d)" % (hp_f - d.foe.hp))
	check(ev.any(func(e): return e.t == "parried" and e.by == "hero"), "parried event")
	var t := new_duel("tetsu", 12)
	force_intent(t, Duel.Act.TECH)
	t.foe.ki = 100
	var hp_t := t.hero.hp
	t.play_turn(Duel.Act.PARRY)
	check(t.hero.hp < hp_t, "techniques can't be parried")
	var raw := 0
	var guarded := 0
	for i in 60:
		var a := new_duel("tetsu", 200 + i)
		force_intent(a, Duel.Act.LIGHT)
		var h0 := a.hero.hp
		a.play_turn(Duel.Act.OBSERVE)
		raw += h0 - a.hero.hp
		var b := new_duel("tetsu", 200 + i)
		force_intent(b, Duel.Act.LIGHT)
		var h1 := b.hero.hp
		b.play_turn(Duel.Act.GUARD)
		guarded += h1 - b.hero.hp
	check(guarded < raw * 0.5, "guard cuts light damage (%d vs %d)" % [guarded, raw])
	var w := new_duel("tetsu", 13)
	force_intent(w, Duel.Act.GUARD)
	var wev := w.play_turn(Duel.Act.PARRY)
	check(wev.any(func(e): return e.t == "parry_wasted" and e.who == "hero"), "parry into a guard is wasted")


func test_cowards_surrender() -> void:
	var surrendered := false
	for i in 40:
		var t := new_duel("guarda", 300 + i)
		t.foe.hp = 20
		force_intent(t, Duel.Act.GUARD)
		var ev := t.say_boca(Bocas.Cat.AMEACA)
		if ev[0].mood == Personality.Mood.INTIMIDADO:
			surrendered = t.result == Duel.Result.SURRENDER and ev.any(func(e): return e.t == "surrender")
			break
	check(surrendered, "an intimidated coward at low HP surrenders")
	var proud := new_duel("tetsu", 6)
	proud.foe.hp = 10
	force_intent(proud, Duel.Act.GUARD)
	proud.say_boca(Bocas.Cat.AMEACA)
	check(proud.result == Duel.Result.ONGOING, "a proud man never surrenders")


func test_tech_cost() -> void:
	var d := new_duel("tetsu", 8)
	check(not d.can_use(Duel.Act.TECH), "technique locked at low ki")
	d.hero.ki = 70
	check(d.can_use(Duel.Act.TECH), "technique unlocked at 60 ki")
	force_intent(d, Duel.Act.GUARD)
	d.play_turn(Duel.Act.TECH)
	check(d.hero.ki < 40, "technique spends ki (%d left)" % d.hero.ki)


func test_moods_shift_damage() -> void:
	var d := new_duel("tetsu", 9)
	var base := d.damage_of(d.foe, d.hero, Duel.Act.LIGHT)
	d.foe.set_mood(Personality.Mood.MOTIVADO)
	var fired := d.damage_of(d.foe, d.hero, Duel.Act.LIGHT)
	d.foe.set_mood(Personality.Mood.ABALADO)
	var shaken := d.damage_of(d.foe, d.hero, Duel.Act.LIGHT)
	check(fired > base and shaken < base, "mood changes foe damage (abalado %d < base %d < motivado %d)" % [shaken, base, fired])
	d.foe.set_mood(Personality.Mood.ENFURECIDO)
	var hit_enraged := d.damage_of(d.hero, d.foe, Duel.Act.LIGHT)
	var his_enraged := d.damage_of(d.foe, d.hero, Duel.Act.LIGHT)
	d.foe.set_mood(Personality.Mood.NONE)
	var hit_calm := d.damage_of(d.hero, d.foe, Duel.Act.LIGHT)
	check(hit_enraged >= hit_calm + 2, "an enraged foe is easier to hurt (%d vs %d)" % [hit_enraged, hit_calm])
	check(his_enraged > base, "...and hits harder (%d vs %d): a double-edged boca" % [his_enraged, base])
	for m in Personality.MOOD_TURNS:
		d.foe.set_mood(m)
		for _t in 5:
			d.foe.tick_mood()
		check(d.foe.mood == Personality.Mood.NONE, "%s wears off" % Personality.MOOD_NAMES[m])


## Does talking well actually win duels, and does talking badly lose them?
func test_policies() -> void:
	for foe_id in ["tetsu", "guarda"]:
		var make := func(s: int) -> Duel: return new_duel(foe_id, s)
		var rb := DuelPolicies.win_rate(make, DuelPolicies.brute)
		var rr := DuelPolicies.win_rate(make, DuelPolicies.reader)
		var rt := DuelPolicies.win_rate(make, DuelPolicies.talker)
		var ri := DuelPolicies.win_rate(make, DuelPolicies.informed)
		var rf := DuelPolicies.win_rate(make, DuelPolicies.fool)
		print("      %s: brute %.2f | reader %.2f | blind talker %.2f | informed %.2f | fool %.2f" % [foe_id, rb, rr, rt, ri, rf])
		check(rb >= 0.08 and rb <= 0.5, "%s: mashing attack usually loses (%.2f)" % [foe_id, rb])
		check(rr >= rb + 0.2, "%s: reading intents beats mashing (%.2f vs %.2f)" % [foe_id, rr, rb])
		check(rr <= 0.85, "%s: reading alone is not a sure win (%.2f)" % [foe_id, rr])
		check(rt >= rr + 0.04, "%s: talking, even blind, beats silence (%.2f vs %.2f)" % [foe_id, rt, rr])
		check(ri >= rr + 0.1, "%s: the right boca for his temperament wins more (%.2f vs %.2f)" % [foe_id, ri, rr])
		check(rf <= rr - 0.25, "%s: the wrong boca loses duels (%.2f vs %.2f)" % [foe_id, rf, rr])
	# the boss: the black-steel quest is what makes Kuroda beatable
	var broken := func(sd: int) -> Duel: return Duel.new(GameState.new().make_hero(), Foes.make_foe("kuroda"), sd)
	var forged := func(sd: int) -> Duel:
		var gs := GameState.new()
		gs.set_flag("espada_forjada")
		return Duel.new(gs.make_hero(), Foes.make_foe("kuroda"), sd)
	var kb := DuelPolicies.win_rate(broken, DuelPolicies.informed, 300)
	var kf := DuelPolicies.win_rate(forged, DuelPolicies.informed, 300)
	print("      kuroda (informed): broken blade %.2f | black steel %.2f" % [kb, kf])
	check(kb <= 0.6, "Kuroda is a real boss with a broken blade (%.2f)" % kb)
	check(kf >= kb + 0.2, "the reforged blade makes Kuroda beatable (%.2f vs %.2f)" % [kf, kb])
