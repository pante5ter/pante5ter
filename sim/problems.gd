class_name Problems
extends RefCounted

const PESTS: String = "pests"
const MOLD: String = "mold"
const LAMP: String = "lamp"
const KINDS: Array[String] = [PESTS, MOLD, LAMP]

var next_roll_at: float = 0.0

var _def: ProblemsDef
var _grow: Grow
var _supplies: Supplies
var _rng: SimRng
var _event_log: EventLog


func _init(def: ProblemsDef, grow: Grow, supplies: Supplies, rng: SimRng, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_supplies = supplies
	_rng = rng
	_event_log = event_log
	next_roll_at = def.start_hours * SimClock.GAME_SECONDS_PER_HOUR


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
		if _rng.randf() >= _def.chance_per_hour:
			continue
		target.problem = KINDS[_rng.randi_range(0, KINDS.size() - 1)]
		_event_log.record(EventLog.PLOT_PROBLEM, at, PackedStringArray(["plot:%d" % target.id]), {
			"plot_id": target.id,
			"problem": target.problem,
		})


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
