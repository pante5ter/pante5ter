class_name IntrigueBoard
extends RefCounted

## Reads clue keys ("suspect_id:kind:index") against the content, and the board back from the log.
const ALIBI: String = "alibi"
const HERRING: String = "herring"
const GUILTY: String = "guilty"
const TRAIL: String = "trail"


static func parts(key: String) -> PackedStringArray:
	return key.split(":")


static func text(def: IntrigueDef, key: String) -> String:
	return _lookup(def, key, true)


static func place(def: IntrigueDef, key: String) -> String:
	return _lookup(def, key, false)


## The card a clue hangs under. A trail names nobody, so it never gives the rat away.
static func subject(key: String) -> String:
	var split := parts(key)
	if split.size() < 2 or split[1] == TRAIL:
		return ""
	return split[0]


## Saves from before trails existed count the rat's clues on from the named ones: "guilty:1" is the first trail.
static func _lookup(def: IntrigueDef, key: String, want_text: bool) -> String:
	var split := parts(key)
	if def == null or split.size() < 3:
		return ""
	var person := def.suspect(split[0])
	if person == null:
		return ""
	var index := int(split[2])
	match split[1]:
		ALIBI:
			return person.alibi_clue if want_text else person.alibi_place
		HERRING:
			return person.herring_clue if want_text else person.herring_place
		GUILTY:
			if index >= person.guilty_clues.size():
				return _pick(person.trail_clues if want_text else person.trail_places, index - person.guilty_clues.size())
			return _pick(person.guilty_clues if want_text else person.guilty_places, index)
		TRAIL:
			return _pick(person.trail_clues if want_text else person.trail_places, index)
	return ""


static func _pick(list: PackedStringArray, index: int) -> String:
	return list[index] if index >= 0 and index < list.size() else ""


## Every clue brought so far, oldest first, as Reggie pinned it up.
static func pinned(def: IntrigueDef, event_log: EventLog) -> Array[IntrigueClue]:
	var found: Array[IntrigueClue] = []
	for event: SimEvent in event_log.of_type(EventLog.INTRIGUE_CLUE):
		var key := String(event.data.get("clue", ""))
		var clue := IntrigueClue.new()
		clue.key = key
		clue.suspect_id = subject(key)
		clue.text = text(def, key)
		clue.place = place(def, key)
		clue.found_at = event.game_time
		clue.number = int(event.data.get("number", found.size() + 1))
		if not clue.text.is_empty():
			found.append(clue)
	return found


## Board columns in a fixed order: the raid itself first, then the suspects as the content lists them.
static func cases(def: IntrigueDef, clues: Array[IntrigueClue]) -> PackedStringArray:
	var order := PackedStringArray()
	var ids := PackedStringArray([""])
	if def != null:
		for person: SuspectDef in def.suspects:
			ids.append(person.id)
	for suspect_id: String in ids:
		for clue: IntrigueClue in clues:
			if clue.suspect_id == suspect_id:
				order.append(suspect_id)
				break
	return order
