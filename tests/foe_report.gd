extends SceneTree
## Win rates of every scripted style against every foe at full health:
##   godot --headless --path . -s tests/foe_report.gd


func _init() -> void:
	for forged in [false, true]:
		print("== hero blade: ", "aço negro (atk 24)" if forged else "partida (atk 18)")
		_report(forged)
	quit(0)


func _report(forged: bool) -> void:
	print("foe          personality   brute  reader  blind  informed  fool")
	for id in Foes.ALL:
		var d: Dictionary = Foes.ALL[id]
		var make := func(s: int) -> Duel:
			var gs := GameState.new()
			if forged:
				gs.set_flag("espada_forjada")
			return Duel.new(gs.make_hero(), Foes.make_foe(id), s)
		var r := []
		for pol in [DuelPolicies.brute, DuelPolicies.reader, DuelPolicies.talker, DuelPolicies.informed, DuelPolicies.fool]:
			r.append(DuelPolicies.win_rate(make, pol, 300))
		print("%-12s %-12s  %.2f   %.2f   %.2f    %.2f    %.2f" % [id, Personality.NAMES[d.personality], r[0], r[1], r[2], r[3], r[4]])
