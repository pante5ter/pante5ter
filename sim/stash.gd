class_name Stash
extends RefCounted

## The back room of the village bakery: harvest leaves the farm in crates and is packed and
## shipped from here. The drive with the crates is the risky part.

## Crates on the road, gone from the inventory until they arrive.
var transit: Array[Product] = []
var driver: String = ""
var arrives_at: float = INF

var _def: StashDef
var _config: BalanceConfig
var _inventory: Inventory
var _packing: Packing
var _suspicion: Suspicion
var _rng: SimRng
var _event_log: EventLog
var _helper: Helper = null
var _packer: Packer = null


func _init(config: BalanceConfig, inventory: Inventory, packing: Packing, suspicion: Suspicion, rng: SimRng, event_log: EventLog) -> void:
	_config = config
	_def = config.stash
	_inventory = inventory
	_packing = packing
	_suspicion = suspicion
	_rng = rng
	_event_log = event_log


func attach(helper: Helper, packer: Packer) -> void:
	_helper = helper
	_packer = packer


func on_the_road() -> bool:
	return not transit.is_empty()


func haul_seconds() -> float:
	return (_def.haul_hours if _def != null else 0.0) * SimClock.GAME_SECONDS_PER_HOUR


func risk(by: String) -> float:
	if _def == null:
		return 0.0
	var factor := _def.jack_risk_factor
	if by == Helper.ACTOR and _helper != null:
		factor = _helper.trip_risk_factor()
	var heat := 1.0 + _suspicion.level * _def.suspicion_risk_factor
	return clampf(_def.base_risk * heat * factor, 0.0, 1.0)


## Reggie takes the crates now and is back after the round trip (longer if he packs them there).
func send_with_helper(now: float, actor: String) -> CommandResult:
	if _helper == null or not _helper.exists():
		return CommandResult.failure(CommandResult.WORKER_NOT_HIRED)
	if not _helper.present():
		return CommandResult.failure(CommandResult.HELPER_AWAY)
	var loaded := _load(Helper.ACTOR, now, now + haul_seconds(), actor)
	if not loaded.ok:
		return loaded
	_helper.leave_for_haul(now, now + haul_seconds() * 2.0)
	return loaded


## Jack drives the crates himself; they arrive with him.
func load_for_jack(now: float, arrival: float, actor: String) -> CommandResult:
	return _load(DayCycle.JACK, now, arrival, actor)


func _load(by: String, now: float, arrival: float, actor: String) -> CommandResult:
	if on_the_road():
		return CommandResult.failure(CommandResult.HAUL_UNDER_WAY)
	var crates := _inventory.farm_crates()
	if crates.is_empty():
		return CommandResult.failure(CommandResult.NOTHING_TO_HAUL)
	for crate: Product in crates:
		transit.append(_inventory.take(crate.id))
	driver = by
	arrives_at = arrival
	if _def != null:
		_suspicion.add(_def.per_haul_suspicion)
	_event_log.record(EventLog.HAUL_STARTED, now, PackedStringArray([actor, by]), {
		"driver": by,
		"units": transit.size(),
		"arrives_at": arrives_at,
	})
	return CommandResult.success(transit.size())


func next_event_time() -> float:
	return arrives_at if on_the_road() else INF


func process(now: float) -> void:
	if on_the_road() and now >= arrives_at:
		_arrive(arrives_at)


func _arrive(at: float) -> void:
	var by := driver
	var units := transit.size()
	var crates := transit.duplicate()
	transit.clear()
	driver = ""
	arrives_at = INF
	if _rng.randf() < risk(by):
		if _def != null:
			_suspicion.add(_def.stopped_suspicion)
		_event_log.record(EventLog.HAUL_STOPPED, at, PackedStringArray([by]), {"driver": by, "units": units})
		return
	for crate: Product in crates:
		crate.at_stash = true
		_inventory.put(crate)
	_event_log.record(EventLog.HAUL_ARRIVED, at, PackedStringArray([by]), {"driver": by, "units": units})
	if by == Helper.ACTOR:
		_helper_packs(at)


func _helper_packs(at: float) -> void:
	if not _helper.knows(SkillDef.PACK) or _packing.busy() or (_packer != null and _packer.hired):
		return
	if _packing.start(at, Helper.ACTOR, _helper.definition().competence).ok:
		_helper.extend_away(_packing.ends_at + haul_seconds())


func value(economy: Economy) -> int:
	var total := 0
	for crate: Product in transit:
		total += economy.price_of(crate)
	return total


func to_dict() -> Dictionary:
	var crates: Array[Dictionary] = []
	for crate: Product in transit:
		crates.append(crate.to_dict())
	return {"transit": crates, "driver": driver, "arrives_at": ExactFloat.encode(arrives_at)}


func load_dict(data: Dictionary) -> void:
	transit.clear()
	for item: Variant in data["transit"] as Array:
		transit.append(Product.from_dict(item as Dictionary))
	driver = String(data["driver"])
	arrives_at = ExactFloat.decode(data["arrives_at"])
