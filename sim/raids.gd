class_name Raids
extends RefCounted

const RAIDER_ACTOR: String = "raiders"
const PAY: String = "pay"
const GIVE: String = "give"
const CHASE: String = "chase"
## Outcomes where the gang left with crates and Jack was not there to answer them.
const UNATTENDED_ROBBERIES: Array[String] = ["ignored", "helper_failed"]

var pending: bool = false
var deadline: float = 0.0
var next_roll_at: float = 0.0
## Reggie heard they are coming tonight: the next night roll skips the dice.
var expected: bool = false
## Nights before this game time stay quiet: the gang was paid, scared off or lost its informer.
var calm_until: float = 0.0

var _def: RaidsDef
var _rng: SimRng
var _inventory: Inventory
var _economy: Economy
var _orders: Orders
var _workers: Workers
var _suspicion: Suspicion
var _event_log: EventLog
var _empire_value: Callable
var _helper: Helper = null


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


func attach_helper(helper: Helper) -> void:
	_helper = helper


func bribe() -> int:
	return _def.bribe


func chase_chance() -> float:
	var help := _workers.hired or (_helper != null and _helper.present())
	return clampf(_def.chase_chance + (_def.chase_bonus_with_worker if help else 0.0), 0.0, 1.0)


func calm(until: float) -> void:
	calm_until = maxf(calm_until, until)


func enabled() -> bool:
	return _def.chance_per_night > 0.0


func expect() -> bool:
	if pending or expected or not enabled():
		return false
	expected = true
	return true


func next_event_time() -> float:
	var next := next_roll_at if _def.chance_per_night > 0.0 or expected else INF
	if pending:
		next = minf(next, deadline)
	return next


func process(now: float) -> void:
	if pending and now >= deadline:
		_unanswered(now)
	while now >= next_roll_at:
		_roll(next_roll_at)
		next_roll_at += SimClock.GAME_SECONDS_PER_DAY


func _roll(at: float) -> void:
	var tipped := expected
	expected = false
	if pending or at < calm_until or not _has_loot():
		return
	if int(_empire_value.call()) >= _def.max_empire_value:
		return
	if not tipped and _rng.randf() >= _def.chance_per_night:
		return
	pending = true
	deadline = at + _def.deadline_hours * SimClock.GAME_SECONDS_PER_HOUR
	_event_log.record(EventLog.RAID_STARTED, at, PackedStringArray([RAIDER_ACTOR]), {"bribe": _def.bribe})


## The gang knows the container, not the stash: only crates still on the farm are at risk.
func _has_loot() -> bool:
	return not _inventory.farm_crates().is_empty()


func respond(choice: String, now: float, actor: String) -> CommandResult:
	if not pending:
		return CommandResult.failure(CommandResult.NO_RAID)
	match choice:
		PAY:
			if not _economy.spend(_def.bribe):
				return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
			_resolve(now, actor, "paid", {"paid": _def.bribe})
		GIVE:
			var products := _inventory.farm_crates()
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


func _unanswered(now: float) -> void:
	if _helper == null or not _helper.chases_raiders():
		_rob(now, "ignored")
		return
	_suspicion.add(_def.chase_noise)
	if _rng.randf() < chase_chance():
		_event_log.record(EventLog.HELPER_SAVED, now, PackedStringArray([Helper.ACTOR, RAIDER_ACTOR]), {"kind": Helper.SAVED_RAID})
		_resolve(now, Helper.ACTOR, "helper_chased", {})
	else:
		_rob(now, "helper_failed")


func _rob(now: float, outcome: String) -> void:
	var crates := _inventory.farm_crates()
	for product: Product in crates:
		_inventory.take(product.id)
	var taken := crates.size()
	_resolve(now, RAIDER_ACTOR, outcome, {"taken": taken})


func _resolve(now: float, actor: String, outcome: String, data: Dictionary) -> void:
	pending = false
	deadline = 0.0
	var record := data.duplicate()
	record["outcome"] = outcome
	_event_log.record(EventLog.RAID_RESOLVED, now, PackedStringArray([actor, RAIDER_ACTOR]), record)


static func is_unattended_robbery(event: SimEvent) -> bool:
	if event == null or event.type != EventLog.RAID_RESOLVED:
		return false
	return UNATTENDED_ROBBERIES.has(String(event.data.get("outcome", ""))) and crates_taken(event) > 0


static func crates_taken(event: SimEvent) -> int:
	return maxi(int(event.data.get("taken", 0)), 0)


## The latest robbery Jack missed at or after seq; null when there was none.
static func last_unattended_robbery_since(event_log: EventLog, seq: int) -> SimEvent:
	var found: SimEvent = null
	for event: SimEvent in event_log.since(seq):
		if is_unattended_robbery(event):
			found = event
	return found


func to_dict() -> Dictionary:
	return {
		"pending": pending,
		"deadline": ExactFloat.encode(deadline),
		"next_roll_at": ExactFloat.encode(next_roll_at),
		"expected": expected,
		"calm_until": ExactFloat.encode(calm_until),
	}


func load_dict(data: Dictionary) -> void:
	pending = data["pending"] == true
	deadline = ExactFloat.decode(data["deadline"])
	next_roll_at = ExactFloat.decode(data["next_roll_at"])
	expected = data.get("expected", false) == true
	calm_until = ExactFloat.decode(data["calm_until"]) if data.has("calm_until") else 0.0
