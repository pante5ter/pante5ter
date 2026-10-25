class_name Meetings
extends RefCounted

## Who Jack has already met. A character's intro is told once: the opening cast with the prologue,
## the rest when their first-meeting event turns up in the log after it.

var met: Array[String] = []
## Met in the world, intro not told yet; in the order they turned up.
var due: Array[String] = []
var seen_events: int = 0

var _cast: CastDef
var _event_log: EventLog


func _init(config: BalanceConfig, event_log: EventLog) -> void:
	_cast = config.cast
	_event_log = event_log
	seen_events = event_log.size()


func characters() -> Array[CharacterDef]:
	var found: Array[CharacterDef] = []
	if _cast != null:
		found.append_array(_cast.characters)
	return found


func find(character_id: String) -> CharacterDef:
	return _cast.find(character_id) if _cast != null else null


func has_met(character_id: String) -> bool:
	return met.has(character_id)


## The opening cast not met yet, in story order.
func opening() -> Array[CharacterDef]:
	var found: Array[CharacterDef] = []
	for character: CharacterDef in characters():
		if character.meeting == CharacterDef.OPENING and not has_met(character.id):
			found.append(character)
	return found


## The first due intro Jack can hear where he is; `place` empty matches only intros that play anywhere.
func next_due(place: String) -> CharacterDef:
	for character_id: String in due:
		var character := find(character_id)
		if character != null and (character.place.is_empty() or character.place == place):
			return character
	return null


## Story order: nobody introduces themselves before the opening night is told,
## so a game started without the prologue has no intros at all.
func opened() -> bool:
	return opening().is_empty()


func update(_now: float) -> void:
	if not opened():
		seen_events = _event_log.size()
		return
	for event: SimEvent in _event_log.since(seen_events):
		for character: CharacterDef in characters():
			if not has_met(character.id) and not due.has(character.id) and character.is_met_by(event):
				due.append(character.id)
	seen_events = _event_log.size()


func meet(character_id: String, now: float, actor: String) -> CommandResult:
	if find(character_id) == null:
		return CommandResult.failure(CommandResult.UNKNOWN_COMMAND)
	if has_met(character_id):
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	due.erase(character_id)
	met.append(character_id)
	_event_log.record(EventLog.CHARACTER_MET, now, PackedStringArray([actor, character_id]), {"character_id": character_id})
	return CommandResult.success()


## A save from before the intros: Jack has long known everyone, nobody introduces themselves mid-game.
func meet_everyone() -> void:
	due.clear()
	for character: CharacterDef in characters():
		if not has_met(character.id):
			met.append(character.id)
	seen_events = _event_log.size()


func to_dict() -> Dictionary:
	return {"met": met.duplicate(), "due": due.duplicate(), "seen_events": seen_events}


func load_dict(data: Dictionary) -> void:
	met.clear()
	for character_id: Variant in data.get("met", []) as Array:
		met.append(String(character_id))
	due.clear()
	for character_id: Variant in data.get("due", []) as Array:
		due.append(String(character_id))
	seen_events = clampi(int(data.get("seen_events", _event_log.size())), 0, _event_log.size())
