class_name Grow
extends RefCounted

var _strain: StrainDef
var _rng: SimRng
var _event_log: EventLog
var _inventory: Inventory
var _plots: Array[Plot] = []


func _init(strain: StrainDef, plot_count: int, rng: SimRng, event_log: EventLog, inventory: Inventory) -> void:
	_strain = strain
	_rng = rng
	_event_log = event_log
	_inventory = inventory
	for plot_id: int in plot_count:
		_plots.append(Plot.new(plot_id))


func plot(plot_id: int) -> Plot:
	if plot_id < 0 or plot_id >= _plots.size():
		return null
	return _plots[plot_id]


func plots() -> Array[Plot]:
	return _plots.duplicate()


func plant(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if target.stage != Plot.Stage.EMPTY:
		return CommandResult.failure(CommandResult.PLOT_OCCUPIED)
	target.reset()
	target.stage = Plot.Stage.SEED
	_event_log.record(EventLog.PLOT_PLANTED, now, _actors(actor, target), {"plot_id": plot_id, "strain_id": _strain.id})
	return CommandResult.success()


func water(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if not target.is_growing():
		return CommandResult.failure(CommandResult.PLOT_NOT_GROWING)
	target.water_seconds = _hours(_strain.water_capacity_hours)
	_event_log.record(EventLog.PLOT_WATERED, now, _actors(actor, target), {"plot_id": plot_id})
	return CommandResult.success()


func harvest(plot_id: int, now: float, actor: String) -> CommandResult:
	var target := plot(plot_id)
	if target == null:
		return CommandResult.failure(CommandResult.INVALID_PLOT)
	if target.stage != Plot.Stage.READY:
		return CommandResult.failure(CommandResult.PLOT_NOT_READY)
	var product := _inventory.create(_strain.id, _roll_quality(target))
	_event_log.record(EventLog.PLOT_HARVESTED, now, _actors(actor, target), {
		"plot_id": plot_id,
		"product_id": product.id,
		"quality": product.quality,
	})
	target.reset()
	return CommandResult.success(product.id)


func advance(start_time: float, game_seconds: float) -> void:
	for target: Plot in _plots:
		_advance_plot(target, start_time, game_seconds)


func _advance_plot(target: Plot, start_time: float, game_seconds: float) -> void:
	var remaining := game_seconds
	var now := start_time
	while remaining > 0.0 and target.is_growing():
		if target.water_seconds <= 0.0:
			target.dry_seconds += remaining
			return
		var to_next_stage := _stage_duration(target.stage) - target.progress_seconds
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


func _stage_duration(stage: Plot.Stage) -> float:
	match stage:
		Plot.Stage.SEED:
			return _hours(_strain.seed_hours)
		Plot.Stage.SPROUT:
			return _hours(_strain.sprout_hours)
		Plot.Stage.BUSH:
			return _hours(_strain.bush_hours)
	return 0.0


func _roll_quality(target: Plot) -> int:
	var dry_hours := target.dry_seconds / SimClock.GAME_SECONDS_PER_HOUR
	var spread := _rng.randi_range(-_strain.quality_variance, _strain.quality_variance)
	var raw := float(_strain.base_quality) - dry_hours * _strain.dry_penalty_per_hour + float(spread)
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
