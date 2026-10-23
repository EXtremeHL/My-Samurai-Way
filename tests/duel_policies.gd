class_name DuelPolicies
## Scripted players used by tests and the balance sweep. A policy may call
## d.say_boca() itself, then returns the action to play.


static func brute(d: Duel) -> int:
	return Duel.Act.TECH if d.can_use(Duel.Act.TECH) else Duel.Act.LIGHT


## Reads the intent the foe shows (feints included) but never talks.
static func reader(d: Duel) -> int:
	if not d.intent_hidden:
		match d.shown_intent:
			Duel.Act.HEAVY:
				return Duel.Act.PARRY
			Duel.Act.TECH:
				return Duel.Act.GUARD
			Duel.Act.GUARD:
				return Duel.Act.HEAVY
	return brute(d)


## Already knows the foe's temperament (town gossip, an earlier duel).
static func informed(d: Duel) -> int:
	d.foe.revealed = true
	return talker(d)


## Talks first: probes an unknown foe, then uses the boca that suits him.
static func talker(d: Duel) -> int:
	if d.can_boca() and d.foe.mood == Personality.Mood.NONE:
		var cat := -1
		if d.foe.revealed:
			var best_odds := 0.4
			for c in Bocas.ORDER:
				var o := d.boca_odds(c)
				if o[0] in Personality.GOOD_FOR_SPEAKER and o[1] >= best_odds:
					cat = c
					best_odds = o[1]
		else:
			cat = Bocas.Cat.TROCA if d.foe.times_heard(Bocas.Cat.TROCA) == 0 else Bocas.Cat.AMEACA
		if cat >= 0:
			d.say_boca(cat)
	return reader(d)


## Like the talker, but always picks the boca that backfires on this foe.
static func fool(d: Duel) -> int:
	if d.can_boca() and d.foe.mood == Personality.Mood.NONE:
		for c in Bocas.ORDER:
			var r: Array = Personality.reaction(d.foe.personality, c)
			if r[0] == Personality.Mood.MOTIVADO or r[0] == Personality.Mood.FOCADO:
				d.say_boca(c)
				break
	return reader(d)


static func play(d: Duel, policy: Callable) -> int:
	while d.result == Duel.Result.ONGOING and d.turn < 60:
		d.begin_turn()
		var a: int = policy.call(d)
		if d.result == Duel.Result.ONGOING:
			d.play_turn(a)
	return d.result


static func win_rate(make: Callable, policy: Callable, n := 400) -> float:
	var wins := 0
	for i in n:
		var d: Duel = make.call(1000 + i)
		var r := play(d, policy)
		if r == Duel.Result.WIN or r == Duel.Result.SURRENDER:
			wins += 1
	return float(wins) / n
