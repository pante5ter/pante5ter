class_name FirstDay
extends RefCounted

## Reggie walks a new player through one full loop. Every step also completes when the player
## already did the thing, so playing ahead simply skips the lesson.
enum Step { PLANT, CALL, ANSWER, HARVEST, HAUL, PACK, SEND, PAID, EVENING, LORD, MORNING, TROUBLE, DONE }

const ACTOR: String = "reggie"

var step: Step = Step.DONE
var call_at: float = INF
var order_id: int = -1
var trouble_plot_id: int = -1

var _def: FirstDayDef
var _config: BalanceConfig
var _grow: Grow
var _inventory: Inventory
var _orders: Orders
var _problems: Problems
var _stories: Stories
var _event_log: EventLog


func _init(config: BalanceConfig, grow: Grow, inventory: Inventory, orders: Orders, problems: Problems, stories: Stories, event_log: EventLog) -> void:
	_config = config
	_def = config.first_day
	_grow = grow
	_inventory = inventory
	_orders = orders
	_problems = problems
	_stories = stories
	_event_log = event_log
	if _def != null:
		step = Step.PLANT
	_sync_calls()


static func step_name(value: Step) -> String:
	return String(Step.keys()[value]).to_lower()


func definition() -> FirstDayDef:
	return _def


func active() -> bool:
	return step != Step.DONE


## Until the first delivery is on its way the script itself is the excitement.
func blocks_director() -> bool:
	return step <= Step.PAID


## Regular callers wait until the lesson's order is on the road, so the first call is the scripted one.
func holds_calls() -> bool:
	return step <= Step.SEND


## Nobody steals on Jack's first day or while Reggie is still showing him round: a loss there reads as a bug.
func spares_thieves(now: float) -> bool:
	return _def != null and (active() or now < SimClock.GAME_SECONDS_PER_DAY)


func lord_at() -> float:
	return _def.lord_hour * SimClock.GAME_SECONDS_PER_HOUR if _def != null else INF


func trouble_at() -> float:
	return _def.trouble_hour * SimClock.GAME_SECONDS_PER_HOUR if _def != null else INF


func script_order() -> Order:
	return _orders.find(order_id) if order_id >= 0 else null


## An old save arrives mid-game: no lesson for it.
func skip() -> void:
	step = Step.DONE
	_sync_calls()


func next_event_time() -> float:
	match step:
		Step.CALL:
			return call_at
		Step.EVENING, Step.MORNING:
			# Another conversation holds the scene; only Jack's answer (a command) frees it.
			if _stories.is_pending():
				return INF
			return lord_at() if step == Step.EVENING else trouble_at()
	return INF


func update(now: float) -> void:
	while active() and _advance(now):
		pass
	_sync_calls()


func _advance(now: float) -> bool:
	match step:
		Step.PLANT:
			if not _anything_planted():
				return false
			call_at = now + _def.call_after_real_seconds * SimClock.GAME_SECONDS_PER_DAY / _config.real_seconds_per_game_day
			return _go(Step.CALL, now)
		Step.CALL:
			if now < call_at:
				return false
			order_id = _orders.inject(_def.call_quantity, _def.call_min_quality, _def.call_reward, _def.call_answer_hours, 0.0, false, now).id
			return _go(Step.ANSWER, now)
		Step.ANSWER:
			var offered := script_order()
			if offered == null:
				return _go(Step.EVENING, now)
			return offered.status != Order.Status.OFFERED and _go(Step.HARVEST, now)
		Step.HARVEST, Step.HAUL, Step.PACK, Step.SEND:
			return _selling(now)
		Step.PAID:
			return script_order() == null and _go(Step.EVENING, now)
		Step.EVENING:
			if now < lord_at() or _stories.is_pending():
				return false
			if not _stories.start(_def.lord_story, now, ACTOR):
				return _go(Step.MORNING, now)
			return _go(Step.LORD, now)
		Step.LORD:
			return not _stories.is_pending() and _go(Step.MORNING, now)
		Step.MORNING:
			if now < trouble_at() or _stories.is_pending():
				return false
			return _start_trouble(now)
		Step.TROUBLE:
			if trouble_plot_id >= 0:
				var target := _grow.plot(trouble_plot_id)
				return (target == null or target.problem.is_empty()) and _go(Step.DONE, now)
			return not _stories.is_pending() and _go(Step.DONE, now)
	return false


func _selling(now: float) -> bool:
	var order := script_order()
	if order == null:
		return _go(Step.EVENING, now)
	if order.status == Order.Status.IN_TRANSIT:
		return _go(Step.PAID, now)
	if step == Step.HARVEST and _inventory.count() > 0:
		return _go(Step.HAUL, now)
	if step == Step.HAUL and not _inventory.at_stash().is_empty():
		return _go(Step.PACK, now)
	if step == Step.PACK and _orders.can_fill(order):
		return _go(Step.SEND, now)
	return false


func _start_trouble(now: float) -> bool:
	var targets := _problems.healthy_growing()
	if not targets.is_empty():
		trouble_plot_id = targets[0].id
		_problems.force(trouble_plot_id, Problems.PESTS, now)
		return _go(Step.TROUBLE, now)
	trouble_plot_id = -1
	if _stories.start(_def.trouble_story, now, ACTOR):
		return _go(Step.TROUBLE, now)
	return _go(Step.DONE, now)


func _anything_planted() -> bool:
	if _inventory.count() > 0:
		return true
	for target: Plot in _grow.plots():
		if target.stage != Plot.Stage.EMPTY:
			return true
	return false


func _go(next: Step, now: float) -> bool:
	step = next
	_event_log.record(EventLog.FIRST_DAY_STEP, now, PackedStringArray([ACTOR]), {"step": step_name(step)})
	return true


func _sync_calls() -> void:
	_orders.hold_calls = holds_calls()


func to_dict() -> Dictionary:
	return {
		"step": step_name(step),
		"call_at": ExactFloat.encode(call_at),
		"order_id": order_id,
		"trouble_plot_id": trouble_plot_id,
	}


func load_dict(data: Dictionary) -> void:
	step = Step.get(String(data["step"]).to_upper(), Step.DONE) as Step
	call_at = ExactFloat.decode(data["call_at"])
	order_id = int(data["order_id"])
	trouble_plot_id = int(data["trouble_plot_id"])
	_sync_calls()
