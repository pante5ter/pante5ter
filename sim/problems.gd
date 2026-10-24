class_name Problems
extends RefCounted

const PESTS: String = "pests"
const MOLD: String = "mold"
const LAMP: String = "lamp"
const KINDS: Array[String] = [PESTS, MOLD, LAMP]
## Trouble that does not care about the air.
const DRY_KINDS: Array[String] = [PESTS, LAMP]

var next_roll_at: float = 0.0

var _def: ProblemsDef
var _grow: Grow
var _supplies: Supplies
var _rng: SimRng
var _event_log: EventLog
var _climate: Climate = null


func _init(def: ProblemsDef, grow: Grow, supplies: Supplies, rng: SimRng, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_supplies = supplies
	_rng = rng
	_event_log = event_log
	next_roll_at = def.start_hours * SimClock.GAME_SECONDS_PER_HOUR


func attach_climate(climate: Climate) -> void:
	_climate = climate if climate != null and climate.exists() else null


static func cure_item(problem: String) -> String:
	match problem:
		PESTS:
			return Supplies.PESTICIDE
		LAMP:
			return Supplies.LAMP
	return ""


func next_event_time() -> float:
	return next_roll_at if _def.chance_per_hour > 0.0 else INF


func process(now: float) -> void:
	while now >= next_roll_at:
		_roll(next_roll_at)
		next_roll_at += SimClock.GAME_SECONDS_PER_HOUR


func _roll(at: float) -> void:
	for target: Plot in _grow.plots():
		if not target.is_growing() or not target.problem.is_empty():
			continue
		var kind := _roll_kind()
		if kind.is_empty():
			continue
		target.problem = kind
		_event_log.record(EventLog.PLOT_PROBLEM, at, PackedStringArray(["plot:%d" % target.id]), {
			"plot_id": target.id,
			"problem": target.problem,
		})


## One draw per bed, as before the climate: with it, mold comes from damp air instead of the plain roll.
func _roll_kind() -> String:
	var roll := _rng.randf()
	if _climate == null:
		return KINDS[_rng.randi_range(0, KINDS.size() - 1)] if roll < _def.chance_per_hour else ""
	if roll < _def.chance_per_hour:
		return DRY_KINDS[_rng.randi_range(0, DRY_KINDS.size() - 1)]
	if roll < _def.chance_per_hour + mold_chance():
		return MOLD
	return ""


## Hourly chance a healthy growing bed catches mold from damp air.
func mold_chance() -> float:
	return _def.chance_per_hour * _climate.mold_factor() if _climate != null else 0.0


func healthy_growing() -> Array[Plot]:
	var found: Array[Plot] = []
	for target: Plot in _grow.plots():
		if target.is_growing() and target.problem.is_empty():
			found.append(target)
	return found


## Trouble by script or director rather than by the hourly roll.
func force(plot_id: int, kind: String, at: float) -> bool:
	var target := _grow.plot(plot_id)
	if target == null or not target.is_growing() or not target.problem.is_empty():
		return false
	target.problem = kind
	_event_log.record(EventLog.PLOT_PROBLEM, at, PackedStringArray(["plot:%d" % target.id]), {
		"plot_id": target.id,
		"problem": target.problem,
	})
	return true


func treat(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := _grow.plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if target.problem.is_empty():
		return CommandResult.failure(CommandResult.NO_PROBLEM)
	var item := cure_item(target.problem)
	if not item.is_empty() and not _supplies.take_item(item):
		return CommandResult.failure(CommandResult.NO_SUPPLY)
	var cured := target.problem
	target.problem = ""
	_event_log.record(EventLog.PLOT_TREATED, now, PackedStringArray([actor, "plot:%d" % plot_id]), {
		"plot_id": plot_id,
		"problem": cured,
	})
	return CommandResult.success()


func to_dict() -> Dictionary:
	return {"next_roll_at": ExactFloat.encode(next_roll_at)}


func load_dict(data: Dictionary) -> void:
	next_roll_at = ExactFloat.decode(data["next_roll_at"])
