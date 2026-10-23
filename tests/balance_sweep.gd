extends SceneTree
## Balance sweep: godot --headless --path . -s tests/balance_sweep.gd
## Prints win rates per policy for a grid of foe stats.


func _init() -> void:
	for foe_id in ["tetsu", "guarda"]:
		var base: Dictionary = Foes.ALL[foe_id]
		print("== ", foe_id, " (", Personality.NAMES[base.personality], ")")
		for hp in [120, 140, 160]:
			for atk in [19, 21, 23]:
				var stats := {"hp": hp, "atk": atk, "def": base.def, "ki": base.ki}
				var make := func(s: int) -> Duel:
					return Duel.new(Foes.make_hero(), Fighter.make(base.name, stats, base.personality), s)
				var r := []
				for pol in [DuelPolicies.brute, DuelPolicies.reader, DuelPolicies.talker, DuelPolicies.informed, DuelPolicies.fool]:
					r.append(DuelPolicies.win_rate(make, pol, 300))
				print("hp %d atk %d | brute %.2f reader %.2f blind %.2f informed %.2f fool %.2f" % [hp, atk, r[0], r[1], r[2], r[3], r[4]])
	quit(0)
