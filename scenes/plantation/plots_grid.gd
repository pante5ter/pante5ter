class_name PlotsGrid
extends Node3D

@export var plot_scene: PackedScene
@export var columns: int = 3
@export var spacing: Vector2 = Vector2(3.4, 3.4)

var _views: Array[PlotView] = []


func _ready() -> void:
	_sync_beds()


func _process(_delta: float) -> void:
	if Game.sim.grow.plots().size() != _views.size():
		_sync_beds()
		var level := owner as Level
		if level != null:
			level.rebake_navigation()


func _sync_beds() -> void:
	var count := Game.sim.grow.plots().size()
	while _views.size() > count:
		var removed: PlotView = _views.pop_back()
		removed.queue_free()
	while _views.size() < count:
		var view := plot_scene.instantiate() as PlotView
		view.plot_id = _views.size()
		view.position = slot_position(view.plot_id, maxi(Game.sim.config.max_plots, count))
		add_child(view)
		_views.append(view)


## Every bed has a fixed slot in a grid sized for the most beds the farm can hold, so buying one
## never moves the others. Rows fill from the middle of the room outwards.
func slot_position(plot_id: int, capacity: int) -> Vector3:
	var rows := ceili(float(capacity) / float(columns))
	var row_order: Array[int] = []
	for row: int in rows:
		row_order.append(row)
	var middle := float(rows - 1) / 2.0
	row_order.sort_custom(func(a: int, b: int) -> bool:
		var a_off := absf(float(a) - middle)
		var b_off := absf(float(b) - middle)
		return a_off < b_off or (is_equal_approx(a_off, b_off) and a < b))
	var column := plot_id % columns
	var row := row_order[mini(floori(float(plot_id) / float(columns)), rows - 1)]
	return Vector3(
		(float(column) - float(columns - 1) / 2.0) * spacing.x,
		0.0,
		(float(row) - middle) * spacing.y)


func view_for(plot_id: int) -> PlotView:
	if plot_id < 0 or plot_id >= _views.size():
		return null
	return _views[plot_id]


func views() -> Array[PlotView]:
	return _views.duplicate()
