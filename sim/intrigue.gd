class_name Intrigue
extends RefCounted

## After the first raid: somebody told the gang about the container. The rat is drawn when the
## arc starts and every clue Reggie brings is true, so the right answer can be worked out —
## though only by putting two of them together. Nobody is suspected before Jack has met him.
enum Phase { WAITING, OPENING, INVESTIGATING, ACCUSING, DONE }

const ACTOR: String = "reggie"
const ACCUSE_STORY_ID: String = "intrigue_accuse"
const ALIBI: String = IntrigueBoard.ALIBI
const HERRING: String = IntrigueBoard.HERRING
const GUILTY: String = IntrigueBoard.GUILTY
const TRAIL: String = IntrigueBoard.TRAIL
const WAITED: String = "wait"
const CAUGHT: String = "caught"
const WRONG: String = "wrong"
const RETALIATED: String = "retaliated"
const RETALIATION_FAILED: String = "retaliation_failed"

var phase: Phase = Phase.DONE
var rat: int = -1
## Planned clues as "suspect_id:kind:index", in the order Reggie brings them.
var schedule: Array[String] = []
var clues_given: int = 0
var next_clue_at: float = INF
var boss_named: bool = false
## Jack asked for more time: the accusation comes back at this game time; 0 when not waiting.
var accuse_at: float = 0.0
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
	return IntrigueBoard.parts(key)


func clue_text(key: String) -> String:
	return IntrigueBoard.text(_def, key)


func given_clues() -> Array[String]:
	return schedule.slice(0, clues_given)


## Jack has met him, or at least heard of him: his introduction story has been told.
## A courier suspect only counts once Jack has actually hired him.
func is_introduced(person: SuspectDef) -> bool:
	if not person.courier_id.is_empty() and not _couriers.hired.has(person.courier_id):
		return false
	return person.intro_story == null or _stories.used.has(person.intro_story.id)


## Someone whose introduction cannot be told is left out of the hunt altogether.
func _can_meet(person: SuspectDef) -> bool:
	if not person.courier_id.is_empty() and not _couriers.hired.has(person.courier_id):
		return false
	return is_introduced(person) or (person.intro_story != null and not person.intro_story.choices.is_empty())


## The names the accusation offers, in content order.
func accusable() -> Array[SuspectDef]:
	var found: Array[SuspectDef] = []
	if _def == null:
		return found
	for person: SuspectDef in _def.suspects:
		if is_introduced(person):
			found.append(person)
	return found


func next_event_time() -> float:
	if phase == Phase.ACCUSING and accuse_at > 0.0:
		return accuse_at
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
			for answer: SimEvent in answers:
				if String(answer.data["story_id"]) == ACCUSE_STORY_ID:
					_accused(int(answer.data["choice"]), now)
			if accuse_at > 0.0 and now >= accuse_at:
				accuse_at = 0.0
			if phase == Phase.ACCUSING and not _stories.used.has(ACCUSE_STORY_ID):
				_try_accuse(now)
	if phase == Phase.INVESTIGATING and _introduce(now):
		if next_clue_at == INF and clues_given < schedule.size():
			next_clue_at = now + _def.clue_interval_hours * SimClock.GAME_SECONDS_PER_HOUR
		next_clue_at = maxf(next_clue_at, now)
		_bring_clues(now)
	seen_events = _event_log.size()


func _start(now: float) -> void:
	var cast: Array[int] = []
	for index: int in _def.suspects.size():
		if _can_meet(_def.suspects[index]):
			cast.append(index)
	if cast.is_empty():
		phase = Phase.DONE
		return
	rat = cast[_rng.randi_range(0, cast.size() - 1)]
	schedule.clear()
	for index: int in cast:
		var person := _def.suspects[index]
		if not person.herring_clue.is_empty():
			schedule.append("%s:%s:0" % [person.id, HERRING])
		if index == rat:
			for clue: int in person.guilty_clues.size():
				schedule.append("%s:%s:%d" % [person.id, GUILTY, clue])
			for clue: int in person.trail_clues.size():
				schedule.append("%s:%s:%d" % [person.id, TRAIL, clue])
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
			# The clock starts once everybody on the list has been met; see update().
			next_clue_at = INF
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
		var subject := IntrigueBoard.subject(key)
		var actors := PackedStringArray([ACTOR]) if subject.is_empty() else PackedStringArray([ACTOR, subject])
		_event_log.record(EventLog.INTRIGUE_CLUE, next_clue_at, actors, {
			"clue": key,
			"number": clues_given,
			"of": schedule.size(),
		})
		next_clue_at += _def.clue_interval_hours * SimClock.GAME_SECONDS_PER_HOUR
	if clues_given >= schedule.size():
		next_clue_at = INF
		phase = Phase.ACCUSING
		_try_accuse(now)


## Tells the introduction of everyone Jack has not met yet, one story at a time.
## True once nobody on the list is a stranger.
func _introduce(now: float) -> bool:
	for person: SuspectDef in _def.suspects:
		if is_introduced(person) or not _can_meet(person):
			continue
		if _stories.is_pending():
			return false
		_stories.start(person.intro_story, now, ACTOR)
	return true


func _try_accuse(now: float) -> void:
	if accuse_at > 0.0 or _stories.is_pending() or _stories.used.has(ACCUSE_STORY_ID):
		return
	if not _introduce(now) or _stories.is_pending():
		return
	_stories.register(accusation())
	_stories.start(_stories.find(ACCUSE_STORY_ID), now, ACTOR)


## Built from the saved state, so a load mid-accusation shows the same question.
func accusation() -> StoryDef:
	return IntrigueAccusation.build(self)


func _accused(choice: int, now: float) -> void:
	var names := accusable()
	if choice < 0 or choice >= names.size():
		_wait(now)
		return
	var accused := names[choice]
	if accused == rat_suspect():
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


## No name tonight. The rat is still out there talking, and Reggie will ask again.
func _wait(now: float) -> void:
	_raids.expect()
	_stories.forget(ACCUSE_STORY_ID)
	accuse_at = now + _def.wait_hours * SimClock.GAME_SECONDS_PER_HOUR
	_event_log.record(EventLog.INTRIGUE_STEP, now, PackedStringArray([ACTOR]), {"path": WAITED, "hours": _def.wait_hours})


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
		"accuse_at": ExactFloat.encode(accuse_at),
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
	accuse_at = ExactFloat.decode(data["accuse_at"]) if data.has("accuse_at") else 0.0
	seen_events = int(data["seen_events"])
	if phase == Phase.ACCUSING and _stories.used.has(ACCUSE_STORY_ID):
		_stories.register(accusation())
