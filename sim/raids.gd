class_name Raids
extends RefCounted

const RAIDER_ACTOR: String = "raiders"
const PAY: String = "pay"
const GIVE: String = "give"
const CHASE: String = "chase"

var pending: bool = false
var deadline: float = 0.0
var next_roll_at: float = 0.0

var _def: RaidsDef
var _rng: SimRng
var _inventory: Inventory
var _economy: Economy
var _orders: Orders
var _workers: Workers
var _suspicion: Suspicion
var _event_log: EventLog
var _empire_value: Callable


func _init(def: RaidsDef, rng: SimRng, inventory: Inventory, economy: Economy, orders: Orders, workers: Workers, suspicion: Suspicion, event_log: EventLog, empire_value: Callable) -> void:
	_def = def
	_rng = rng
	_inventory = inventory
	_economy = economy
	_orders = orders
	_workers = workers
	_suspicion = suspicion
	_event_log = event_log
	_empire_value = empire_value
	var first_night := floorf(def.start_hours / 24.0) * SimClock.GAME_SECONDS_PER_DAY + def.night_hour * SimClock.GAME_SECONDS_PER_HOUR
	if first_night < def.start_hours * SimClock.GAME_SECONDS_PER_HOUR:
		first_night += SimClock.GAME_SECONDS_PER_DAY
	next_roll_at = first_night


func bribe() -> int:
	return _def.bribe


func chase_chance() -> float:
	return clampf(_def.chase_chance + (_def.chase_bonus_with_worker if _workers.hired else 0.0), 0.0, 1.0)


func next_event_time() -> float:
	var next := next_roll_at if _def.chance_per_night > 0.0 else INF
	if pending:
		next = minf(next, deadline)
	return next


func process(now: float) -> void:
	if pending and now >= deadline:
		_rob(now, "ignored")
	while now >= next_roll_at:
		_roll(next_roll_at)
		next_roll_at += SimClock.GAME_SECONDS_PER_DAY


func _roll(at: float) -> void:
	if pending or not _has_loot():
		return
	if int(_empire_value.call()) >= _def.max_empire_value:
		return
	if _rng.randf() >= _def.chance_per_night:
		return
	pending = true
	deadline = at + _def.deadline_hours * SimClock.GAME_SECONDS_PER_HOUR
	_event_log.record(EventLog.RAID_STARTED, at, PackedStringArray([RAIDER_ACTOR]), {"bribe": _def.bribe})


func _has_loot() -> bool:
	if _inventory.count() > 0:
		return true
	for order: Order in _orders.all():
		if order.status == Order.Status.DROPPED:
			return true
	return false


func respond(choice: String, now: float, actor: String) -> CommandResult:
	if not pending:
		return CommandResult.failure(CommandResult.NO_RAID)
	match choice:
		PAY:
			if not _economy.spend(_def.bribe):
				return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
			_resolve(now, actor, "paid", {"paid": _def.bribe})
		GIVE:
			var products := _inventory.products()
			var taken := ceili(float(products.size()) / 2.0)
			for index: int in taken:
				_inventory.take(products[index].id)
			_resolve(now, actor, "gave", {"taken": taken})
		CHASE:
			_suspicion.add(_def.chase_noise)
			if _rng.randf() < chase_chance():
				_resolve(now, actor, "chased", {})
			else:
				_rob(now, "chase_failed")
		_:
			return CommandResult.failure(CommandResult.UNKNOWN_CHOICE)
	return CommandResult.success()


func _rob(now: float, outcome: String) -> void:
	var taken := _inventory.count()
	for product: Product in _inventory.products():
		_inventory.take(product.id)
	var lost_orders := _orders.steal_dropped()
	_resolve(now, RAIDER_ACTOR, outcome, {"taken": taken, "lost_orders": lost_orders})


func _resolve(now: float, actor: String, outcome: String, data: Dictionary) -> void:
	pending = false
	deadline = 0.0
	var record := data.duplicate()
	record["outcome"] = outcome
	_event_log.record(EventLog.RAID_RESOLVED, now, PackedStringArray([actor, RAIDER_ACTOR]), record)


func to_dict() -> Dictionary:
	return {
		"pending": pending,
		"deadline": ExactFloat.encode(deadline),
		"next_roll_at": ExactFloat.encode(next_roll_at),
	}


func load_dict(data: Dictionary) -> void:
	pending = data["pending"] == true
	deadline = ExactFloat.decode(data["deadline"])
	next_roll_at = ExactFloat.decode(data["next_roll_at"])
