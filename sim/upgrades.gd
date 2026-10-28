class_name Upgrades
extends RefCounted

## Big kit for the bunker: bought in the phone shop, installed with the daily delivery.
## Everything installed is billed once a day; an unpaid bill switches all of it off until a bill is paid.

const ACTOR: String = "upgrades"
const AUTO_WATER_ACTOR: String = "auto_water"
## A bed this dry gets topped up on the hourly round.
const AUTO_WATER_BELOW_HOURS: float = 1.5

var owned: Array[String] = []
## upgrade id -> game time it arrives.
var on_order: Dictionary[String, float] = {}
var powered: bool = true
var next_bill_at: float = INF
var next_round_at: float = INF
## The raid deadline the camera already pushed back.
var spotted_deadline: float = -1.0
## Vivienne's gossip put one used piece on sale.
var sale_id: String = ""
var sale_price: int = 0
var sale_until: float = 0.0

var _shop: ShopDef
var _economy: Economy
var _suspicion: Suspicion
var _progress: Progress
var _supplies: Supplies
var _event_log: EventLog
var _grow: Grow = null
var _raids: Raids = null


func _init(shop: ShopDef, economy: Economy, suspicion: Suspicion, progress: Progress, supplies: Supplies, event_log: EventLog) -> void:
	_shop = shop
	_economy = economy
	_suspicion = suspicion
	_progress = progress
	_supplies = supplies
	_event_log = event_log


func attach(grow: Grow, raids: Raids) -> void:
	_grow = grow
	_raids = raids


func catalogue() -> Array[UpgradeDef]:
	var all: Array[UpgradeDef] = []
	if _shop != null:
		all.assign(_shop.upgrades)
	return all


func find(upgrade_id: String) -> UpgradeDef:
	return _shop.find_upgrade(upgrade_id) if _shop != null else null


func has(upgrade_id: String) -> bool:
	return owned.has(upgrade_id)


func unlocked(upgrade: UpgradeDef) -> bool:
	return _progress == null or upgrade.level <= _progress.reached


func price_of(upgrade_id: String) -> int:
	if on_sale(upgrade_id):
		return sale_price
	var upgrade := find(upgrade_id)
	return upgrade.price if upgrade != null else 0


func on_sale(upgrade_id: String) -> bool:
	return not sale_id.is_empty() and sale_id == upgrade_id


## Why it cannot be bought now; empty when it can, money aside.
func refusal(upgrade_id: String) -> String:
	var upgrade := find(upgrade_id)
	if upgrade == null:
		return CommandResult.UNKNOWN_ITEM
	if owned.has(upgrade_id) or on_order.has(upgrade_id) or _replaced_by_owned(upgrade_id):
		return CommandResult.ALREADY_DONE
	if not unlocked(upgrade):
		return CommandResult.UPGRADE_LOCKED
	if not upgrade.requires.is_empty() and not owned.has(upgrade.requires):
		return CommandResult.NEEDS_UPGRADE
	return ""


func _replaced_by_owned(upgrade_id: String) -> bool:
	for id: String in owned:
		var installed := find(id)
		if installed != null and installed.replaces == upgrade_id:
			return true
	return false


func buy(upgrade_id: String, now: float, actor: String) -> CommandResult:
	var refused := refusal(upgrade_id)
	if not refused.is_empty():
		return CommandResult.failure(refused)
	var cost := price_of(upgrade_id)
	if not _economy.spend(cost):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	var used := on_sale(upgrade_id)
	if used:
		end_sale()
	on_order[upgrade_id] = _supplies.arrival_for(now)
	_event_log.record(EventLog.UPGRADE_ORDERED, now, PackedStringArray([actor]), {
		"upgrade_id": upgrade_id,
		"cost": cost,
		"used": used,
		"arrives_at": on_order[upgrade_id],
		"money": _economy.money,
	})
	return CommandResult.success(cost)


## Unlocked, not owned and not coming: what a household selling up might have.
func sale_candidates() -> Array[String]:
	var found: Array[String] = []
	for upgrade: UpgradeDef in catalogue():
		if refusal(upgrade.id).is_empty():
			found.append(upgrade.id)
	return found


func start_sale(upgrade_id: String, price: int, until: float) -> void:
	sale_id = upgrade_id
	sale_price = price
	sale_until = until


func end_sale() -> void:
	sale_id = ""
	sale_price = 0
	sale_until = 0.0


func _active() -> Array[UpgradeDef]:
	var found: Array[UpgradeDef] = []
	if not powered:
		return found
	for id: String in owned:
		var upgrade := find(id)
		if upgrade != null:
			found.append(upgrade)
	return found


func humidity_drop() -> float:
	var total := 0.0
	for upgrade: UpgradeDef in _active():
		total += upgrade.humidity_drop
	return total


func growth_multiplier() -> float:
	var total := 1.0
	for upgrade: UpgradeDef in _active():
		total += upgrade.growth_speed
	return maxf(total, 0.1)


func yield_bonus() -> int:
	var total := 0
	for upgrade: UpgradeDef in _active():
		total += upgrade.yield_bonus
	return total


func quality_bonus() -> int:
	var total := 0
	for upgrade: UpgradeDef in _active():
		total += upgrade.quality_bonus
	return total


func auto_water_beds() -> int:
	var most := 0
	for upgrade: UpgradeDef in _active():
		most = maxi(most, upgrade.auto_water_beds)
	return most


func raid_warning_hours() -> float:
	var most := 0.0
	for upgrade: UpgradeDef in _active():
		most = maxf(most, upgrade.raid_warning_hours)
	return most


## The bill whether or not the kit is running: it has to be paid to switch back on.
func daily_cost() -> int:
	var total := 0
	for id: String in owned:
		var upgrade := find(id)
		if upgrade != null:
			total += upgrade.daily_cost
	return total


## What the installed kit adds to the empire.
func value() -> int:
	var total := 0
	for id: String in owned:
		var upgrade := find(id)
		if upgrade != null:
			total += upgrade.price
	return total


func next_event_time() -> float:
	var next := minf(next_bill_at, next_round_at)
	for id: String in on_order:
		next = minf(next, on_order[id])
	return next


func process(now: float) -> void:
	for id: String in on_order.keys():
		if on_order[id] <= now:
			_install(id, on_order[id])
	while now >= next_bill_at:
		_bill(next_bill_at)
		next_bill_at += SimClock.GAME_SECONDS_PER_DAY
	while now >= next_round_at:
		_water_round(next_round_at)
		next_round_at += SimClock.GAME_SECONDS_PER_HOUR
	_watch_the_road(now)


func _install(upgrade_id: String, at: float) -> void:
	on_order.erase(upgrade_id)
	var upgrade := find(upgrade_id)
	if upgrade == null:
		return
	if not upgrade.replaces.is_empty():
		owned.erase(upgrade.replaces)
	owned.append(upgrade_id)
	_suspicion.add(upgrade.install_suspicion)
	_event_log.record(EventLog.UPGRADE_INSTALLED, at, PackedStringArray([ACTOR]), {"upgrade_id": upgrade_id, "replaced": upgrade.replaces})
	if next_bill_at == INF:
		next_bill_at = _next_hour(at, _shop.bill_hour)
	if upgrade.auto_water_beds > 0 and next_round_at == INF:
		next_round_at = at


## The first time of day `hour` after `at`.
static func _next_hour(at: float, hour: float) -> float:
	var slot := floorf(at / SimClock.GAME_SECONDS_PER_DAY) * SimClock.GAME_SECONDS_PER_DAY + hour * SimClock.GAME_SECONDS_PER_HOUR
	return slot if slot > at else slot + SimClock.GAME_SECONDS_PER_DAY


func _bill(at: float) -> void:
	var amount := daily_cost()
	if amount <= 0:
		return
	if _economy.spend(amount):
		powered = true
		var noticed := 0.0
		for upgrade: UpgradeDef in _active():
			noticed += upgrade.daily_suspicion
		_suspicion.add(noticed)
		_event_log.record(EventLog.UPGRADES_BILLED, at, PackedStringArray([ACTOR]), {"amount": amount, "money": _economy.money})
		return
	powered = false
	_event_log.record(EventLog.UPGRADES_CUT, at, PackedStringArray([ACTOR]), {"amount": amount, "money": _economy.money})


func _water_round(at: float) -> void:
	var beds := auto_water_beds()
	if beds <= 0 or _grow == null:
		return
	var watered: Array[int] = []
	for target: Plot in _grow.plots():
		if target.id >= beds or not target.is_growing():
			continue
		if target.water_seconds < AUTO_WATER_BELOW_HOURS * SimClock.GAME_SECONDS_PER_HOUR:
			target.water_seconds = _grow.strain_of(target).water_capacity_hours * SimClock.GAME_SECONDS_PER_HOUR
			watered.append(target.id)
	if not watered.is_empty():
		_event_log.record(EventLog.AUTO_WATERED, at, PackedStringArray([AUTO_WATER_ACTOR]), {"plot_ids": watered})


## The camera sees the gang at the gate: their deadline moves back, once per raid.
func _watch_the_road(now: float) -> void:
	var hours := raid_warning_hours()
	if hours <= 0.0 or _raids == null or not _raids.pending or _raids.deadline == spotted_deadline:
		return
	_raids.deadline += hours * SimClock.GAME_SECONDS_PER_HOUR
	spotted_deadline = _raids.deadline
	_event_log.record(EventLog.RAID_SPOTTED, now, PackedStringArray([ACTOR, Raids.RAIDER_ACTOR]), {"hours": hours, "deadline": _raids.deadline})


func to_dict() -> Dictionary:
	var coming := {}
	for id: String in on_order:
		coming[id] = ExactFloat.encode(on_order[id])
	return {
		"owned": owned.duplicate(),
		"on_order": coming,
		"powered": powered,
		"next_bill_at": ExactFloat.encode(next_bill_at),
		"next_round_at": ExactFloat.encode(next_round_at),
		"spotted_deadline": ExactFloat.encode(spotted_deadline),
		"sale_id": sale_id,
		"sale_price": sale_price,
		"sale_until": ExactFloat.encode(sale_until),
	}


func load_dict(data: Dictionary) -> void:
	owned.clear()
	for id: Variant in data.get("owned", []) as Array:
		if find(String(id)) != null:
			owned.append(String(id))
	on_order.clear()
	var coming := data.get("on_order", {}) as Dictionary
	for id: Variant in coming:
		if find(String(id)) != null:
			on_order[String(id)] = ExactFloat.decode(coming[id])
	powered = data.get("powered", true) == true
	next_bill_at = ExactFloat.decode(data["next_bill_at"]) if data.has("next_bill_at") else INF
	next_round_at = ExactFloat.decode(data["next_round_at"]) if data.has("next_round_at") else INF
	spotted_deadline = ExactFloat.decode(data["spotted_deadline"]) if data.has("spotted_deadline") else -1.0
	sale_id = String(data.get("sale_id", ""))
	sale_price = int(data.get("sale_price", 0))
	sale_until = ExactFloat.decode(data["sale_until"]) if data.has("sale_until") else 0.0
