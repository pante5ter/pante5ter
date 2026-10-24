class_name InspectorView
extends Node3D
## The council inspector walks in along the road while an inspection is pending.

@export var route: RoadRoute
@export var model: CharacterModel


func _process(_delta: float) -> void:
	var suspicion := Game.sim.suspicion
	visible = suspicion.inspection_pending()
	if not visible:
		return
	var warning := Game.sim.config.suspicion.warning_hours * SimClock.GAME_SECONDS_PER_HOUR
	var left := suspicion.inspection_at - Game.sim.clock.elapsed_game_seconds
	var progress := clampf(1.0 - left / warning, 0.0, 1.0)
	global_position = route.sample(progress)
	var heading := route.heading(progress)
	if heading.length() > 0.0:
		rotation.y = atan2(heading.x, heading.z)
	if progress >= 1.0:
		model.play_idle()
	else:
		model.play_walk()
