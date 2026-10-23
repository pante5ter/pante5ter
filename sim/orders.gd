class_name Orders
extends RefCounted

const ACCEPT: String = "accept"
const DECLINE: String = "decline"
const HAGGLE: String = "haggle"

var next_spawn_at: float = 0.0

var _orders: Array[Order] = []
var _next_id: int = 1
var _def: OrdersDef
var _reference_strain: StrainDef
var _rng: SimRng
var _inventory: Inventory
var _event_log: EventLog


func _init(def: OrdersDef, reference_strain: StrainDef, rng: SimRng, inventory: Inventory, event_log: EventLog) -> void:
	_def = def
	_reference_strain = reference_strain
	_rng = rng
	_inventory = inventory
	_event_log = event_log
	next_spawn_at = def.first_order_hours * SimClock.GAME_SECONDS_PER_HOUR


func all() -> Array[Order]:
	return _orders.duplicate()


func with_status(status: Order.Status) -> Array[Order]:
	var matching: Array[Order] = []
	for order: Order in _orders:
		if order.status == status:
			matching.append(order)
	return matching


func find(order_id: int) -> Order:
	for order: Order in _orders:
		if order.id == order_id:
			return order
	return null


func remove(order: Order) -> void:
	_orders.erase(order)


func matching_products(order: Order) -> Array[Product]:
	var candidates: Array[Product] = []
	for product: Product in _inventory.products():
		if product.packed and product.quality >= order.min_quality:
			candidates.append(product)
	candidates.sort_custom(func(a: Product, b: Product) -> bool: return a.quality < b.quality or (a.quality == b.quality and a.id < b.id))
	return candidates.slice(0, order.quantity)


func can_fill(order: Order) -> bool:
	return order.status == Order.Status.ACCEPTED and matching_products(order).size() >= order.quantity


func answer(order_id: int, choice: String, now: float, actor: String) -> CommandResult:
	var order := find(order_id)
	if order == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ORDER)
	if order.status != Order.Status.OFFERED:
		return CommandResult.failure(CommandResult.ORDER_NOT_OPEN)
	match choice:
		ACCEPT:
			_accept(order, now, actor)
		DECLINE:
			_orders.erase(order)
			_event_log.record(EventLog.ORDER_DECLINED, now, PackedStringArray([actor, _tag(order)]), {"order_id": order.id})
		HAGGLE:
			if order.haggled:
				return CommandResult.failure(CommandResult.ALREADY_DONE)
			order.haggled = true
			if _rng.randf() < _def.haggle_success:
				order.reward = roundi(float(order.reward) * (1.0 + _def.haggle_bonus))
				_event_log.record(EventLog.ORDER_HAGGLED, now, PackedStringArray([actor, _tag(order)]), {"order_id": order.id, "reward": order.reward})
			else:
				_orders.erase(order)
				_event_log.record(EventLog.ORDER_WALKED_AWAY, now, PackedStringArray([actor, _tag(order)]), {"order_id": order.id})
		_:
			return CommandResult.failure(CommandResult.UNKNOWN_CHOICE)
	return CommandResult.success(order.id)


func _accept(order: Order, now: float, actor: String) -> void:
	order.status = Order.Status.ACCEPTED
	order.deadline = now + _def.deadline_hours * SimClock.GAME_SECONDS_PER_HOUR
	_event_log.record(EventLog.ORDER_ACCEPTED, now, PackedStringArray([actor, _tag(order)]), {"order_id": order.id, "reward": order.reward})


func start_transit(order: Order, courier_id: String, arrives_at: float) -> Array[int]:
	var product_ids: Array[int] = []
	for product: Product in matching_products(order):
		_inventory.take(product.id)
		product_ids.append(product.id)
	order.status = Order.Status.IN_TRANSIT
	order.courier_id = courier_id
	order.product_ids = product_ids
	order.arrives_at = arrives_at
	return product_ids


func next_event_time() -> float:
	var next := next_spawn_at
	for order: Order in _orders:
		if order.status == Order.Status.OFFERED:
			next = minf(next, order.answer_by)
		elif order.status == Order.Status.ACCEPTED:
			next = minf(next, order.deadline)
	return next


func process(now: float) -> void:
	for order: Order in _orders.duplicate():
		if order.status == Order.Status.OFFERED and now >= order.answer_by:
			_orders.erase(order)
			_event_log.record(EventLog.ORDER_MISSED, now, PackedStringArray([_tag(order)]), {"order_id": order.id})
		elif order.status == Order.Status.ACCEPTED and now >= order.deadline:
			_orders.erase(order)
			_event_log.record(EventLog.ORDER_EXPIRED, now, PackedStringArray([_tag(order)]), {"order_id": order.id})
	while now >= next_spawn_at:
		if _open_count() < _def.max_open:
			_spawn(next_spawn_at)
		next_spawn_at += _def.interval_hours * SimClock.GAME_SECONDS_PER_HOUR


func _open_count() -> int:
	return _orders.size() - with_status(Order.Status.IN_TRANSIT).size()


func _spawn(at: float) -> void:
	var order := Order.new()
	order.id = _next_id
	_next_id += 1
	order.quantity = _rng.randi_range(_def.quantity_min, _def.quantity_max)
	var quality_steps := maxi(floori(float(_def.quality_max - _def.quality_min) / float(maxi(_def.quality_step, 1))), 0)
	order.min_quality = _def.quality_min + _rng.randi_range(0, quality_steps) * _def.quality_step
	order.reward = roundi(float(order.quantity * Economy.price_with(_reference_strain, order.min_quality)) * _def.reward_multiplier)
	order.answer_by = at + _def.answer_hours * SimClock.GAME_SECONDS_PER_HOUR
	_orders.append(order)
	_event_log.record(EventLog.ORDER_RECEIVED, at, PackedStringArray([_tag(order)]), {
		"order_id": order.id,
		"quantity": order.quantity,
		"min_quality": order.min_quality,
		"reward": order.reward,
	})


static func _tag(order: Order) -> String:
	return "order:%d" % order.id


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
