class_name PlotView
extends Interactable

const GROWTH_START_SCALE: float = 0.75
const DRY_SOIL: Color = Color(0.6, 0.45, 0.3)
const WET_SOIL: Color = Color(0.22, 0.14, 0.09)
const DRY_LABEL: Color = Color(1.0, 0.5, 0.4)
const READY_LABEL: Color = Color(0.7, 1.0, 0.6)

@export var plot_id: int = 0
@export var soil: MeshInstance3D
@export var plant: Node3D
@export var label: Label3D
@export var splash: CPUParticles3D
@export var stage_models: Array[PackedScene] = []
@export var plants_per_bed: int = 3
@export var plant_spacing: float = 0.65
@export var plant_scale: float = 0.8

var _soil_material: StandardMaterial3D
var _stage_holders: Array[Node3D] = []
var _last_water: float = 0.0


func _ready() -> void:
	_soil_material = StandardMaterial3D.new()
	_soil_material.roughness = 1.0
	soil.material_override = _soil_material
	for stage_model: PackedScene in stage_models:
		var holder := Node3D.new()
		holder.visible = false
		for index: int in plants_per_bed:
			var instance := stage_model.instantiate() as Node3D
			instance.position.x = (float(index) - float(plants_per_bed - 1) / 2.0) * plant_spacing
			instance.rotation.y = deg_to_rad(70.0 * float(index + plot_id))
			holder.add_child(instance)
		plant.add_child(holder)
		_stage_holders.append(holder)


func _process(_delta: float) -> void:
	var plot := Game.sim.grow.plot(plot_id)
	if plot == null:
		return
	var strain := Game.sim.grow.strain_of(plot)
	var capacity := strain.water_capacity_hours * SimClock.GAME_SECONDS_PER_HOUR
	_soil_material.albedo_color = DRY_SOIL.lerp(WET_SOIL, clampf(plot.water_seconds / capacity, 0.0, 1.0))
	if plot.water_seconds > _last_water + 1.0:
		splash.restart()
	_last_water = plot.water_seconds
	var visible_holder := int(plot.stage) - 1
	for index: int in _stage_holders.size():
		_stage_holders[index].visible = index == visible_holder
	plant.scale = Vector3.ONE * plant_scale * _growth_scale(plot)
	label.text = _label_text(plot)
	var troubled := _is_dry(plot) or not plot.problem.is_empty()
	label.modulate = DRY_LABEL if troubled else (READY_LABEL if plot.stage == Plot.Stage.READY else Color.WHITE)


func title() -> String:
	return "Грядка %d" % UiText.plot_number(plot_id)


func hover_text() -> String:
	var plot := Game.sim.grow.plot(plot_id)
	match plot.stage:
		Plot.Stage.EMPTY:
			return "%s — посадить" % title()
		Plot.Stage.READY:
			return "%s — собрать урожай" % title()
	if not plot.problem.is_empty():
		return "%s — %s, вылечить" % [title(), UiText.problem(plot.problem)]
	return "%s — уход" % title()


func interact(level: Level) -> void:
	level.hud.show_actions(title(), actions(level))


func actions(level: Level) -> Array[UiAction]:
	var sim := Game.sim
	var plot := sim.grow.plot(plot_id)
	var result: Array[UiAction] = []
	match plot.stage:
		Plot.Stage.EMPTY:
			for strain: StrainDef in sim.config.strains():
				if not sim.progress.is_strain_unlocked(strain.id):
					continue
				var seeds_text := "бесплатно" if not strain.needs_seeds() else "семян: %d" % sim.supplies.seeds(strain.id)
				var can_plant := not strain.needs_seeds() or sim.supplies.seeds(strain.id) > 0
				result.append(UiAction.make("Посадить «%s» (%s)" % [strain.display_name, seeds_text], _plant.bind(level, strain.id), can_plant))
		Plot.Stage.READY:
			result.append(UiAction.make("Собрать урожай", _harvest.bind(level)))
		_:
			if not plot.problem.is_empty():
				var item := Problems.cure_item(plot.problem)
				var have := sim.supplies.count(item) if not item.is_empty() else 1
				var stock := "" if item.is_empty() else " (есть: %d)" % have
				result.append(UiAction.make(UiText.cure(plot.problem) + stock, _run.bind(level, TreatCommand.new(plot_id), "%s снова в порядке." % title()), have > 0))
			result.append(UiAction.make("Полить", _run.bind(level, WaterCommand.new(plot_id), "%s полита." % title())))
			if not plot.fertilized:
				result.append(UiAction.make("Удобрить (+%d к качеству, есть: %d)" % [sim.config.fertilizer_bonus, sim.supplies.fertilizer], _run.bind(level, FertilizeCommand.new(plot_id), "Удобрено."), sim.supplies.fertilizer > 0))
			if plot.stage == Plot.Stage.BUSH and not plot.pruned:
				result.append(UiAction.make("Обрезать листья (+%d к качеству)" % sim.config.prune_bonus, _run.bind(level, PruneCommand.new(plot_id), "Лишние листья срезаны.")))
	return result


func _plant(level: Level, strain_id: String) -> void:
	_run(level, PlantCommand.new(plot_id, strain_id), "%s засажена. Теперь полей её." % title())


func _harvest(level: Level) -> void:
	var result := Game.sim.apply(HarvestCommand.new(plot_id))
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	var quality := Game.sim.inventory.find(result.value).quality
	level.show_message("Собран урожай, качество %d. Заказы — в телефоне (Tab)." % quality)


func _run(level: Level, command: SimCommand, success_text: String) -> void:
	var result := Game.sim.apply(command)
	level.show_message(success_text if result.ok else UiText.error(result.error))


func _growth_scale(plot: Plot) -> float:
	if not plot.is_growing():
		return 1.0
	var duration := Game.sim.grow.stage_duration(plot)
	var progress := clampf(plot.progress_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	return lerpf(GROWTH_START_SCALE, 1.0, progress)


func _is_dry(plot: Plot) -> bool:
	return plot.is_growing() and plot.water_seconds <= 0.0


func _time_to_harvest(plot: Plot) -> float:
	var strain := Game.sim.grow.strain_of(plot)
	var remaining := Game.sim.grow.stage_duration(plot) - plot.progress_seconds
	if plot.stage == Plot.Stage.SEED:
		remaining += (strain.sprout_hours + strain.bush_hours) * SimClock.GAME_SECONDS_PER_HOUR
	elif plot.stage == Plot.Stage.SPROUT:
		remaining += strain.bush_hours * SimClock.GAME_SECONDS_PER_HOUR
	return remaining


func _label_text(plot: Plot) -> String:
	var lines := PackedStringArray([title()])
	if plot.stage == Plot.Stage.EMPTY:
		lines.append("пусто")
		return "\n".join(lines)
	var strain := Game.sim.grow.strain_of(plot)
	lines.append("%s · %s" % [strain.display_name, UiText.stage(plot.stage)])
	if not plot.problem.is_empty():
		lines.append("%s — рост стоит!" % UiText.capitalized(UiText.problem(plot.problem)))
	elif plot.is_growing():
		var capacity := strain.water_capacity_hours * SimClock.GAME_SECONDS_PER_HOUR
		var water_percent := roundi(clampf(plot.water_seconds / capacity, 0.0, 1.0) * 100.0)
		if _is_dry(plot):
			lines.append("СУХО — рост стоит!")
		else:
			lines.append("до сбора %s · вода %d%%" % [UiText.real_duration(_time_to_harvest(plot), Game.sim), water_percent])
		var care := PackedStringArray()
		if plot.fertilized:
			care.append("удобрено")
		if plot.pruned:
			care.append("обрезано")
		if not care.is_empty():
			lines.append(", ".join(care))
	return "\n".join(lines)
