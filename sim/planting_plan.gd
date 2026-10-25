class_name PlantingPlan
extends RefCounted

## What goes into an empty bed when nobody names a strain: the player's bed counts first,
## then the best seeds in stock, and the free house seeds when nothing else is left.

## No count for the strain: it is planted by the best-seeds rule.
const AUTO: int = -1

## strain id -> beds wanted; a planned strain is not planted beyond its count.
var _beds: Dictionary[String, int] = {}
var _config: BalanceConfig
var _grow: Grow
var _supplies: Supplies
var _progress: Progress
var _event_log: EventLog


func _init(config: BalanceConfig, grow: Grow, supplies: Supplies, progress: Progress, event_log: EventLog) -> void:
	_config = config
	_grow = grow
	_supplies = supplies
	_progress = progress
	_event_log = event_log


func beds_for(strain_id: String) -> int:
	return _beds.get(strain_id, AUTO)


func is_empty() -> bool:
	return _beds.is_empty()


func set_beds(strain_id: String, beds: int, now: float, actor: String) -> CommandResult:
	var strain := _config.find_strain(strain_id) if not strain_id.is_empty() else null
	if strain == null:
		return CommandResult.failure(CommandResult.UNKNOWN_STRAIN)
	if beds < AUTO or beds > _config.max_plots:
		return CommandResult.failure(CommandResult.INVALID_QUANTITY)
	if beds > 0 and not _progress.is_strain_unlocked(strain_id):
		return CommandResult.failure(CommandResult.STRAIN_LOCKED)
	if beds == AUTO:
		_beds.erase(strain_id)
	else:
		_beds[strain_id] = beds
	_event_log.record(EventLog.PLANTING_PLAN_SET, now, PackedStringArray([actor]), {"strain_id": strain_id, "beds": beds})
	return CommandResult.success()


## Unlocked strains, the dearest first.
func best_first() -> Array[StrainDef]:
	var found: Array[StrainDef] = []
	for strain: StrainDef in _config.strains():
		if _progress.is_strain_unlocked(strain.id):
			found.append(strain)
	found.sort_custom(func(a: StrainDef, b: StrainDef) -> bool: return a.base_price > b.base_price)
	return found


func can_plant(strain: StrainDef) -> bool:
	return _progress.is_strain_unlocked(strain.id) and (not strain.needs_seeds() or _supplies.seeds(strain.id) > 0)


## The strain for the next empty bed; never empty while the house strain is free.
func choose() -> String:
	var planted := _planted_counts()
	var ranked := best_first()
	for strain: StrainDef in ranked:
		if beds_for(strain.id) > int(planted.get(strain.id, 0)) and can_plant(strain):
			return strain.id
	for strain: StrainDef in ranked:
		if beds_for(strain.id) == AUTO and can_plant(strain):
			return strain.id
	return _config.strain.id


func _planted_counts() -> Dictionary:
	var counts := {}
	for target: Plot in _grow.plots():
		if target.stage != Plot.Stage.EMPTY:
			counts[target.strain_id] = int(counts.get(target.strain_id, 0)) + 1
	return counts


func to_dict() -> Dictionary:
	return _beds.duplicate()


func load_dict(data: Dictionary) -> void:
	_beds.clear()
	for strain_id: Variant in data:
		_beds[String(strain_id)] = int(data[strain_id])
