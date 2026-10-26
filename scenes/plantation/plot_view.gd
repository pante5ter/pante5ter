class_name PlotView
extends Interactable

const GROWTH_START_SCALE: float = 0.75
const DRY_SOIL: Color = Color(0.49, 0.4, 0.314)
const WET_SOIL: Color = Color(0.227, 0.173, 0.133)
const DRY_LABEL: Color = Color(1.0, 0.5, 0.4)
const READY_LABEL: Color = Color(0.7, 1.0, 0.6)
## Out of the mouse's way a bed shows only a faint name; the details come up under the cursor.
const FULL_FONT: int = 34
const COMPACT_FONT: int = 20
const COMPACT_ALPHA: float = 0.4
const TROUBLE_ALPHA: float = 0.75
const BADGE_HEIGHT: float = 2.6
const BADGE_PIXEL: float = 0.009

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
## The pictogram over a bed that needs a hand; it stays up when the label is faint.
var badge: Sprite3D
@onready var _grow_light: OmniLight3D = get_node_or_null("GrowLight") as OmniLight3D


func _ready() -> void:
	_soil_material = StandardMaterial3D.new()
	_soil_material.roughness = 1.0
	soil.material_override = _soil_material
	badge = Sprite3D.new()
	badge.name = "Badge"
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.no_depth_test = true
	badge.render_priority = 1
	badge.pixel_size = BADGE_PIXEL
	badge.position = Vector3(0.0, BADGE_HEIGHT, 0.0)
	badge.visible = false
	add_child(badge)
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
	if _grow_light != null:
		_grow_light.visible = not Game.sim.suspicion.quiet and plot.problem != Problems.LAMP
	var visible_holder := int(plot.stage) - 1
	for index: int in _stage_holders.size():
		_stage_holders[index].visible = index == visible_holder
	plant.scale = Vector3.ONE * plant_scale * _growth_scale(plot)
	label.text = _label_text(plot) if hovered else _compact_text(plot)
	label.font_size = FULL_FONT if hovered else COMPACT_FONT
	var troubled := _is_dry(plot) or not plot.problem.is_empty()
	var tint := DRY_LABEL if troubled else (READY_LABEL if plot.stage == Plot.Stage.READY else Color.WHITE)
	tint.a = 1.0 if hovered else (TROUBLE_ALPHA if not badge_kind(plot).is_empty() else COMPACT_ALPHA)
	label.modulate = tint
	label.outline_modulate.a = tint.a
	var kind := badge_kind(plot)
	badge.visible = not kind.is_empty() and not hovered
	if badge.visible:
		badge.texture = BedBadge.texture(kind)


## Which pictogram the bed wears; a problem outranks dry soil, as on the full label.
func badge_kind(plot: Plot) -> String:
	if not plot.problem.is_empty():
		return BedBadge.PROBLEM
	if _is_dry(plot):
		return BedBadge.DRY
	if plot.stage == Plot.Stage.READY:
		return BedBadge.READY
	return ""


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
			var best := sim.config.find_strain(sim.planting.choose())
			var by_plan := "" if sim.planting.is_empty() else " (по плану)"
			result.append(UiAction.make("Посадить лучшее: «%s»%s" % [best.display_name, by_plan], _plant.bind(level, "")))
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
	level.show_message(harvest_text(Game.sim.event_log.last(), Game.sim))


static func harvest_text(harvested: SimEvent, sim: SimState) -> String:
	if harvested == null or harvested.type != EventLog.PLOT_HARVESTED:
		return "Собрано. Заказы — в телефоне (Tab)."
	var strain_id := String(harvested.data.get("strain_id", ""))
	var strain := sim.config.find_strain(strain_id) if not strain_id.is_empty() else null
	var strain_text := " «%s»" % strain.display_name if strain != null else ""
	return "Собрано %d шт.%s, качество %d. Заказы — в телефоне (Tab)." % [int(harvested.data.get("quantity", 1)), strain_text, int(harvested.data["quality"])]


func _run(level: Level, command: SimCommand, success_text: String) -> void:
	var result := Game.sim.apply(command)
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	var tip := _tip_for(command)
	level.show_message(success_text if tip.is_empty() else "%s\n%s" % [success_text, tip])


func _tip_for(command: SimCommand) -> String:
	var kind := ""
	if command is WaterCommand:
		kind = "water"
	elif command is FertilizeCommand:
		kind = "fertilize"
	elif command is PruneCommand:
		kind = "prune"
	elif command is PlantCommand:
		kind = "plant"
	var tip := Advice.first_tip(Game.sim, kind)
	if not tip.is_empty():
		Advice.mark_tip(Game.sim, kind)
	return tip


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


## The faint label keeps one word for a bed that needs a hand, so it reads without hovering.
func _compact_text(plot: Plot) -> String:
	if not plot.problem.is_empty():
		return "%s · %s" % [title(), UiText.capitalized(UiText.problem(plot.problem))]
	if _is_dry(plot):
		return "%s · СУХО" % title()
	if plot.stage == Plot.Stage.READY:
		return "%s · созрела" % title()
	return title()


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
