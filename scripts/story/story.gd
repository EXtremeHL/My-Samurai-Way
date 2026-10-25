class_name Story
## Reads StoryData against a GameState: who is around, what they say.


static func ids() -> Array:
	return StoryData.CHARS.keys()


static func char_data(id: String) -> Dictionary:
	return StoryData.CHARS[id]


## Where this character is right now, or null when absent.
static func present(id: String, s: GameState) -> Variant:
	var c: Dictionary = StoryData.CHARS[id]
	for f in c.get("gone", []):
		if s.has(f):
			return null
	if c.has("when"):
		var any := false
		for cond in c.when:
			any = any or s.check(cond)
		if not any:
			return null
	var at: Dictionary = c.at
	if not at.has(s.period()):
		return null
	var pos: Vector3 = at[s.period()]
	var moved: Dictionary = c.get("moved", {})
	for f in moved:
		if s.has(f):
			pos = moved[f]
	return pos


static func display_name(id: String, s: GameState) -> String:
	var c: Dictionary = StoryData.CHARS[id]
	var n: String = c.name
	var names: Dictionary = c.get("names", {})
	for f in names:
		if s.has(f):
			n = names[f]
	return n


## Every name a speaker can appear under -> the portrait sheet to show.
## "Tu" is the hero; the narrator ("") has no portrait.
static func portrait_table() -> Dictionary:
	var table := {"Tu": "hero"}
	for id in StoryData.CHARS:
		var c: Dictionary = StoryData.CHARS[id]
		if c.sheet == "":
			continue
		table[c.name] = c.sheet
		for f in c.get("names", {}):
			table[c.names[f]] = c.sheet
	return table


static func entry_ok(e: Dictionary, s: GameState) -> bool:
	if e.get("chained", false):
		return false
	if e.get("once", false) and s.has("seen_" + e.id):
		return false
	return s.check(e.get("when", {}))


## The conversation this character has for the current state.
static func pick(id: String, s: GameState) -> Dictionary:
	for e in StoryData.CHARS[id].talks:
		if entry_ok(e, s):
			return e
	return {}


static func entry(entry_id: String) -> Dictionary:
	for id in StoryData.CHARS:
		for e in StoryData.CHARS[id].talks:
			if e.id == entry_id:
				return e
	return {}


static func owner_of(entry_id: String) -> String:
	for id in StoryData.CHARS:
		for e in StoryData.CHARS[id].talks:
			if e.id == entry_id:
				return id
	return ""


## All tag strings an entry can apply (after + every choice option).
static func entry_tags(e: Dictionary) -> Array:
	var out: Array = []
	if e.has("after"):
		out.append(e.after)
	for l in e.lines:
		if l is Dictionary:
			out.append_array(l.tags)
	return out


static func journal(s: GameState) -> Array:
	var out: Array = []
	for j in StoryData.JOURNAL:
		if s.has(j[0]):
			out.append(j[1])
	return out
