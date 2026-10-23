class_name PlotView
extends Interactable

const GROWTH_START_SCALE: float = 0.75
const DRY_SOIL: Color = Color(0.6, 0.45, 0.3)
const WET_SOIL: Color = Color(0.22, 0.14, 0.09)
const DRY_LABEL: Color = Color(1.0, 0.5, 0.4)

@export var plot_id: int = 0
@export var soil: MeshInstance3D
@export var plant: Node3D
@export var label: Label3D
@export var stage_models: Array[PackedScene] = []
@export var plants_per_bed: int = 3
@export var plant_spacing: float = 0.65
@export var plant_scale: float = 0.8

var _soil_material: StandardMaterial3D
var _stage_holders: Array[Node3D] = []


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
	var strain := Game.sim.config.strain
	var capacity := strain.water_capacity_hours * SimClock.GAME_SECONDS_PER_HOUR
	_soil_material.albedo_color = DRY_SOIL.lerp(WET_SOIL, clampf(plot.water_seconds / capacity, 0.0, 1.0))
	var visible_holder := int(plot.stage) - 1
	for index: int in _stage_holders.size():
		_stage_holders[index].visible = index == visible_holder
	plant.scale = Vector3.ONE * plant_scale * _growth_scale(plot, strain)
	label.text = _label_text(plot)
	label.modulate = DRY_LABEL if _is_dry(plot) else Color.WHITE


func hover_text() -> String:
	var plot := Game.sim.grow.plot(plot_id)
	var title := "Грядка %d" % UiText.plot_number(plot_id)
	match plot.stage:
		Plot.Stage.EMPTY:
			return "%s — посадить" % title
		Plot.Stage.READY:
			return "%s — собрать урожай" % title
	return "%s — полить" % title


func interact(level: Level) -> void:
	var plot := Game.sim.grow.plot(plot_id)
	var title := "Грядка %d" % UiText.plot_number(plot_id)
	match plot.stage:
		Plot.Stage.EMPTY:
			_report(level, Game.sim.apply(PlantCommand.new(plot_id)), "%s засажена. Теперь полей её." % title)
		Plot.Stage.READY:
			var result := Game.sim.apply(HarvestCommand.new(plot_id))
			var quality := 0
			if result.ok:
				quality = Game.sim.inventory.find(result.value).quality
			_report(level, result, "Собран урожай, качество %d. Отнеси покупателю наверху." % quality)
		_:
			_report(level, Game.sim.apply(WaterCommand.new(plot_id)), "%s полита." % title)


func _report(level: Level, result: CommandResult, success_text: String) -> void:
	level.show_message(success_text if result.ok else UiText.error(result.error))


func _growth_scale(plot: Plot, strain: StrainDef) -> float:
	if not plot.is_growing():
		return 1.0
	var duration := _stage_hours(plot.stage, strain) * SimClock.GAME_SECONDS_PER_HOUR
	var progress := clampf(plot.progress_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	return lerpf(GROWTH_START_SCALE, 1.0, progress)


func _stage_hours(stage: Plot.Stage, strain: StrainDef) -> float:
	match stage:
		Plot.Stage.SEED:
			return strain.seed_hours
		Plot.Stage.SPROUT:
			return strain.sprout_hours
		Plot.Stage.BUSH:
			return strain.bush_hours
	return 0.0


func _is_dry(plot: Plot) -> bool:
	return plot.is_growing() and plot.water_seconds <= 0.0


func _label_text(plot: Plot) -> String:
	var lines := PackedStringArray(["Грядка %d" % UiText.plot_number(plot_id), UiText.capitalized(UiText.stage(plot.stage))])
	if _is_dry(plot):
		lines.append("СУХО — полей!")
	elif plot.is_growing():
		lines.append("вода: %d ч" % ceili(plot.water_seconds / SimClock.GAME_SECONDS_PER_HOUR))
	return "\n".join(lines)
