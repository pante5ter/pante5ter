class_name Supplies
extends RefCounted

const FERTILIZER: String = "fertilizer"
const PESTICIDE: String = "pesticide"
const LAMP: String = "lamp"
const TOOLS: Array[String] = [PESTICIDE, LAMP]
const SEED_PREFIX: String = "seed:"
const AUTO_ACTOR: String = "auto_reorder"

var fertilizer: int = 0
## item -> keep this many in stock and on the way.
var auto_keep: Dictionary[String, int] = {}
var next_reorder_at: float = INF

var _seeds: Dictionary[String, int] = {}
var _items: Dictionary[String, int] = {}
var _progress: Progress = null
var _deliveries: Array[Dictionary] = []
var _parcel: Array[Dictionary] = []
var _config: BalanceConfig
var _economy: Economy
var _event_log: EventLog


func _init(config: BalanceConfig, economy: Economy, event_log: EventLog) -> void:
	_config = config
	_economy = economy
	_event_log = event_log


func attach(progress: Progress) -> void:
	_progress = progress


func count(item: String) -> int:
	if item == FERTILIZER:
		return fertilizer
	return _items.get(item, 0)


## Stock in hand plus everything bought and not yet picked up.
func stock_and_coming(item: String) -> int:
	var total := seeds(item.trim_prefix(SEED_PREFIX)) if item.begins_with(SEED_PREFIX) else count(item)
	for delivery: Dictionary in _deliveries:
		if String(delivery["item"]) == item:
			total += int(delivery["quantity"])
	for entry: Dictionary in _parcel:
		if String(entry["item"]) == item:
			total += int(entry["quantity"])
	return total


func can_order(item: String) -> bool:
	if unit_price(item) <= 0:
		return false
	return not item.begins_with(SEED_PREFIX) or _progress == null or _progress.is_strain_unlocked(item.trim_prefix(SEED_PREFIX))


## Tops the basket up as far as the money goes, one parcel line per item.
func restock(now: float, actor: String) -> CommandResult:
	var wanted := false
	var spent := 0
	for item: String in _config.restock_basket:
		if not can_order(item):
			continue
		var need := _config.restock_basket[item] - stock_and_coming(item)
		if need <= 0:
			continue
		wanted = true
		spent += _buy_up_to(item, need, now, actor)
	if not wanted:
		return CommandResult.failure(CommandResult.NOTHING_TO_RESTOCK)
	if spent == 0:
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	return CommandResult.success(spent)


func basket_cost() -> int:
	var cost := 0
	for item: String in _config.restock_basket:
		if can_order(item):
			cost += maxi(_config.restock_basket[item] - stock_and_coming(item), 0) * unit_price(item)
	return cost


func set_auto_reorder(item: String, keep: int, now: float, actor: String) -> CommandResult:
	if keep < 0:
		return CommandResult.failure(CommandResult.INVALID_QUANTITY)
	if unit_price(item) <= 0:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	if not can_order(item):
		return CommandResult.failure(CommandResult.STRAIN_LOCKED)
	if keep == 0:
		auto_keep.erase(item)
	else:
		auto_keep[item] = keep
	_event_log.record(EventLog.SUPPLY_RULE_SET, now, PackedStringArray([actor]), {"item": item, "keep": keep})
	if auto_keep.is_empty():
		next_reorder_at = INF
		return CommandResult.success()
	_reorder(now)
	if next_reorder_at == INF:
		next_reorder_at = now + _check_seconds()
	return CommandResult.success()


func _check_seconds() -> float:
	return maxf(_config.auto_reorder_check_hours, 0.05) * SimClock.GAME_SECONDS_PER_HOUR


func _reorder(at: float) -> void:
	for item: String in auto_keep:
		if not can_order(item):
			continue
		var need := auto_keep[item] - stock_and_coming(item)
		if need > 0:
			_buy_up_to(item, need, at, AUTO_ACTOR)


func _buy_up_to(item: String, need: int, now: float, actor: String) -> int:
	var affordable := mini(need, floori(float(_economy.money) / float(unit_price(item))))
	if affordable <= 0:
		return 0
	var result := buy(item, affordable, now, actor)
	return result.value if result.ok else 0


func take_item(item: String) -> bool:
	if count(item) <= 0:
		return false
	_items[item] = count(item) - 1
	return true


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
	if item == PESTICIDE:
		return _config.problems.pesticide_price
	if item == LAMP:
		return _config.problems.lamp_price
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
	if item.begins_with(SEED_PREFIX) and _progress != null and not _progress.is_strain_unlocked(item.trim_prefix(SEED_PREFIX)):
		return CommandResult.failure(CommandResult.STRAIN_LOCKED)
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
	var next := next_reorder_at
	for delivery: Dictionary in _deliveries:
		next = minf(next, float(delivery["arrives_at"]))
	return next


func process(now: float) -> void:
	_process_deliveries(now)
	while now >= next_reorder_at:
		_reorder(next_reorder_at)
		next_reorder_at += _check_seconds()


func _process_deliveries(now: float) -> void:
	for delivery: Dictionary in _deliveries.duplicate():
		if float(delivery["arrives_at"]) > now:
			continue
		_deliveries.erase(delivery)
		var item := String(delivery["item"])
		var quantity := int(delivery["quantity"])
		_parcel.append({"item": item, "quantity": quantity})
		_event_log.record(EventLog.SUPPLY_DELIVERED, now, PackedStringArray(), {"item": item, "quantity": quantity})


func parcel() -> Array[Dictionary]:
	return _parcel.duplicate(true)


func pick_up(now: float, actor: String) -> CommandResult:
	if _parcel.is_empty():
		return CommandResult.failure(CommandResult.NO_PARCEL)
	var items := 0
	for entry: Dictionary in _parcel:
		_stock(String(entry["item"]), int(entry["quantity"]))
		items += int(entry["quantity"])
	_parcel.clear()
	_event_log.record(EventLog.PARCEL_PICKED_UP, now, PackedStringArray([actor]), {"items": items})
	return CommandResult.success(items)


func _stock(item: String, quantity: int) -> void:
	if item == FERTILIZER:
		fertilizer += quantity
	elif TOOLS.has(item):
		_items[item] = count(item) + quantity
	else:
		var strain_id := item.trim_prefix(SEED_PREFIX)
		_seeds[strain_id] = seeds(strain_id) + quantity


func to_dict() -> Dictionary:
	var deliveries: Array[Dictionary] = []
	for delivery: Dictionary in _deliveries:
		deliveries.append({
			"item": delivery["item"],
			"quantity": delivery["quantity"],
			"arrives_at": ExactFloat.encode(float(delivery["arrives_at"])),
		})
	return {
		"fertilizer": fertilizer,
		"seeds": _seeds.duplicate(),
		"items": _items.duplicate(),
		"deliveries": deliveries,
		"parcel": _parcel.duplicate(true),
		"auto_keep": auto_keep.duplicate(),
		"next_reorder_at": ExactFloat.encode(next_reorder_at),
	}


func load_dict(data: Dictionary) -> void:
	fertilizer = int(data["fertilizer"])
	auto_keep.clear()
	var stored_rules := data.get("auto_keep", {}) as Dictionary
	for item_id: Variant in stored_rules:
		auto_keep[String(item_id)] = int(stored_rules[item_id])
	next_reorder_at = ExactFloat.decode(data["next_reorder_at"]) if data.has("next_reorder_at") else INF
	_seeds.clear()
	var stored_seeds := data["seeds"] as Dictionary
	for strain_id: Variant in stored_seeds:
		_seeds[String(strain_id)] = int(stored_seeds[strain_id])
	_items.clear()
	var stored_items := data["items"] as Dictionary
	for item_id: Variant in stored_items:
		_items[String(item_id)] = int(stored_items[item_id])
	_parcel.clear()
	for entry: Variant in data["parcel"] as Array:
		var stored := entry as Dictionary
		_parcel.append({"item": String(stored["item"]), "quantity": int(stored["quantity"])})
	_deliveries.clear()
	for item: Variant in data["deliveries"] as Array:
		var delivery := item as Dictionary
		_deliveries.append({
			"item": String(delivery["item"]),
			"quantity": int(delivery["quantity"]),
			"arrives_at": ExactFloat.decode(delivery["arrives_at"]),
		})
