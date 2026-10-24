class_name Gardener
extends RefCounted

## One hired gardener: waters, harvests and replants the beds nobody else is on.

var task: Workers.Task = Workers.Task.NONE
var task_plot_id: int = -1
var task_ends_at: float = 0.0
var next_check_at: float = 0.0
var next_wage_at: float = 0.0

var _def: WorkerDef
var _crew: Workers


func _init(def: WorkerDef, crew: Workers) -> void:
	_def = def
	_crew = crew


func definition() -> WorkerDef:
	return _def


## The whole crew shares one actor tag; events that need the person carry worker_id.
func actor() -> String:
	return Workers.ACTOR


func start_at(now: float) -> void:
	_clear_task()
	next_check_at = now
	next_wage_at = now + SimClock.GAME_SECONDS_PER_DAY


func next_event_time() -> float:
	var pending := task_ends_at if task != Workers.Task.NONE else next_check_at
	return minf(next_wage_at, pending)


## False when he walked off unpaid.
func process(now: float) -> bool:
	if now >= next_wage_at and not _pay_wage(now):
		return false
	if task != Workers.Task.NONE and now >= task_ends_at:
		_finish_task(now)
	if task == Workers.Task.NONE and now >= next_check_at:
		if _crew.farm_is_quiet():
			next_check_at = now + _def.idle_check_minutes * 60.0
		else:
			_start_next_task(now)
	return true


func _pay_wage(now: float) -> bool:
	if _crew.economy().spend(_def.daily_wage):
		next_wage_at += SimClock.GAME_SECONDS_PER_DAY
		_crew.talk(_def.talkativeness)
		_crew.event_log().record(EventLog.WORKER_PAID, now, PackedStringArray([actor()]), {
			"worker_id": _def.id,
			"wage": _def.daily_wage,
			"money": _crew.economy().money,
		})
		return true
	_clear_task()
	_crew.event_log().record(EventLog.WORKER_QUIT, now, PackedStringArray([actor()]), {
		"worker_id": _def.id,
		"reason": "unpaid",
		"money": _crew.economy().money,
	})
	return false


func _finish_task(now: float) -> void:
	var grow := _crew.grow()
	match task:
		Workers.Task.PLANT:
			grow.plant(task_plot_id, now, actor(), grow.replant_strain(grow.plot(task_plot_id)))
		Workers.Task.WATER:
			grow.water(task_plot_id, now, actor())
		Workers.Task.HARVEST:
			_harvest(now)
	_clear_task()
	next_check_at = now


func _harvest(now: float) -> void:
	var result := _crew.grow().harvest(task_plot_id, now, actor())
	var rng := _crew.rng()
	if not result.ok or rng == null or rng.randf() >= _def.steal_chance():
		return
	var stolen := _crew.inventory().take(result.value)
	_crew.event_log().record(EventLog.WORKER_STOLE, now, PackedStringArray([actor(), "plot:%d" % task_plot_id]), {
		"worker_id": _def.id,
		"plot_id": task_plot_id,
		"product_id": stolen.id,
		"quality": stolen.quality,
	})


func _start_next_task(now: float) -> void:
	var taken := _crew.busy_plot_ids(self)
	var chosen := Workers.Task.NONE
	var target: Plot = null
	for kind: Workers.Task in Workers.CARE_ORDER:
		target = Workers.pick_plot(_crew.grow(), kind, _def.water_below_hours, taken)
		if target != null:
			chosen = kind
			break
	if target == null:
		next_check_at = now + _def.idle_check_minutes * 60.0
		return
	task = chosen
	task_plot_id = target.id
	task_ends_at = now + _def.task_seconds()
	_crew.event_log().record(EventLog.WORKER_TASK_STARTED, now, PackedStringArray([actor(), "plot:%d" % target.id]), {
		"plot_id": target.id,
		"task": Workers.task_name(task),
	})


func _clear_task() -> void:
	task = Workers.Task.NONE
	task_plot_id = -1
	task_ends_at = 0.0


func to_dict() -> Dictionary:
	return {
		"worker_id": _def.id,
		"task": Workers.task_name(task),
		"task_plot_id": task_plot_id,
		"task_ends_at": ExactFloat.encode(task_ends_at),
		"next_check_at": ExactFloat.encode(next_check_at),
		"next_wage_at": ExactFloat.encode(next_wage_at),
	}


func load_dict(data: Dictionary) -> void:
	task = Workers.Task.get(String(data["task"]).to_upper(), Workers.Task.NONE) as Workers.Task
	task_plot_id = int(data["task_plot_id"])
	task_ends_at = ExactFloat.decode(data["task_ends_at"])
	next_check_at = ExactFloat.decode(data["next_check_at"])
	next_wage_at = ExactFloat.decode(data["next_wage_at"])
