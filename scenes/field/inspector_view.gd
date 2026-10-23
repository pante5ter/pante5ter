class_name InspectorView
extends Node3D

@export var road_point: Marker3D
@export var target_point: Marker3D
@export var model: CharacterModel


func _process(_delta: float) -> void:
	var suspicion := Game.sim.suspicion
	visible = suspicion.inspection_pending()
	if not visible:
		return
	var warning := Game.sim.config.suspicion.warning_hours * SimClock.GAME_SECONDS_PER_HOUR
	var left := suspicion.inspection_at - Game.sim.clock.elapsed_game_seconds
	var progress := clampf(1.0 - left / warning, 0.0, 1.0)
	var from := road_point.global_position
	var to := target_point.global_position
	global_position = from.lerp(to, progress)
	var heading := to - from
	rotation.y = atan2(heading.x, heading.z)
	if progress >= 1.0:
		model.play_idle()
	else:
		model.play_walk()
