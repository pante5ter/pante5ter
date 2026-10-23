class_name Supplies
extends RefCounted

const FERTILIZER: String = "fertilizer"
const SEED_PREFIX: String = "seed:"

var fertilizer: int = 0

var _seeds: Dictionary[String, int] = {}
var _deliveries: Array[Dictionary] = []
var _config: BalanceConfig
var _economy: Economy
var _event_log: EventLog


func _init(config: BalanceConfig, economy: Economy, event_log: EventLog) -> void:
	_config = config
	_economy = economy
	_event_log = event_log


static func seed_item(strain_id: String) -> String:
	return SEED_PREFIX + strain_id


func seeds(strain_id: String) -> int:
	return _seeds.get(strain_id, 0)


func take_seed(strain_id: String) -> bool:
	if seeds(strain_id) <= 0:
		return false
	_seeds[strain_id] = seeds(strain_id) - 1
	return true


func take_fertilizer() -> bool:
	if fertilizer <= 0:
		return false
	fertilizer -= 1
	return true


func unit_price(item: String) -> int:
	if item == FERTILIZER:
		return _config.fertilizer_price
	if item.begins_with(SEED_PREFIX):
		var strain := _config.find_strain(item.trim_prefix(SEED_PREFIX))
		if strain != null and strain.needs_seeds():
			return strain.seed_price
	return 0


func buy(item: String, quantity: int, now: float, actor: String) -> CommandResult:
	if quantity <= 0:
		return CommandResult.failure(CommandResult.INVALID_QUANTITY)
	var price := unit_price(item)
	if price <= 0:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	var cost := price * quantity
	if not _economy.spend(cost):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	var arrives_at := now + _config.delivery_hours * SimClock.GAME_SECONDS_PER_HOUR
	_deliveries.append({"item": item, "quantity": quantity, "arrives_at": arrives_at})
	_event_log.record(EventLog.SUPPLY_ORDERED, now, PackedStringArray([actor]), {
		"item": item,
		"quantity": quantity,
		"cost": cost,
		"money": _economy.money,
	})
	return CommandResult.success(cost)


func pending_deliveries() -> Array[Dictionary]:
	return _deliveries.duplicate(true)


func next_event_time() -> float:
	var next := INF
	for delivery: Dictionary in _deliveries:
		next = minf(next, float(delivery["arrives_at"]))
	return next


func process(now: float) -> void:
	for delivery: Dictionary in _deliveries.duplicate():
		if float(delivery["arrives_at"]) > now:
			continue
		_deliveries.erase(delivery)
		var item := String(delivery["item"])
		var quantity := int(delivery["quantity"])
		if item == FERTILIZER:
			fertilizer += quantity
		else:
			var strain_id := item.trim_prefix(SEED_PREFIX)
			_seeds[strain_id] = seeds(strain_id) + quantity
		_event_log.record(EventLog.SUPPLY_DELIVERED, now, PackedStringArray(), {"item": item, "quantity": quantity})


func to_dict() -> Dictionary:
	var deliveries: Array[Dictionary] = []
	for delivery: Dictionary in _deliveries:
		deliveries.append({
			"item": delivery["item"],
			"quantity": delivery["quantity"],
			"arrives_at": ExactFloat.encode(float(delivery["arrives_at"])),
		})
	return {"fertilizer": fertilizer, "seeds": _seeds.duplicate(), "deliveries": deliveries}


func load_dict(data: Dictionary) -> void:
	fertilizer = int(data["fertilizer"])
	_seeds.clear()
	var stored_seeds := data["seeds"] as Dictionary
	for strain_id: Variant in stored_seeds:
		_seeds[String(strain_id)] = int(stored_seeds[strain_id])
	_deliveries.clear()
	for item: Variant in data["deliveries"] as Array:
		var delivery := item as Dictionary
		_deliveries.append({
			"item": String(delivery["item"]),
			"quantity": int(delivery["quantity"]),
			"arrives_at": ExactFloat.decode(delivery["arrives_at"]),
		})
