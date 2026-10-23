class_name Workers
extends RefCounted

const ACTOR: String = "worker"

enum Task { NONE, PLANT, WATER, HARVEST }

var hired: bool = false
var task: Task = Task.NONE
var task_plot_id: int = -1
var task_ends_at: float = 0.0
var next_check_at: float = 0.0
var next_wage_at: float = 0.0

var _def: WorkerDef
var _grow: Grow
var _economy: Economy
var _event_log: EventLog


func _init(def: WorkerDef, grow: Grow, economy: Economy, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_economy = economy
	_event_log = event_log


func definition() -> WorkerDef:
	return _def


func hire(now: float, actor: String) -> CommandResult:
	if hired:
		return CommandResult.failure(CommandResult.WORKER_ALREADY_HIRED)
	if not _economy.spend(_def.daily_wage):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	hired = true
	_clear_task()
	next_check_at = now
	next_wage_at = now + SimClock.GAME_SECONDS_PER_DAY
	_event_log.record(EventLog.WORKER_HIRED, now, PackedStringArray([actor, ACTOR]), {
		"worker_id": _def.id,
		"wage": _def.daily_wage,
		"money": _economy.money,
	})
	return CommandResult.success()


func next_event_time() -> float:
	if not hired:
		return INF
	var pending := task_ends_at if task != Task.NONE else next_check_at
	return minf(next_wage_at, pending)


func process(now: float) -> void:
	if not hired:
		return
	if now >= next_wage_at:
		_pay_wage(now)
		if not hired:
			return
	if task != Task.NONE and now >= task_ends_at:
		_finish_task(now)
	if task == Task.NONE and now >= next_check_at:
		_start_next_task(now)


func _pay_wage(now: float) -> void:
	if _economy.spend(_def.daily_wage):
		next_wage_at += SimClock.GAME_SECONDS_PER_DAY
		_event_log.record(EventLog.WORKER_PAID, now, PackedStringArray([ACTOR]), {
			"wage": _def.daily_wage,
			"money": _economy.money,
		})
		return
	hired = false
	_clear_task()
	_event_log.record(EventLog.WORKER_QUIT, now, PackedStringArray([ACTOR]), {
		"reason": "unpaid",
		"money": _economy.money,
	})


func _finish_task(now: float) -> void:
	match task:
		Task.PLANT:
			_grow.plant(task_plot_id, now, ACTOR)
		Task.WATER:
			_grow.water(task_plot_id, now, ACTOR)
		Task.HARVEST:
			_grow.harvest(task_plot_id, now, ACTOR)
	_clear_task()
	next_check_at = now


func _start_next_task(now: float) -> void:
	var target := _pick_plot_for(Task.HARVEST)
	var chosen := Task.HARVEST
	if target == null:
		target = _pick_plot_for(Task.WATER)
		chosen = Task.WATER
	if target == null:
		target = _pick_plot_for(Task.PLANT)
		chosen = Task.PLANT
	if target == null:
		next_check_at = now + _def.idle_check_minutes * 60.0
		return
	task = chosen
	task_plot_id = target.id
	task_ends_at = now + _def.task_minutes * 60.0
	_event_log.record(EventLog.WORKER_TASK_STARTED, now, PackedStringArray([ACTOR, "plot:%d" % target.id]), {
		"plot_id": target.id,
		"task": task_name(task),
	})


func _pick_plot_for(kind: Task) -> Plot:
	var best: Plot = null
	for candidate: Plot in _grow.plots():
		if not _needs(candidate, kind):
			continue
		if best == null or (kind == Task.WATER and candidate.water_seconds < best.water_seconds):
			best = candidate
	return best


func _needs(target: Plot, kind: Task) -> bool:
	match kind:
		Task.HARVEST:
			return target.stage == Plot.Stage.READY
		Task.WATER:
			return target.is_growing() and target.water_seconds < _def.water_below_hours * SimClock.GAME_SECONDS_PER_HOUR
		Task.PLANT:
			return target.stage == Plot.Stage.EMPTY
	return false


func _clear_task() -> void:
	task = Task.NONE
	task_plot_id = -1
	task_ends_at = 0.0


static func task_name(value: Task) -> String:
	return String(Task.keys()[value]).to_lower()


func to_dict() -> Dictionary:
	return {
		"hired": hired,
		"task": task_name(task),
		"task_plot_id": task_plot_id,
		"task_ends_at": ExactFloat.encode(task_ends_at),
		"next_check_at": ExactFloat.encode(next_check_at),
		"next_wage_at": ExactFloat.encode(next_wage_at),
	}


func load_dict(data: Dictionary) -> void:
	hired = data["hired"] == true
	task = Task.get(String(data["task"]).to_upper(), Task.NONE) as Task
	task_plot_id = int(data["task_plot_id"])
	task_ends_at = ExactFloat.decode(data["task_ends_at"])
	next_check_at = ExactFloat.decode(data["next_check_at"])
	next_wage_at = ExactFloat.decode(data["next_wage_at"])
