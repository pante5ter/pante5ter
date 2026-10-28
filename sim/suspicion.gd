class_name Suspicion
extends RefCounted

const MAX_LEVEL: float = 100.0

var level: float = 0.0
var quiet: bool = false
var inspection_at: float = INF
var next_tick_at: float = 0.0

var _def: SuspicionDef
var _grow: Grow
var _economy: Economy
var _event_log: EventLog


func _init(def: SuspicionDef, grow: Grow, economy: Economy, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_economy = economy
	_event_log = event_log
	next_tick_at = SimClock.GAME_SECONDS_PER_HOUR


func inspection_pending() -> bool:
	return inspection_at != INF


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


## Pay to cancel a pending inspection (the tip never reaches the constable).
func bribe_off(now: float, actor: String) -> CommandResult:
	if not inspection_pending():
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	var cost := maxi(_def.bribe_cost, 0)
	if cost > 0 and not _economy.spend(cost):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	inspection_at = INF
	add(-maxf(_def.bribe_suspicion_relief, 0.0))
	_event_log.record(EventLog.INSPECTION_BRIBED, now, PackedStringArray([actor, "inspector"]), {
		"cost": cost,
		"money": _economy.money,
		"level": roundi(level),
	})
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
	if quiet:
		add(-_def.relief_when_hidden)
		_event_log.record(EventLog.INSPECTION_PASSED, now, PackedStringArray(["inspector"]), {"level": roundi(level)})
		return
	var fine := mini(_def.fine, _economy.money)
	_economy.spend(fine)
	add(-_def.relief_when_caught)
	_event_log.record(EventLog.INSPECTION_FAILED, now, PackedStringArray(["inspector"]), {
		"fine": fine,
		"money": _economy.money,
		"level": roundi(level),
	})


func to_dict() -> Dictionary:
	return {
		"level": ExactFloat.encode(level),
		"quiet": quiet,
		"inspection_at": ExactFloat.encode(inspection_at),
		"next_tick_at": ExactFloat.encode(next_tick_at),
	}


func load_dict(data: Dictionary) -> void:
	level = ExactFloat.decode(data["level"])
	quiet = data["quiet"] == true
	inspection_at = ExactFloat.decode(data["inspection_at"])
	next_tick_at = ExactFloat.decode(data["next_tick_at"])
