extends SceneTree
## Story logic tests: godot --headless --path . -s tests/test_story.gd

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
	test_clock()
	test_conditions_and_tags()
	test_data_integrity()
	test_no_dead_flags()
	test_everyone_has_something_to_say()
	test_schedules()
	test_routes_to_every_ending()
	print("RESULT: ", "PASS" if ok else "FAIL", " (%d checks)" % count)
	quit(0 if ok else 1)


# --- tiny story driver -----------------------------------------------------
## Talks to `id` (must be present), picks `choice` at the first choice line.
## Returns the commands produced.
func talk(s: GameState, id: String, choice := 0, expect := "") -> Array:
	var e := Story.pick(id, s)
	if expect != "" and e.get("id", "") != expect:
		print("      (talk %s gave '%s', expected '%s')" % [id, e.get("id", ""), expect])
		ok = false
	return run_entry(s, e, choice)


func run_entry(s: GameState, e: Dictionary, choice := 0) -> Array:
	s.set_flag("seen_" + e.id)
	var cmds: Array = []
	for l in e.lines:
		if l is Dictionary:
			cmds.append_array(s.apply(l.tags[choice]))
			break
	cmds.append_array(s.apply(e.get("after", "")))
	var out: Array = []
	for c in cmds:
		if c[0] == "chain":
			out.append_array(run_entry(s, Story.entry(c[1]), choice))
		else:
			out.append(c)
	return out


func duel(s: GameState, id: String, win: bool, kill := false) -> Array:
	var f: Dictionary = Foes.ALL[id]
	if not win:
		return s.apply(f.on_lose)
	var cmds := s.apply(f.on_win)
	cmds.append_array(s.apply(f.on_kill if kill else f.on_spare))
	return cmds


func to(s: GameState, day: int, period: String) -> void:
	while not (s.day == day and s.period() == period):
		if not s.advance_period():
			return


func has_cmd(cmds: Array, kind: String, arg := "") -> bool:
	for c in cmds:
		if c[0] == kind and (arg == "" or c[1] == arg):
			return true
	return false


# --- tests -----------------------------------------------------------------
func test_clock() -> void:
	var s := GameState.new()
	check(s.clock_text() == "Dia 1 · Tarde" and s.look() == "dourado", "the hero arrives on day 1, afternoon")
	check(not s.spend(GameState.UNITS_PER_PERIOD - 1), "time left after %d units" % (GameState.UNITS_PER_PERIOD - 1))
	check(s.spend(1), "part of the day ends after %d units" % GameState.UNITS_PER_PERIOD)
	s.advance_period()
	check(s.clock_text() == "Dia 1 · Noite" and s.units == 0 and s.look() == "noite", "afternoon -> night")
	s.advance_period()
	check(s.clock_text() == "Dia 2 · Manhã" and s.look() == "neblina", "night -> next morning")
	to(s, 3, "noite")
	check(s.is_last_period(), "day 3 night is the last part")
	check(not s.advance_period(), "time runs out after the third night")


func test_conditions_and_tags() -> void:
	var s := GameState.new()
	var cmds := s.apply("flag:a;rep:vila:+15;rep:corvo:-200;duel:tetsu;time:2;end:leave;mark:m")
	check(s.has("a") and s.rep.vila == 15 and s.rep.corvo == -100, "flag + rep tags (clamped to -100)")
	check(has_cmd(cmds, "duel", "tetsu") and has_cmd(cmds, "time") and has_cmd(cmds, "end", "leave"), "command tags returned")
	check(s.check({"flags": ["a"], "rep_min": {"vila": 10}, "period": ["tarde"]}), "conditions hold")
	check(not s.check({"noflags": ["a"]}) and not s.check({"day_min": 2}) and not s.check({"rep_max": {"vila": 5}}), "conditions fail")
	check(s.check({"anyflags": ["zz", "a"]}) and not s.check({"anyflags": ["zz"]}), "anyflags")
	check(not s.check({"since": {"m": 1}}), "since: not yet")
	s.advance_period()
	check(s.check({"since": {"m": 1}}), "since: one part of the day later")
	s.hero_hp = 20
	s.apply("heal:0.5")
	check(s.hero_hp == 75, "heal 50%% (20 -> %d)" % s.hero_hp)
	check(s.make_hero().atk == 18 and s.make_hero().hp == 75, "hero carries his wounds into the next duel")
	s.set_flag("espada_forjada")
	check(s.make_hero().atk > 18, "the reforged blade hits harder")


func test_data_integrity() -> void:
	var ids := {}
	var bad := []
	for id in StoryData.CHARS:
		var c: Dictionary = StoryData.CHARS[id]
		if c.sheet != "" and not ResourceLoader.exists("res://assets/sprites/char_%s.png" % c.sheet):
			bad.append("%s: missing sheet %s" % [id, c.sheet])
		for p in c.at:
			var pos: Vector3 = c.at[p]
			if not Village.BOUNDS.has_point(Vector2(pos.x, pos.z)):
				bad.append("%s: %s post outside the town" % [id, p])
		for e in c.talks:
			if ids.has(e.id):
				bad.append("duplicate entry id " + e.id)
			ids[e.id] = true
			if e.lines.is_empty():
				bad.append(e.id + ": no lines")
			for l in e.lines:
				if l is Dictionary and l.choice.size() != l.tags.size():
					bad.append(e.id + ": choice/tag count mismatch")
			for tags in Story.entry_tags(e):
				bad.append_array(_bad_tags(tags, e.id))
	for f in Foes.ALL:
		for k in ["on_win", "on_spare", "on_kill", "on_lose"]:
			bad.append_array(_bad_tags(Foes.ALL[f][k], f + "." + k))
		var has_spot := false
		for id in StoryData.CHARS:
			if StoryData.CHARS[id].sheet == Foes.ALL[f].sheet and StoryData.CHARS[id].has("duel_spot"):
				has_spot = true
		if not has_spot:
			bad.append("foe %s has no character with a duel_spot" % f)
		if not ResourceLoader.exists("res://assets/sprites/combat_%s.png" % Foes.ALL[f].sheet):
			bad.append("foe %s has no combat sheet" % f)
	for b in bad:
		print("      ", b)
	check(bad.is_empty(), "story data is consistent (%d entries)" % ids.size())


func _bad_tags(tags: String, where: String) -> Array:
	var bad := []
	for raw in tags.split(";", false):
		var p: PackedStringArray = raw.strip_edges().split(":")
		match p[0]:
			"flag", "unflag", "mark", "time", "heal":
				pass
			"rest":
				pass
			"rep":
				if not GameState.FACTIONS.has(p[1]):
					bad.append("%s: unknown faction %s" % [where, p[1]])
			"duel":
				if not Foes.ALL.has(p[1]):
					bad.append("%s: unknown foe %s" % [where, p[1]])
			"chain":
				if Story.entry(p[1]).is_empty():
					bad.append("%s: unknown chain %s" % [where, p[1]])
			"end":
				if not (p[1] in ["leave", "time"] or Endings.ALL.has(p[1])):
					bad.append("%s: unknown ending %s" % [where, p[1]])
			_:
				bad.append("%s: unknown tag %s" % [where, raw])
	return bad


## Every flag the story *reads* must be *written* somewhere.
func test_no_dead_flags() -> void:
	var written := {}
	var all_tags: Array = []
	for id in StoryData.CHARS:
		for e in StoryData.CHARS[id].talks:
			all_tags.append_array(Story.entry_tags(e))
	for f in Foes.ALL:
		for k in ["on_win", "on_spare", "on_kill", "on_lose"]:
			all_tags.append(Foes.ALL[f][k])
	for tags in all_tags:
		for raw in tags.split(";", false):
			var p: PackedStringArray = raw.strip_edges().split(":")
			if p[0] in ["flag", "mark"]:
				written[p[1]] = true
	var read := {}
	for id in StoryData.CHARS:
		var c: Dictionary = StoryData.CHARS[id]
		for f in c.get("gone", []):
			read[f] = id + ".gone"
		for f in c.get("moved", {}):
			read[f] = id + ".moved"
		for cond in c.get("when", []):
			for f in cond.get("flags", []) + cond.get("noflags", []) + cond.get("anyflags", []):
				read[f] = id + ".when"
		for e in c.talks:
			var w: Dictionary = e.get("when", {})
			for f in w.get("flags", []) + w.get("noflags", []) + w.get("anyflags", []):
				read[f] = e.id
			for f in w.get("since", {}):
				read[f] = e.id
	for j in StoryData.JOURNAL:
		read[j[0]] = "journal"
	var dead := []
	for f in read:
		if not written.has(f):
			dead.append("%s (read by %s)" % [f, read[f]])
	for d in dead:
		print("      never set: ", d)
	check(dead.is_empty(), "every flag the story reads can be set (%d flags)" % read.size())


## In every part of every day, whoever is around has something to say.
func test_everyone_has_something_to_say() -> void:
	var silent := []
	var states := [GameState.new()]
	var s2 := GameState.new()
	for f in ["salvou_oyuki", "venceu_tetsu", "corvo_membro", "espada_forjada", "sabe_corrupcao"]:
		s2.set_flag(f)
	states.append(s2)
	for s in states:
		for day in [1, 2, 3]:
			for p in GameState.PERIODS:
				s.day = day
				s.period_i = GameState.PERIODS.find(p)
				for id in Story.ids():
					if Story.present(id, s) != null and Story.pick(id, s).is_empty():
						silent.append("%s on day %d %s" % [id, day, p])
	for x in silent:
		print("      silent: ", x)
	check(silent.is_empty(), "nobody present is ever silent")


func test_schedules() -> void:
	var s := GameState.new()
	check(Story.present("guarda", s) != null, "the guard blocks the shrine by day")
	s.advance_period()
	check(Story.present("guarda", s) == null, "...but not at night")
	check(Story.present("bandido", s) != null, "a Corvo thug haunts the tea house at night")
	check(Story.pick("santuario", s).id == "santuario", "at night the shrine path is open")
	check(Story.present("kuroda", s) == null and Story.present("akamatsu", s) == null, "the bosses arrive on day 2")
	s.advance_period()
	check(Story.present("kuroda", s) != null and Story.present("akamatsu", s) != null, "day 2: Kuroda and Akamatsu are in the valley")
	var t := GameState.new()
	t.set_flag("venceu_tetsu")
	check(Story.present("kuroda", t) != null, "beating Tetsu draws Kuroda out early")
	t.set_flag("dead_tetsu")
	check(Story.present("tetsu", t) == null, "the dead stay gone")
	check(Story.pick("kuroda", t).id == "kuroda_vinganca", "...and Kuroda wants revenge")


func test_routes_to_every_ending() -> void:
	var reached := {}
	var s: GameState
	var c: Array

	# -- protetor: save Oyuki, learn the truth, beat both bosses --
	s = GameState.new()
	talk(s, "oyuki", 0, "oyuki_1")
	to(s, 1, "noite")
	c = talk(s, "bandido", 0, "bandido_1")
	check(has_cmd(c, "duel", "bandido"), "protetor: defending Oyuki starts a duel")
	duel(s, "bandido", true)
	talk(s, "oyuki", 0, "oyuki_salva")
	to(s, 2, "manha")
	talk(s, "heita", 0, "heita_corrupcao")
	talk(s, "kuroda", 1, "kuroda_1")             # refuse
	c = talk(s, "kuroda", 0, "kuroda_protetor")
	check(has_cmd(c, "duel", "kuroda"), "protetor: the village's champion challenges Kuroda (vila %d)" % s.rep.vila)
	duel(s, "kuroda", true)
	talk(s, "akamatsu", 1, "akamatsu_1")         # refuse the job
	c = talk(s, "akamatsu", 0, "akamatsu_acusacao")
	duel(s, "akamatsu", true)
	reached[Endings.on_event(s)] = true
	check(Endings.on_event(s) == "protetor", "route -> O Protetor de Kurogane")

	# -- corvo: join Kuroda, bring down the magistrate --
	s = GameState.new()
	to(s, 2, "manha")
	talk(s, "kuroda", 0, "kuroda_1")
	c = talk(s, "akamatsu", 0, "akamatsu_corvo")
	check(has_cmd(c, "duel", "akamatsu"), "corvo: a Corvo man can challenge Akamatsu")
	duel(s, "akamatsu", true, true)
	reached[Endings.on_event(s)] = true
	check(Endings.on_event(s) == "corvo", "route -> O Corvo Voa Alto")

	# -- lei: take the magistrate's contract on Kuroda --
	s = GameState.new()
	to(s, 2, "tarde")
	talk(s, "akamatsu", 0, "akamatsu_1")
	c = talk(s, "kuroda", 0, "kuroda_contrato")
	duel(s, "kuroda", true, true)
	reached[Endings.on_event(s)] = true
	check(Endings.on_event(s) == "lei", "route -> A Espada do Magistrado")

	# -- lamina: sneak past the guard at night, reforge the blade, leave --
	s = GameState.new()
	talk(s, "genzo", 0, "genzo_1")
	to(s, 1, "noite")
	c = talk(s, "santuario", 0, "santuario")
	check(s.has("aco_negro"), "lamina: the mine gives black steel at night")
	to(s, 2, "manha")
	talk(s, "genzo", 0, "genzo_aco")
	check(Story.pick("genzo", s).id == "genzo_espera", "lamina: forging takes time")
	to(s, 2, "tarde")
	talk(s, "genzo", 0, "genzo_pronta")
	check(s.has("espada_forjada"), "lamina: the blade is reborn")
	c = talk(s, "estrada", 0, "estrada")
	check(has_cmd(c, "end", "leave"), "lamina: the east road offers a way out")
	reached[Endings.evaluate(s, "leave")] = true
	check(Endings.evaluate(s, "leave") == "lamina", "route -> A Lâmina Renascida")

	# -- desertor: accept a job, walk away --
	s = GameState.new()
	to(s, 2, "manha")
	talk(s, "akamatsu", 0, "akamatsu_1")
	reached[Endings.evaluate(s, "leave")] = true
	check(Endings.evaluate(s, "leave") == "desertor", "route -> O Desertor")

	# -- vagabundo: leave at once --
	s = GameState.new()
	reached[Endings.evaluate(s, "leave")] = true
	check(Endings.evaluate(s, "leave") == "vagabundo", "route -> Só de Passagem")

	# -- odiado: side with the thug, then lose to the magistrate in public --
	s = GameState.new()
	to(s, 1, "noite")
	talk(s, "bandido", 1, "bandido_1")
	to(s, 2, "manha")
	talk(s, "kuroda", 0, "kuroda_1")
	talk(s, "akamatsu", 0, "akamatsu_corvo")
	duel(s, "akamatsu", false)
	reached[Endings.evaluate(s, "leave")] = true
	check(Endings.evaluate(s, "leave") == "odiado", "route -> O Ronin Maldito (vila %d)" % s.rep.vila)

	# -- chamas: join a side and let the clock run out --
	s = GameState.new()
	to(s, 2, "manha")
	talk(s, "kuroda", 0, "kuroda_1")
	to(s, 3, "noite")
	reached[Endings.evaluate(s, "time")] = true
	check(Endings.evaluate(s, "time") == "chamas", "route -> Kurogane em Chamas")

	# -- mais_um_dia: do nothing --
	s = GameState.new()
	to(s, 3, "noite")
	reached[Endings.evaluate(s, "time")] = true
	check(Endings.evaluate(s, "time") == "mais_um_dia", "route -> Mais Um Dia em Kurogane")

	# -- caido: lose to Kuroda --
	s = GameState.new()
	to(s, 2, "manha")
	talk(s, "akamatsu", 0)
	talk(s, "kuroda", 0, "kuroda_contrato")
	c = duel(s, "kuroda", false)
	check(has_cmd(c, "end", "caido"), "route -> O Último Corte")
	reached["caido"] = true

	var missing := []
	for e in Endings.ALL:
		if not reached.has(e):
			missing.append(e)
	check(missing.is_empty(), "all %d endings are reachable %s" % [Endings.ALL.size(), missing])
