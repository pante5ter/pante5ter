class_name Helper
extends RefCounted

## Actor tag in the event log and his courier id for deliveries.
const ACTOR: String = "helper"
const AWAY_DELIVERY: String = "delivery"
const AWAY_TRAINING: String = "training"
const AWAY_HAUL: String = "haul"
const SAVED_LIGHTS: String = "lights"
const SAVED_RAID: String = "raid"

var skills: Array[String] = []
var task: Workers.Task = Workers.Task.NONE
var task_plot_id: int = -1
var task_ends_at: float = 0.0
var next_check_at: float = 0.0
var next_wage_at: float = SimClock.GAME_SECONDS_PER_DAY
var wage_debt: int = 0
var away_reason: String = ""
var away_until: float = 0.0
var training_skill_id: String = ""
## He dimmed the farm for an inspection and turns it back on afterwards.
var dimmed_lights: bool = false
## He told Jack a spare lamp is needed and there was no money to order one; said once per burned lamp.
var asked_for_lamp: bool = false
## Set by SimState: the gardeners' beds are left to them.
var farmhand: Workers = null

var _def: WorkerDef
var _config: BalanceConfig
var _grow: Grow
var _supplies: Supplies
var _packing: Packing
var _economy: Economy
var _suspicion: Suspicion
var _event_log: EventLog


func _init(config: BalanceConfig, grow: Grow, supplies: Supplies, packing: Packing, economy: Economy, suspicion: Suspicion, event_log: EventLog) -> void:
	_config = config
	_def = config.helper
	_grow = grow
	_supplies = supplies
	_packing = packing
	_economy = economy
	_suspicion = suspicion
	_event_log = event_log
	if _def != null:
		for skill_id: String in _def.starting_skills:
			if config.find_skill(skill_id) != null and not skills.has(skill_id):
				skills.append(skill_id)


func definition() -> WorkerDef:
	return _def


func exists() -> bool:
	return _def != null


## On the farm and able to work, drive or save the day.
func present() -> bool:
	return exists() and away_reason.is_empty()


func knows(kind: String) -> bool:
	for skill_id: String in skills:
		var skill := _config.find_skill(skill_id)
		if skill != null and skill.kind == kind:
			return true
	return false


func trip_risk_factor() -> float:
	var factor := 1.0
	for skill_id: String in skills:
		var skill := _config.find_skill(skill_id)
		if skill != null and skill.kind == SkillDef.DRIVING:
			factor = minf(factor, skill.trip_risk_factor)
	return factor


## Arrival of a migrated save: he starts his first day now.
func start_at(now: float) -> void:
	next_check_at = now
	next_wage_at = now + SimClock.GAME_SECONDS_PER_DAY


func leave_for_delivery(now: float, back_at: float) -> void:
	_leave(AWAY_DELIVERY, now, back_at)


func leave_for_haul(now: float, back_at: float) -> void:
	_leave(AWAY_HAUL, now, back_at)


func extend_away(back_at: float) -> void:
	if away_reason.is_empty():
		return
	away_until = maxf(away_until, back_at)
	next_check_at = away_until


func learn(skill_id: String, now: float, actor: String) -> CommandResult:
	if not exists():
		return CommandResult.failure(CommandResult.WORKER_NOT_HIRED)
	var skill := _config.find_skill(skill_id)
	if skill == null:
		return CommandResult.failure(CommandResult.UNKNOWN_SKILL)
	if skills.has(skill_id) or training_skill_id == skill_id:
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	if not present():
		return CommandResult.failure(CommandResult.HELPER_AWAY)
	if not _economy.spend(skill.price):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	training_skill_id = skill_id
	_leave(AWAY_TRAINING, now, now + skill.train_hours * SimClock.GAME_SECONDS_PER_HOUR)
	_event_log.record(EventLog.HELPER_TRAINING_STARTED, now, PackedStringArray([actor, ACTOR]), {
		"skill_id": skill_id,
		"cost": skill.price,
		"money": _economy.money,
		"back_at": away_until,
	})
	return CommandResult.success(skill.price)


## Old saves: the courses for bed work are gone, and what was paid for them comes back.
func retire_skills(now: float) -> void:
	var refunded: Array[String] = []
	var refund := 0
	for skill_id: String in _config.retired_skills:
		if not skills.has(skill_id) and training_skill_id != skill_id:
			continue
		skills.erase(skill_id)
		if training_skill_id == skill_id:
			training_skill_id = ""
		refunded.append(skill_id)
		refund += _config.retired_skills[skill_id]
	if refund == 0:
		return
	_economy.earn(refund)
	_event_log.record(EventLog.HELPER_SKILLS_REFUNDED, now, PackedStringArray([ACTOR]), {
		"skill_ids": refunded,
		"refund": refund,
		"money": _economy.money,
	})


func _leave(reason: String, now: float, back_at: float) -> void:
	away_reason = reason
	away_until = back_at
	_clear_task()
	next_check_at = back_at
	if now < back_at:
		return
	_come_back(now)


func next_event_time() -> float:
	if not exists():
		return INF
	var next := next_wage_at
	if not away_reason.is_empty():
		return minf(next, away_until)
	next = minf(next, task_ends_at if task != Workers.Task.NONE else next_check_at)
	if _lights_due():
		next = minf(next, _lights_out_at())
	return next


func process(now: float) -> void:
	if not exists():
		return
	if now >= next_wage_at:
		_pay_wage(now)
	if not away_reason.is_empty():
		if now < away_until:
			return
		_come_back(now)
	if _lights_due() and now >= _lights_out_at():
		_dim_lights(now)
	elif dimmed_lights and not _suspicion.inspection_pending():
		_lights_back_on(now)
	if task != Workers.Task.NONE and now >= task_ends_at:
		_finish_task(now)
	if task == Workers.Task.NONE and now >= next_check_at:
		if _suspicion.quiet:
			next_check_at = now + _def.idle_check_minutes * 60.0
		else:
			_start_next_task(now)


## Raiders nobody answered: he sees them off himself.
func chases_raiders() -> bool:
	return present()


func _pay_wage(now: float) -> void:
	next_wage_at += SimClock.GAME_SECONDS_PER_DAY
	var owed := _def.daily_wage + wage_debt
	if _economy.spend(owed):
		wage_debt = 0
		_event_log.record(EventLog.WORKER_PAID, now, PackedStringArray([ACTOR]), {
			"worker_id": _def.id,
			"wage": owed,
			"money": _economy.money,
		})
		return
	wage_debt = owed
	_event_log.record(EventLog.HELPER_UNPAID, now, PackedStringArray([ACTOR]), {
		"worker_id": _def.id,
		"debt": wage_debt,
		"money": _economy.money,
	})


func _come_back(now: float) -> void:
	var reason := away_reason
	away_reason = ""
	away_until = 0.0
	next_check_at = now
	if reason == AWAY_TRAINING and not training_skill_id.is_empty():
		skills.append(training_skill_id)
		_event_log.record(EventLog.HELPER_SKILL_LEARNED, now, PackedStringArray([ACTOR]), {"skill_id": training_skill_id})
		training_skill_id = ""


func _lights_due() -> bool:
	return present() and _suspicion.awaiting_prep() and not _suspicion.quiet and not dimmed_lights


func _lights_out_at() -> float:
	return _suspicion.inspection_at - _config.helper_lights_out_hours * SimClock.GAME_SECONDS_PER_HOUR


func _dim_lights(now: float) -> void:
	if not _suspicion.lie_low(true, now, ACTOR).ok:
		return
	dimmed_lights = true
	_clear_task()
	_event_log.record(EventLog.HELPER_SAVED, now, PackedStringArray([ACTOR]), {"kind": SAVED_LIGHTS})


func _lights_back_on(now: float) -> void:
	dimmed_lights = false
	if _suspicion.quiet:
		_suspicion.lie_low(false, now, ACTOR)


## He is Jack's right hand, not a gardener: on the farm he only deals with trouble on a bed.
func _start_next_task(now: float) -> void:
	_fetch_spare_lamp(now)
	var taken: Array[int] = farmhand.busy_plot_ids() if farmhand != null else []
	var target := Workers.pick_plot(_grow, Workers.Task.TREAT, _def.water_below_hours, taken, _can_do)
	if target != null:
		_start(Workers.Task.TREAT, target.id, now)
		return
	_order_spare_lamp(now)
	next_check_at = now + _def.idle_check_minutes * 60.0


func _lamp_burned() -> bool:
	if not knows(SkillDef.ELECTRICS):
		return false
	for target: Plot in _grow.plots():
		if target.problem == Problems.LAMP:
			return true
	return false


## A spare lamp waiting in the parcel at the door: he carries the parcel in himself.
func _fetch_spare_lamp(now: float) -> void:
	if not _lamp_burned() or _supplies.count(Supplies.LAMP) > 0:
		return
	for entry: Dictionary in _supplies.parcel():
		if String(entry["item"]) == Supplies.LAMP:
			_supplies.pick_up(now, ACTOR)
			return


## No spare anywhere: he orders one if the till allows, otherwise he tells Jack once.
func _order_spare_lamp(now: float) -> void:
	if not _lamp_burned() or _supplies.stock_and_coming(Supplies.LAMP) > 0:
		asked_for_lamp = false
		return
	var price := _supplies.unit_price(Supplies.LAMP)
	if price > 0 and _economy.money >= price and _supplies.buy(Supplies.LAMP, 1, now, ACTOR).ok:
		asked_for_lamp = false
		return
	if asked_for_lamp:
		return
	asked_for_lamp = true
	_event_log.record(EventLog.HELPER_NEEDS_LAMP, now, PackedStringArray([ACTOR]), {"price": price, "money": _economy.money})


func _can_do(_kind: Workers.Task, target: Plot) -> bool:
	return _can_treat(target)


## A burned lamp needs the electrics course and a spare lamp on the shelf.
func _can_treat(target: Plot) -> bool:
	if target.problem == Problems.LAMP and not knows(SkillDef.ELECTRICS):
		return false
	var cure := Problems.cure_item(target.problem)
	return cure.is_empty() or _supplies.count(cure) > 0


func _start(kind: Workers.Task, plot_id: int, now: float) -> void:
	task = kind
	task_plot_id = plot_id
	task_ends_at = now + _def.task_seconds()
	var actors := PackedStringArray([ACTOR])
	if plot_id >= 0:
		actors.append("plot:%d" % plot_id)
	_event_log.record(EventLog.WORKER_TASK_STARTED, now, actors, {"plot_id": plot_id, "task": Workers.task_name(task)})


func _finish_task(now: float) -> void:
	if task == Workers.Task.TREAT:
		_treat(now)
	_clear_task()
	next_check_at = now


func _treat(now: float) -> void:
	var target := _grow.plot(task_plot_id)
	if target == null or target.problem.is_empty() or not _can_treat(target):
		return
	var cure := Problems.cure_item(target.problem)
	if not cure.is_empty() and not _supplies.take_item(cure):
		return
	var cured := target.problem
	target.problem = ""
	_event_log.record(EventLog.PLOT_TREATED, now, PackedStringArray([ACTOR, "plot:%d" % task_plot_id]), {
		"plot_id": task_plot_id,
		"problem": cured,
	})


func _clear_task() -> void:
	task = Workers.Task.NONE
	task_plot_id = -1
	task_ends_at = 0.0


func to_dict() -> Dictionary:
	return {
		"skills": skills.duplicate(),
		"task": Workers.task_name(task),
		"task_plot_id": task_plot_id,
		"task_ends_at": ExactFloat.encode(task_ends_at),
		"next_check_at": ExactFloat.encode(next_check_at),
		"next_wage_at": ExactFloat.encode(next_wage_at),
		"wage_debt": wage_debt,
		"away_reason": away_reason,
		"away_until": ExactFloat.encode(away_until),
		"training_skill_id": training_skill_id,
		"dimmed_lights": dimmed_lights,
		"asked_for_lamp": asked_for_lamp,
	}


func load_dict(data: Dictionary) -> void:
	skills.clear()
	for skill_id: Variant in data["skills"] as Array:
		skills.append(String(skill_id))
	task = Workers.Task.get(String(data["task"]).to_upper(), Workers.Task.NONE) as Workers.Task
	task_plot_id = int(data["task_plot_id"])
	task_ends_at = ExactFloat.decode(data["task_ends_at"])
	next_check_at = ExactFloat.decode(data["next_check_at"])
	next_wage_at = ExactFloat.decode(data["next_wage_at"])
	wage_debt = int(data["wage_debt"])
	away_reason = String(data["away_reason"])
	away_until = ExactFloat.decode(data["away_until"])
	training_skill_id = String(data["training_skill_id"])
	dimmed_lights = data["dimmed_lights"] == true
	asked_for_lamp = data.get("asked_for_lamp", false) == true
