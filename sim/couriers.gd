class_name Couriers
extends RefCounted

## Jack no longer drives; the id stays for saves with him on the road.
const JACK: String = "jack"

var hired: Array[String] = []
## courier id -> game time when he is back and free.
var busy_until: Dictionary[String, float] = {}

var _config: BalanceConfig
var _orders: Orders
var _economy: Economy
var _suspicion: Suspicion
var _rng: SimRng
var _event_log: EventLog
var _helper: Helper = null


func _init(config: BalanceConfig, orders: Orders, economy: Economy, suspicion: Suspicion, rng: SimRng, event_log: EventLog) -> void:
	_config = config
	_orders = orders
	_economy = economy
	_suspicion = suspicion
	_rng = rng
	_event_log = event_log


func attach_helper(helper: Helper) -> void:
	_helper = helper


func is_helper(courier_id: String) -> bool:
	return courier_id == Helper.ACTOR and _helper != null and _helper.exists()


func is_free(courier_id: String, now: float) -> bool:
	if is_helper(courier_id):
		return _helper.present()
	return busy_until.get(courier_id, -INF) <= now


## Who can take this order right now: the helper first, then hired couriers.
func available_for(order: Order, now: float) -> Array[String]:
	var free: Array[String] = []
	if _suspicion.quiet or not _orders.can_fill(order):
		return free
	for courier_id: String in drivers():
		if is_free(courier_id, now):
			free.append(courier_id)
	return free


func drivers() -> Array[String]:
	var all: Array[String] = []
	if _helper != null and _helper.exists():
		all.append(Helper.ACTOR)
	all.append_array(hired)
	return all


func hire(courier_id: String, now: float, actor: String) -> CommandResult:
	var def := _config.find_courier(courier_id)
	if def == null:
		return CommandResult.failure(CommandResult.UNKNOWN_WORKER)
	if hired.has(courier_id):
		return CommandResult.failure(CommandResult.WORKER_ALREADY_HIRED)
	if hired.size() >= _config.max_couriers:
		return CommandResult.failure(CommandResult.TOO_MANY_COURIERS)
	if not _economy.spend(def.hire_fee):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	hired.append(courier_id)
	_event_log.record(EventLog.COURIER_HIRED, now, PackedStringArray([actor, courier_id]), {"courier_id": courier_id, "fee": def.hire_fee})
	return CommandResult.success()


func fire(courier_id: String, now: float, actor: String) -> CommandResult:
	if not hired.has(courier_id):
		return CommandResult.failure(CommandResult.WORKER_NOT_HIRED)
	if not is_free(courier_id, now):
		return CommandResult.failure(CommandResult.COURIER_BUSY)
	hired.erase(courier_id)
	busy_until.erase(courier_id)
	_event_log.record(EventLog.COURIER_FIRED, now, PackedStringArray([actor, courier_id]), {"courier_id": courier_id})
	return CommandResult.success()


func trip_seconds(courier_id: String) -> float:
	var speed := 1.0
	var def := _config.find_courier(courier_id)
	if def != null:
		speed = maxf(def.speed, 0.1)
	return _config.orders.trip_hours * SimClock.GAME_SECONDS_PER_HOUR / speed


func trip_risk(courier_id: String) -> float:
	var reliability := _config.orders.jack_reliability
	var def := _config.find_courier(courier_id)
	if def != null:
		reliability = def.reliability
	var factor := 1.0
	if is_helper(courier_id):
		reliability = _helper.definition().reliability
		factor = _helper.trip_risk_factor()
	var heat := 1.0 + _suspicion.level * _config.orders.suspicion_risk_factor
	return clampf(_config.orders.base_trip_risk * heat * (1.0 - reliability) * factor, 0.0, 1.0)


func dispatch(order_id: int, courier_id: String, now: float, actor: String) -> CommandResult:
	var order := _orders.find(order_id)
	if order == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ORDER)
	if order.status != Order.Status.ACCEPTED:
		return CommandResult.failure(CommandResult.ORDER_NOT_OPEN)
	if not is_helper(courier_id) and not hired.has(courier_id):
		return CommandResult.failure(CommandResult.WORKER_NOT_HIRED)
	if not _orders.can_fill(order):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_PRODUCT)
	if not is_free(courier_id, now):
		return CommandResult.failure(CommandResult.HELPER_AWAY if is_helper(courier_id) else CommandResult.COURIER_BUSY)
	if _suspicion.quiet:
		return CommandResult.failure(CommandResult.LYING_LOW)
	var trip := trip_seconds(courier_id)
	var product_ids := _orders.start_transit(order, courier_id, now + trip)
	busy_until[courier_id] = now + trip * 1.5
	if is_helper(courier_id):
		_helper.leave_for_delivery(now, busy_until[courier_id])
	_suspicion.add(_config.suspicion.per_delivery)
	_event_log.record(EventLog.ORDER_DISPATCHED, now, PackedStringArray([actor, courier_id, "order:%d" % order.id]), {
		"order_id": order.id,
		"courier_id": courier_id,
		"product_ids": product_ids,
	})
	return CommandResult.success(order.id)


## Held up on the road: he and the parcel arrive later.
func delay(order: Order, game_seconds: float) -> void:
	order.delayed = true
	order.arrives_at += game_seconds
	var courier_id := order.courier_id
	busy_until[courier_id] = busy_until.get(courier_id, order.arrives_at) + game_seconds
	if is_helper(courier_id):
		_helper.extend_away(busy_until[courier_id])


func next_event_time() -> float:
	var next := INF
	for order: Order in _orders.with_status(Order.Status.IN_TRANSIT):
		next = minf(next, order.arrives_at)
	return next


func process(now: float) -> void:
	for order: Order in _orders.with_status(Order.Status.IN_TRANSIT):
		if now >= order.arrives_at:
			_arrive(order, now)


func _arrive(order: Order, now: float) -> void:
	_orders.remove(order)
	var actors := PackedStringArray([order.courier_id, "order:%d" % order.id])
	if _rng.randf() < trip_risk(order.courier_id):
		_suspicion.add(_config.orders.stopped_suspicion)
		_event_log.record(EventLog.DELIVERY_STOPPED, now, actors, {"order_id": order.id, "courier_id": order.courier_id})
		return
	var def := _config.find_courier(order.courier_id)
	if def != null and _rng.randf() < def.greed:
		hired.erase(order.courier_id)
		busy_until.erase(order.courier_id)
		_event_log.record(EventLog.COURIER_STOLE, now, actors, {"order_id": order.id, "courier_id": order.courier_id})
		return
	var fee := roundi(float(order.reward) * (def.cut if def != null else 0.0))
	_economy.earn(order.reward - fee)
	_event_log.record(EventLog.ORDER_PAID, now, actors, {
		"order_id": order.id,
		"courier_id": order.courier_id,
		"reward": order.reward,
		"fee": fee,
		"money": _economy.money,
	})


func to_dict() -> Dictionary:
	var busy: Dictionary = {}
	for courier_id: String in busy_until:
		busy[courier_id] = ExactFloat.encode(busy_until[courier_id])
	return {"hired": hired.duplicate(), "busy_until": busy}


func load_dict(data: Dictionary) -> void:
	hired.clear()
	for courier_id: Variant in data["hired"] as Array:
		hired.append(String(courier_id))
	busy_until.clear()
	var busy := data["busy_until"] as Dictionary
	for courier_id: Variant in busy:
		busy_until[String(courier_id)] = ExactFloat.decode(busy[courier_id])
