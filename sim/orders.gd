class_name Orders
extends RefCounted

const COURIER_ACTOR: String = "courier"

var next_spawn_at: float = 0.0

var _orders: Array[Order] = []
var _next_id: int = 1
var _def: OrdersDef
var _reference_strain: StrainDef
var _rng: SimRng
var _inventory: Inventory
var _economy: Economy
var _event_log: EventLog


func _init(def: OrdersDef, reference_strain: StrainDef, rng: SimRng, inventory: Inventory, economy: Economy, event_log: EventLog) -> void:
	_def = def
	_reference_strain = reference_strain
	_rng = rng
	_inventory = inventory
	_economy = economy
	_event_log = event_log
	next_spawn_at = def.first_order_hours * SimClock.GAME_SECONDS_PER_HOUR


func all() -> Array[Order]:
	return _orders.duplicate()


func find(order_id: int) -> Order:
	for order: Order in _orders:
		if order.id == order_id:
			return order
	return null


func matching_products(order: Order) -> Array[Product]:
	var candidates: Array[Product] = []
	for product: Product in _inventory.products():
		if product.quality >= order.min_quality:
			candidates.append(product)
	candidates.sort_custom(func(a: Product, b: Product) -> bool: return a.quality < b.quality or (a.quality == b.quality and a.id < b.id))
	return candidates.slice(0, order.quantity)


func can_fill(order: Order) -> bool:
	return order.status == Order.Status.OPEN and matching_products(order).size() >= order.quantity


func drop(order_id: int, now: float, actor: String) -> CommandResult:
	var order := find(order_id)
	if order == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ORDER)
	if order.status != Order.Status.OPEN:
		return CommandResult.failure(CommandResult.ORDER_NOT_OPEN)
	var products := matching_products(order)
	if products.size() < order.quantity:
		return CommandResult.failure(CommandResult.NOT_ENOUGH_PRODUCT)
	var product_ids: Array[int] = []
	for product: Product in products:
		_inventory.take(product.id)
		product_ids.append(product.id)
	order.status = Order.Status.DROPPED
	order.pickup_at = now + _def.pickup_hours * SimClock.GAME_SECONDS_PER_HOUR
	_event_log.record(EventLog.ORDER_DROPPED, now, PackedStringArray([actor, "order:%d" % order.id]), {
		"order_id": order.id,
		"product_ids": product_ids,
	})
	return CommandResult.success(order.id)


func next_event_time() -> float:
	var next := next_spawn_at
	for order: Order in _orders:
		next = minf(next, order.deadline if order.status == Order.Status.OPEN else order.pickup_at)
	return next


func process(now: float) -> void:
	for order: Order in _orders.duplicate():
		if order.status == Order.Status.OPEN and now >= order.deadline:
			_orders.erase(order)
			_event_log.record(EventLog.ORDER_EXPIRED, now, PackedStringArray(["order:%d" % order.id]), {"order_id": order.id})
		elif order.status == Order.Status.DROPPED and now >= order.pickup_at:
			_orders.erase(order)
			_economy.earn(order.reward)
			_event_log.record(EventLog.ORDER_PAID, now, PackedStringArray([COURIER_ACTOR, "order:%d" % order.id]), {
				"order_id": order.id,
				"reward": order.reward,
				"money": _economy.money,
			})
	while now >= next_spawn_at:
		if _orders.size() < _def.max_open:
			_spawn(next_spawn_at)
		next_spawn_at += _def.interval_hours * SimClock.GAME_SECONDS_PER_HOUR


func _spawn(at: float) -> void:
	var order := Order.new()
	order.id = _next_id
	_next_id += 1
	order.quantity = _rng.randi_range(_def.quantity_min, _def.quantity_max)
	var quality_steps := maxi(floori(float(_def.quality_max - _def.quality_min) / float(maxi(_def.quality_step, 1))), 0)
	order.min_quality = _def.quality_min + _rng.randi_range(0, quality_steps) * _def.quality_step
	order.reward = roundi(float(order.quantity * Economy.price_with(_reference_strain, order.min_quality)) * _def.reward_multiplier)
	order.deadline = at + _def.deadline_hours * SimClock.GAME_SECONDS_PER_HOUR
	_orders.append(order)
	_event_log.record(EventLog.ORDER_RECEIVED, at, PackedStringArray(["order:%d" % order.id]), {
		"order_id": order.id,
		"quantity": order.quantity,
		"min_quality": order.min_quality,
		"reward": order.reward,
	})


func to_dict() -> Dictionary:
	var items: Array[Dictionary] = []
	for order: Order in _orders:
		items.append(order.to_dict())
	return {"next_id": _next_id, "next_spawn_at": ExactFloat.encode(next_spawn_at), "orders": items}


func load_dict(data: Dictionary) -> void:
	_next_id = int(data["next_id"])
	next_spawn_at = ExactFloat.decode(data["next_spawn_at"])
	_orders.clear()
	for item: Variant in data["orders"] as Array:
		_orders.append(Order.from_dict(item as Dictionary))
