class_name Packing
extends RefCounted

var ends_at: float = 0.0
var product_ids: Array[int] = []

var _def: OrdersDef
var _inventory: Inventory
var _event_log: EventLog


func _init(def: OrdersDef, inventory: Inventory, event_log: EventLog) -> void:
	_def = def
	_inventory = inventory
	_event_log = event_log


func busy() -> bool:
	return not product_ids.is_empty()


func unpacked_count() -> int:
	return _inventory.products().filter(func(product: Product) -> bool: return not product.packed).size()


func start(now: float, actor: String) -> CommandResult:
	if busy():
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	for product: Product in _inventory.products():
		if not product.packed:
			product_ids.append(product.id)
	if product_ids.is_empty():
		return CommandResult.failure(CommandResult.NOTHING_TO_PACK)
	ends_at = now + _def.pack_minutes_per_unit * 60.0 * float(product_ids.size())
	_event_log.record(EventLog.PACKING_STARTED, now, PackedStringArray([actor]), {"units": product_ids.size()})
	return CommandResult.success(product_ids.size())


func next_event_time() -> float:
	return ends_at if busy() else INF


func process(now: float) -> void:
	if not busy() or now < ends_at:
		return
	var packed := 0
	for product_id: int in product_ids:
		var product := _inventory.find(product_id)
		if product != null:
			product.packed = true
			packed += 1
	product_ids.clear()
	_event_log.record(EventLog.PACKING_DONE, now, PackedStringArray(), {"units": packed})


func to_dict() -> Dictionary:
	return {"ends_at": ExactFloat.encode(ends_at), "product_ids": product_ids.duplicate()}


func load_dict(data: Dictionary) -> void:
	ends_at = ExactFloat.decode(data["ends_at"])
	product_ids.clear()
	for product_id: Variant in data["product_ids"] as Array:
		product_ids.append(int(product_id))
