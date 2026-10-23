class_name PlotView
extends Interactable

const STAGE_SCALES: Array[float] = [0.0, 0.18, 0.4, 0.75, 0.95]
const DRY_SOIL: Color = Color(0.6, 0.45, 0.3)
const WET_SOIL: Color = Color(0.22, 0.14, 0.09)
const DRY_LABEL: Color = Color(1.0, 0.5, 0.4)

@export var plot_id: int = 0
@export var soil: MeshInstance3D
@export var plant: Node3D
@export var buds: Node3D
@export var label: Label3D

var _soil_material: StandardMaterial3D


func _ready() -> void:
	_soil_material = StandardMaterial3D.new()
	_soil_material.roughness = 1.0
	soil.material_override = _soil_material


func _process(_delta: float) -> void:
	var plot := Game.sim.grow.plot(plot_id)
	if plot == null:
		return
	var strain := Game.sim.config.strain
	var capacity := strain.water_capacity_hours * SimClock.GAME_SECONDS_PER_HOUR
	_soil_material.albedo_color = DRY_SOIL.lerp(WET_SOIL, clampf(plot.water_seconds / capacity, 0.0, 1.0))
	plant.visible = plot.stage != Plot.Stage.EMPTY
	plant.scale = Vector3.ONE * maxf(_plant_scale(plot, strain), 0.01)
	buds.visible = plot.stage == Plot.Stage.READY
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


func _plant_scale(plot: Plot, strain: StrainDef) -> float:
	var stage_index := int(plot.stage)
	var from := STAGE_SCALES[stage_index]
	if not plot.is_growing():
		return from
	var duration := _stage_hours(plot.stage, strain) * SimClock.GAME_SECONDS_PER_HOUR
	var progress := clampf(plot.progress_seconds / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	return lerpf(from, STAGE_SCALES[stage_index + 1], progress)


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
