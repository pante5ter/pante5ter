class_name HandPacking
extends RefCounted

## «Весы»: Jack weighs the bags himself. The scene only reports how far each bag missed the target;
## the grades, the bonus and the packing job are decided here.

enum Grade { PERFECT, GOOD, FAIR, SLOPPY }

var _def: HandPackingDef
var _packing: Packing
var _inventory: Inventory
var _day: DayCycle
var _event_log: EventLog


func _init(def: HandPackingDef, packing: Packing, inventory: Inventory, day: DayCycle, event_log: EventLog) -> void:
	_def = def
	_packing = packing
	_inventory = inventory
	_day = day
	_event_log = event_log


func definition() -> HandPackingDef:
	return _def


func available() -> bool:
	return _def != null


func bags_for(units: int) -> int:
	return clampi(units, _def.min_bags, maxi(_def.max_bags, _def.min_bags))


func bags_now() -> int:
	return bags_for(_packing.unpacked_count())


## Fixed for this batch, so the scene shows the same pours however often the round is opened.
func round_seed() -> int:
	var lowest := -1
	for product: Product in _inventory.at_stash():
		if not product.packed and (lowest < 0 or product.id < lowest):
			lowest = product.id
	return maxi(lowest, 0)


## Real seconds for the needle to reach the target on this bag.
static func fill_seconds(def: HandPackingDef, seed_value: int, bag: int) -> float:
	return lerpf(def.fill_seconds_min, def.fill_seconds_max, _unit_noise(seed_value, bag))


static func grade(def: HandPackingDef, miss_grams: float) -> Grade:
	var off := absf(miss_grams)
	if is_nan(off) or off > def.fair_grams:
		return Grade.SLOPPY
	if off <= def.perfect_grams:
		return Grade.PERFECT
	if off <= def.good_grams:
		return Grade.GOOD
	return Grade.FAIR


static func points(def: HandPackingDef, bag_grade: Grade) -> float:
	match bag_grade:
		Grade.PERFECT:
			return 1.0
		Grade.GOOD:
			return def.good_points
		Grade.FAIR:
			return 0.0
	return def.sloppy_points


## Mean points over the bags, within -1..1.
static func accuracy(def: HandPackingDef, misses: Array[float]) -> float:
	if misses.is_empty():
		return 0.0
	var total := 0.0
	for miss: float in misses:
		total += points(def, grade(def, miss))
	return clampf(total / float(misses.size()), -1.0, 1.0)


static func quality_bonus(def: HandPackingDef, misses: Array[float]) -> int:
	var raw := roundi(accuracy(def, misses) * float(def.max_quality_bonus))
	return clampi(raw, -maxi(def.max_quality_penalty, 0), maxi(def.max_quality_bonus, 0))


## The bonus lifts no unit above the ceiling and never lowers one already above it.
static func bonus_quality(def: HandPackingDef, quality: int, bonus: int) -> int:
	if bonus >= 0:
		return maxi(quality, mini(quality + bonus, def.quality_ceiling))
	return maxi(quality + bonus, 0)


## Starts the usual packing job and applies the round's bonus to every unit of the batch.
func pack(now: float, actor: String, misses: Array[float]) -> CommandResult:
	if _def == null:
		return CommandResult.failure(CommandResult.UNKNOWN_COMMAND)
	if _day.travelling():
		return CommandResult.failure(CommandResult.ON_THE_ROAD)
	if _day.place != DayCycle.STASH:
		return CommandResult.failure(CommandResult.NOT_AT_STASH)
	if _packing.busy():
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	var units := _packing.unpacked_count()
	if units > 0 and not _valid(misses, bags_for(units)):
		return CommandResult.failure(CommandResult.INVALID_QUANTITY)
	var started := _packing.start(now, actor)
	if not started.ok:
		return started
	var bonus := quality_bonus(_def, misses)
	var perfect := 0
	for miss: float in misses:
		if grade(_def, miss) == Grade.PERFECT:
			perfect += 1
	var changed := 0
	for product_id: int in _packing.product_ids:
		var product := _inventory.find(product_id)
		if product == null:
			continue
		var lifted := bonus_quality(_def, product.quality, bonus)
		if lifted != product.quality:
			changed += 1
		product.quality = lifted
	_event_log.record(EventLog.PACKING_HAND_SCORED, now, PackedStringArray([actor]), {
		"units": started.value,
		"bags": misses.size(),
		"perfect": perfect,
		"accuracy": snappedf(accuracy(_def, misses), 0.001),
		"quality_bonus": bonus,
		"units_changed": changed,
		"misses": misses.map(func(miss: float) -> float: return snappedf(miss, 0.01)),
	})
	return started


func _valid(misses: Array[float], bags: int) -> bool:
	if misses.size() != bags:
		return false
	for miss: float in misses:
		if is_nan(miss) or is_inf(miss):
			return false
	return true


static func _unit_noise(seed_value: int, bag: int) -> float:
	var mixed := (seed_value * 73856093) ^ (bag * 19349663) ^ 0x5bd1e995
	mixed = (mixed ^ (mixed >> 16)) * 0x45d9f3b
	mixed = (mixed ^ (mixed >> 16)) * 0x45d9f3b
	mixed = mixed ^ (mixed >> 16)
	return float(mixed & 0xFFFF) / 65535.0
