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
		add_child(view)
		_views.append(view)
	var rows := ceili(float(count) / float(columns))
	for view: PlotView in _views:
		var column := view.plot_id % columns
		var row := floori(float(view.plot_id) / float(columns))
		view.position = Vector3(
			(float(column) - float(columns - 1) / 2.0) * spacing.x,
			0.0,
			(float(row) - float(rows - 1) / 2.0) * spacing.y)


func view_for(plot_id: int) -> PlotView:
	if plot_id < 0 or plot_id >= _views.size():
		return null
	return _views[plot_id]


func views() -> Array[PlotView]:
	return _views.duplicate()
