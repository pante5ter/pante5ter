class_name Grow
extends RefCounted

var _strain: StrainDef
var _rng: SimRng
var _event_log: EventLog
var _inventory: Inventory
var _plots: Array[Plot] = []
var _config: BalanceConfig = null
var _supplies: Supplies = null
var _progress: Progress = null


func _init(strain: StrainDef, plot_count: int, rng: SimRng, event_log: EventLog, inventory: Inventory) -> void:
	_strain = strain
	_rng = rng
	_event_log = event_log
	_inventory = inventory
	for plot_id: int in plot_count:
		_plots.append(Plot.new(plot_id))


func attach(config: BalanceConfig, supplies: Supplies, progress: Progress = null) -> void:
	_config = config
	_supplies = supplies
	_progress = progress


func strain_of(target: Plot) -> StrainDef:
	if _config != null and not target.strain_id.is_empty():
		var found := _config.find_strain(target.strain_id)
		if found != null:
			return found
	return _strain


func replant_strain(target: Plot) -> String:
	if _config == null or target.last_strain_id.is_empty():
		return ""
	var last := _config.find_strain(target.last_strain_id)
	if last == null or (last.needs_seeds() and _supplies.seeds(last.id) <= 0):
		return ""
	return last.id


func add_plot() -> Plot:
	var added := Plot.new(_plots.size())
	_plots.append(added)
	return added


func plot(plot_id: int) -> Plot:
	if plot_id < 0 or plot_id >= _plots.size():
		return null
	return _plots[plot_id]


func plots() -> Array[Plot]:
	return _plots.duplicate()


func plant(plot_id: int, now: float, actor: String, strain_id: String = "") -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if target.stage != Plot.Stage.EMPTY:
		return CommandResult.failure(CommandResult.PLOT_OCCUPIED)
	var strain := _strain
	if not strain_id.is_empty():
		strain = _config.find_strain(strain_id) if _config != null else null
	if strain == null:
		return CommandResult.failure(CommandResult.UNKNOWN_STRAIN)
	if _progress != null and not _progress.is_strain_unlocked(strain.id):
		return CommandResult.failure(CommandResult.STRAIN_LOCKED)
	if strain.needs_seeds() and (_supplies == null or not _supplies.take_seed(strain.id)):
		return CommandResult.failure(CommandResult.NO_SEEDS)
	target.reset()
	target.stage = Plot.Stage.SEED
	target.strain_id = strain.id
	target.last_strain_id = strain.id
	_event_log.record(EventLog.PLOT_PLANTED, now, _actors(actor, target), {"plot_id": plot_id, "strain_id": strain.id})
	return CommandResult.success()


func fertilize(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if not target.is_growing():
		return CommandResult.failure(CommandResult.PLOT_NOT_GROWING)
	if target.fertilized:
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	if _supplies == null or not _supplies.take_fertilizer():
		return CommandResult.failure(CommandResult.NO_FERTILIZER)
	target.fertilized = true
	_event_log.record(EventLog.PLOT_FERTILIZED, now, _actors(actor, target), {"plot_id": plot_id})
	return CommandResult.success()


func prune(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if target.stage != Plot.Stage.BUSH:
		return CommandResult.failure(CommandResult.PLOT_NOT_BUSH)
	if target.pruned:
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	target.pruned = true
	_event_log.record(EventLog.PLOT_PRUNED, now, _actors(actor, target), {"plot_id": plot_id})
	return CommandResult.success()


func water(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if not target.is_growing():
		return CommandResult.failure(CommandResult.PLOT_NOT_GROWING)
	target.water_seconds = _hours(strain_of(target).water_capacity_hours)
	_event_log.record(EventLog.PLOT_WATERED, now, _actors(actor, target), {"plot_id": plot_id})
	return CommandResult.success()


func harvest(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if target.stage != Plot.Stage.READY:
		return CommandResult.failure(CommandResult.PLOT_NOT_READY)
	var strain := strain_of(target)
	var quality := _roll_quality(target)
	var product_ids: Array[int] = []
	for unit: int in strain.yield_for(target.fertilized, target.pruned):
		product_ids.append(_inventory.create(strain.id, quality).id)
	_event_log.record(EventLog.PLOT_HARVESTED, now, _actors(actor, target), {
		"plot_id": plot_id,
		"product_id": product_ids[0],
		"product_ids": product_ids,
		"quantity": product_ids.size(),
		"quality": quality,
	})
	target.reset()
	return CommandResult.success(product_ids[0])


func advance(start_time: float, game_seconds: float) -> void:
	for target: Plot in _plots:
		_advance_plot(target, start_time, game_seconds)


func _advance_plot(target: Plot, start_time: float, game_seconds: float) -> void:
	var remaining := game_seconds
	var now := start_time
	while remaining > 0.0 and target.is_growing():
		if target.water_seconds <= 0.0 or not target.problem.is_empty():
			target.dry_seconds += remaining
			return
		var to_next_stage := _stage_duration(target) - target.progress_seconds
		var step := minf(remaining, minf(target.water_seconds, to_next_stage))
		var stage_completed := step >= to_next_stage
		var water_exhausted := step >= target.water_seconds
		remaining -= step
		now += step
		target.progress_seconds += step
		target.water_seconds -= step
		if stage_completed:
			_enter_next_stage(target, now)
		if water_exhausted:
			target.water_seconds = 0.0
			if target.is_growing():
				_event_log.record(EventLog.PLOT_DRIED_OUT, now, _actors("", target), {"plot_id": target.id})


func _enter_next_stage(target: Plot, now: float) -> void:
	target.stage = (target.stage + 1) as Plot.Stage
	target.progress_seconds = 0.0
	_event_log.record(EventLog.PLOT_STAGE_CHANGED, now, _actors("", target), {
		"plot_id": target.id,
		"stage": Plot.stage_name(target.stage),
	})


func stage_duration(target: Plot) -> float:
	return _stage_duration(target)


func _stage_duration(target: Plot) -> float:
	var strain := strain_of(target)
	match target.stage:
		Plot.Stage.SEED:
			return _hours(strain.seed_hours)
		Plot.Stage.SPROUT:
			return _hours(strain.sprout_hours)
		Plot.Stage.BUSH:
			return _hours(strain.bush_hours)
	return 0.0


func _roll_quality(target: Plot) -> int:
	var strain := strain_of(target)
	var dry_hours := target.dry_seconds / SimClock.GAME_SECONDS_PER_HOUR
	var spread := _rng.randi_range(-strain.quality_variance, strain.quality_variance)
	var raw := float(strain.base_quality) - dry_hours * strain.dry_penalty_per_hour + float(spread)
	if _config != null:
		raw += float(_config.fertilizer_bonus if target.fertilized else 0) + float(_config.prune_bonus if target.pruned else 0)
	return clampi(roundi(raw), 0, 100)


func _actors(actor: String, target: Plot) -> PackedStringArray:
	var result := PackedStringArray()
	if not actor.is_empty():
		result.append(actor)
	result.append("plot:%d" % target.id)
	return result


static func _hours(value: float) -> float:
	return value * SimClock.GAME_SECONDS_PER_HOUR


func to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target: Plot in _plots:
		result.append(target.to_dict())
	return result


func load_array(source: Array) -> void:
	_plots.clear()
	for item: Variant in source:
		_plots.append(Plot.from_dict(item as Dictionary))
