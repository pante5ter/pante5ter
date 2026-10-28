class_name Suspicion
extends RefCounted

const MAX_LEVEL: float = 100.0
## Jack's answer to the warning call.
const PREP_LIGHTS: String = "lights"
const PREP_HIDE: String = "hide"
const PREP_BRIBE: String = "bribe"
const PREP_NOTHING: String = "nothing"
const PREPS: Array[String] = [PREP_LIGHTS, PREP_HIDE, PREP_BRIBE, PREP_NOTHING]
const CREW_ACTOR: String = "crew"

var level: float = 0.0
var quiet: bool = false
var inspection_at: float = INF
var next_tick_at: float = 0.0
## How Jack got ready for the inspection on its way; empty until he answers.
var prep: String = ""

var _def: SuspicionDef
var _grow: Grow
var _economy: Economy
var _event_log: EventLog
var _rng: SimRng = null
var _inventory: Inventory = null


func _init(def: SuspicionDef, grow: Grow, economy: Economy, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_economy = economy
	_event_log = event_log
	next_tick_at = SimClock.GAME_SECONDS_PER_HOUR


## The preparation answers roll the dice and can cost crates.
func attach(rng: SimRng, inventory: Inventory) -> void:
	_rng = rng
	_inventory = inventory


func definition() -> SuspicionDef:
	return _def


func inspection_pending() -> bool:
	return inspection_at != INF


## The inspection is coming and Jack has not said how to meet it.
func awaiting_prep() -> bool:
	return inspection_pending() and prep.is_empty()


func add(amount: float) -> void:
	level = clampf(level + amount, 0.0, MAX_LEVEL)


## A tip-off: the inspector comes whatever the level says.
func schedule_inspection(at: float, hours: float) -> bool:
	if inspection_pending():
		return false
	inspection_at = at + hours * SimClock.GAME_SECONDS_PER_HOUR
	return true


func lie_low(on: bool, now: float, actor: String) -> CommandResult:
	if quiet == on:
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	quiet = on
	_event_log.record(EventLog.WENT_QUIET if on else EventLog.BACK_TO_WORK, now, PackedStringArray([actor]), {})
	return CommandResult.success()


## Chance the lamps-on answers get through the visit at the current level.
func pass_chance(choice: String) -> float:
	var base := _def.nothing_pass_chance
	match choice:
		PREP_HIDE:
			base = _def.hide_pass_chance
		PREP_BRIBE:
			base = _def.bribe_pass_chance
	return clampf(base - level * _def.pass_chance_per_suspicion, _def.min_pass_chance, 1.0)


func prepare(choice: String, now: float, actor: String) -> CommandResult:
	if not PREPS.has(choice):
		return CommandResult.failure(CommandResult.UNKNOWN_CHOICE)
	if not inspection_pending():
		return CommandResult.failure(CommandResult.NO_INSPECTION)
	if not prep.is_empty():
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	var cost := _def.bribe_price if choice == PREP_BRIBE else 0
	if cost > 0 and not _economy.spend(cost):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	prep = choice
	_event_log.record(EventLog.INSPECTION_PREPARED, now, PackedStringArray([actor, "inspector"]), {
		"choice": choice,
		"cost": cost,
		"money": _economy.money,
		"inspection_at": inspection_at,
	})
	if choice == PREP_LIGHTS and not quiet:
		lie_low(true, now, actor)
	return CommandResult.success(cost)


func next_event_time() -> float:
	return minf(next_tick_at, inspection_at)


func process(now: float) -> void:
	while now >= next_tick_at:
		_tick(next_tick_at)
		next_tick_at += SimClock.GAME_SECONDS_PER_HOUR
	if now >= inspection_at:
		_inspect(now)


func _tick(at: float) -> void:
	var extra_beds := maxi(_grow.plots().size() - _def.quiet_beds, 0)
	add(float(extra_beds) * _def.per_extra_bed_per_hour - _def.decay_per_hour)
	if level >= _def.inspection_threshold and not inspection_pending():
		inspection_at = at + _def.warning_hours * SimClock.GAME_SECONDS_PER_HOUR
		_event_log.record(EventLog.INSPECTION_WARNED, at, PackedStringArray(["inspector"]), {
			"level": roundi(level),
			"warning_hours": _def.warning_hours,
		})


func _inspect(now: float) -> void:
	inspection_at = INF
	var choice := prep
	prep = ""
	if quiet:
		_pass(now, choice, 0)
		if choice == PREP_LIGHTS:
			lie_low(false, now, CREW_ACTOR)
		return
	if choice.is_empty() or _rng == null:
		_fail(now, choice, 0)
		return
	var lost := _lose_hidden_crates() if choice == PREP_HIDE else 0
	if _rng.randf() < pass_chance(choice):
		_pass(now, choice, lost)
	else:
		_fail(now, choice, lost)


## The wheat is no warehouse: a share of the crates carried out may not come back.
func _lose_hidden_crates() -> int:
	if _inventory == null:
		return 0
	var crates := _inventory.farm_crates()
	if crates.is_empty() or _rng.randf() >= _def.hide_loss_chance:
		return 0
	var lost := mini(ceili(float(crates.size()) * _def.hide_loss_share), crates.size())
	for index: int in lost:
		_inventory.take(crates[index].id)
	return lost


func _pass(now: float, choice: String, lost: int) -> void:
	add(-_def.relief_when_hidden)
	var data := {"level": roundi(level)}
	if not choice.is_empty():
		data["prep"] = choice
		data["lost"] = lost
	_event_log.record(EventLog.INSPECTION_PASSED, now, PackedStringArray(["inspector"]), data)


func _fail(now: float, choice: String, lost: int) -> void:
	var fine := mini(_def.fine, _economy.money)
	_economy.spend(fine)
	add(-_def.relief_when_caught)
	var data := {
		"fine": fine,
		"money": _economy.money,
		"level": roundi(level),
	}
	if not choice.is_empty():
		data["prep"] = choice
		data["lost"] = lost
	_event_log.record(EventLog.INSPECTION_FAILED, now, PackedStringArray(["inspector"]), data)


func to_dict() -> Dictionary:
	return {
		"level": ExactFloat.encode(level),
		"quiet": quiet,
		"inspection_at": ExactFloat.encode(inspection_at),
		"next_tick_at": ExactFloat.encode(next_tick_at),
		"prep": prep,
	}


func load_dict(data: Dictionary) -> void:
	level = ExactFloat.decode(data["level"])
	quiet = data["quiet"] == true
	inspection_at = ExactFloat.decode(data["inspection_at"])
	next_tick_at = ExactFloat.decode(data["next_tick_at"])
	var saved_prep := String(data.get("prep", ""))
	prep = saved_prep if PREPS.has(saved_prep) and inspection_pending() else ""
