class_name Intrigue
extends RefCounted

## After the first raid: somebody told the gang about the container. The rat is drawn when the
## arc starts and every clue Finn brings is true, so the right answer can be worked out.
enum Phase { WAITING, OPENING, INVESTIGATING, ACCUSING, DONE }

const ACTOR: String = "finn"
const ACCUSE_STORY_ID: String = "intrigue_accuse"
const ALIBI: String = "alibi"
const GUILTY: String = "guilty"
const CAUGHT: String = "caught"
const WRONG: String = "wrong"
const RETALIATED: String = "retaliated"
const RETALIATION_FAILED: String = "retaliation_failed"

var phase: Phase = Phase.DONE
var rat: int = -1
## Planned clues as "suspect_id:kind:index", in the order Finn brings them.
var schedule: Array[String] = []
var clues_given: int = 0
var next_clue_at: float = INF
var boss_named: bool = false
var seen_events: int = 0

var _def: IntrigueDef
var _rng: SimRng
var _stories: Stories
var _raids: Raids
var _couriers: Couriers
var _suspicion: Suspicion
var _event_log: EventLog


func _init(config: BalanceConfig, rng: SimRng, stories: Stories, raids: Raids, couriers: Couriers, suspicion: Suspicion, event_log: EventLog) -> void:
	_def = config.intrigue
	_rng = rng
	_stories = stories
	_raids = raids
	_couriers = couriers
	_suspicion = suspicion
	_event_log = event_log
	seen_events = event_log.size()
	if _def != null and _def.opening_story != null and not _def.suspects.is_empty():
		phase = Phase.WAITING


static func phase_name(value: Phase) -> String:
	return String(Phase.keys()[value]).to_lower()


func definition() -> IntrigueDef:
	return _def


func rat_suspect() -> SuspectDef:
	return _def.suspects[rat] if _def != null and rat >= 0 and rat < _def.suspects.size() else null


static func clue_parts(key: String) -> PackedStringArray:
	return key.split(":")


func clue_text(key: String) -> String:
	var parts := clue_parts(key)
	var person := _def.suspect(parts[0]) if _def != null else null
	if person == null:
		return ""
	if parts[1] == ALIBI:
		return person.alibi_clue
	var index := int(parts[2])
	return person.guilty_clues[index] if index < person.guilty_clues.size() else ""


func given_clues() -> Array[String]:
	return schedule.slice(0, clues_given)


func next_event_time() -> float:
	if phase != Phase.INVESTIGATING:
		return INF
	if clues_given < schedule.size():
		return next_clue_at
	return INF


func update(now: float) -> void:
	if phase == Phase.DONE:
		seen_events = _event_log.size()
		return
	var raided := false
	var answers: Array[SimEvent] = []
	for event: SimEvent in _event_log.since(seen_events):
		if event.type == EventLog.RAID_RESOLVED:
			raided = true
		elif event.type == EventLog.STORY_RESOLVED:
			answers.append(event)
	seen_events = _event_log.size()
	match phase:
		Phase.WAITING:
			if raided:
				_start(now)
		Phase.OPENING:
			_try_open(now)
			for answer: SimEvent in answers:
				if String(answer.data["story_id"]) == _def.opening_story.id:
					_opening_answered(int(answer.data["choice"]), answer.data["worked"] == true, now)
		Phase.ACCUSING:
			if not _stories.used.has(ACCUSE_STORY_ID):
				_try_accuse(now)
			for answer: SimEvent in answers:
				if String(answer.data["story_id"]) == ACCUSE_STORY_ID:
					_accused(int(answer.data["choice"]), now)
	if phase == Phase.INVESTIGATING:
		_bring_clues(now)
	seen_events = _event_log.size()


func _start(now: float) -> void:
	rat = _rng.randi_range(0, _def.suspects.size() - 1)
	schedule.clear()
	for index: int in _def.suspects.size():
		var person := _def.suspects[index]
		if index == rat:
			for clue: int in person.guilty_clues.size():
				schedule.append("%s:%s:%d" % [person.id, GUILTY, clue])
		else:
			schedule.append("%s:%s:0" % [person.id, ALIBI])
	for index: int in range(schedule.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var swap := schedule[index]
		schedule[index] = schedule[other]
		schedule[other] = swap
	phase = Phase.OPENING
	_event_log.record(EventLog.INTRIGUE_STARTED, now, PackedStringArray([ACTOR]), {"rat": rat_suspect().id})
	_try_open(now)


## A story already on screen goes first; the opening waits for Jack's answer to it.
func _try_open(now: float) -> void:
	if not _stories.is_pending() and not _stories.used.has(_def.opening_story.id):
		_stories.start(_def.opening_story, now, ACTOR)


func _opening_answered(choice: int, worked: bool, now: float) -> void:
	var path := ""
	match choice:
		IntrigueDef.INVESTIGATE:
			path = "investigate"
			phase = Phase.INVESTIGATING
			next_clue_at = now + _def.clue_interval_hours * SimClock.GAME_SECONDS_PER_HOUR
		IntrigueDef.PAY_BOSS:
			path = "pay_boss"
			boss_named = true
			_raids.calm(now + _def.paid_calm_days * SimClock.GAME_SECONDS_PER_DAY)
			phase = Phase.ACCUSING
		_:
			path = "retaliate"
			if worked:
				_raids.calm(now + _def.retaliated_calm_days * SimClock.GAME_SECONDS_PER_DAY)
			else:
				_raids.expect()
			_finish(RETALIATED if worked else RETALIATION_FAILED, "", now)
			return
	_event_log.record(EventLog.INTRIGUE_STEP, now, PackedStringArray([ACTOR]), {"path": path})
	if phase == Phase.ACCUSING:
		_try_accuse(now)


func _bring_clues(now: float) -> void:
	while clues_given < schedule.size() and now >= next_clue_at:
		var key := schedule[clues_given]
		clues_given += 1
		var parts := clue_parts(key)
		_event_log.record(EventLog.INTRIGUE_CLUE, next_clue_at, PackedStringArray([ACTOR, parts[0]]), {
			"clue": key,
			"number": clues_given,
			"of": schedule.size(),
		})
		next_clue_at += _def.clue_interval_hours * SimClock.GAME_SECONDS_PER_HOUR
	if clues_given >= schedule.size():
		next_clue_at = INF
		phase = Phase.ACCUSING
		_try_accuse(now)


func _try_accuse(now: float) -> void:
	if _stories.is_pending() or _stories.used.has(ACCUSE_STORY_ID):
		return
	_stories.register(accusation())
	_stories.start(_stories.find(ACCUSE_STORY_ID), now, ACTOR)


## Built from the saved state, so a load mid-accusation shows the same question.
func accusation() -> StoryDef:
	var story := StoryDef.new()
	story.id = ACCUSE_STORY_ID
	story.kind = StoryDef.SCRIPT
	var lines: Array[DialogueLineDef] = []
	lines.append_array(_def.accuse_lines)
	for key: String in given_clues():
		lines.append(DialogueLineDef.make(_def.finn_speaker, clue_text(key)))
	if boss_named:
		lines.append(DialogueLineDef.make(_def.boss_speaker, _def.boss_name_line % rat_suspect().display_name))
	story.lines = lines
	var choices: Array[StoryChoiceDef] = []
	for index: int in _def.suspects.size():
		var person := _def.suspects[index]
		var choice := StoryChoiceDef.new()
		choice.label = person.accuse_label
		choice.reply = person.guilty_reply if index == rat else person.innocent_reply
		choices.append(choice)
	story.choices = choices
	return story


func _accused(choice: int, now: float) -> void:
	var accused := _def.suspects[clampi(choice, 0, _def.suspects.size() - 1)]
	if choice == rat:
		_suspicion.add(-_def.caught_relief)
		_stories.shift(Stories.CREW, _def.caught_crew)
		_raids.calm(now + _def.caught_calm_days * SimClock.GAME_SECONDS_PER_DAY)
		if not accused.courier_id.is_empty():
			_couriers.dismiss(accused.courier_id, now, ACTOR, Couriers.REASON_RAT, true)
		_finish(CAUGHT, accused.id, now)
		return
	# The innocent reply has him walk out; a courier who drove for Jack goes with it.
	if not accused.courier_id.is_empty():
		_couriers.dismiss(accused.courier_id, now, ACTOR, Couriers.REASON_INSULTED, false)
	_suspicion.add(_def.wrong_suspicion)
	_stories.shift(Stories.VILLAGE, _def.wrong_village)
	_raids.expect()
	_finish(WRONG, accused.id, now)


func _finish(outcome: String, accused_id: String, now: float) -> void:
	phase = Phase.DONE
	_event_log.record(EventLog.INTRIGUE_RESOLVED, now, PackedStringArray([ACTOR]), {
		"outcome": outcome,
		"rat": rat_suspect().id,
		"accused": accused_id,
	})


func to_dict() -> Dictionary:
	return {
		"phase": phase_name(phase),
		"rat": rat,
		"schedule": schedule.duplicate(),
		"clues_given": clues_given,
		"next_clue_at": ExactFloat.encode(next_clue_at),
		"boss_named": boss_named,
		"seen_events": seen_events,
	}


func load_dict(data: Dictionary) -> void:
	phase = Phase.get(String(data["phase"]).to_upper(), Phase.DONE) as Phase
	rat = int(data["rat"])
	schedule.clear()
	for key: Variant in data["schedule"] as Array:
		schedule.append(String(key))
	clues_given = int(data["clues_given"])
	next_clue_at = ExactFloat.decode(data["next_clue_at"])
	boss_named = data["boss_named"] == true
	seen_events = int(data["seen_events"])
	if phase == Phase.ACCUSING and _stories.used.has(ACCUSE_STORY_ID):
		_stories.register(accusation())
