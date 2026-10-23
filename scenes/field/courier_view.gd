class_name CourierView
extends Node3D

@export var slot: int = 0
@export var depot_point: Marker3D
@export var road_point: Marker3D
@export var model: CharacterModel
@export var name_label: Label3D


func _process(_delta: float) -> void:
	var sim := Game.sim
	var now := sim.clock.elapsed_game_seconds
	var trips: Array[String] = []
	for courier_id: String in sim.couriers.busy_until:
		if courier_id != Couriers.JACK and sim.couriers.busy_until[courier_id] > now:
			trips.append(courier_id)
	trips.sort()
	visible = slot < trips.size()
	if not visible:
		return
	var courier_id := trips[slot]
	var trip := sim.couriers.trip_seconds(courier_id)
	var left_at := sim.couriers.busy_until[courier_id] - trip * 1.5
	var elapsed := now - left_at
	var outbound := elapsed < trip
	var progress := clampf(elapsed / trip if outbound else 1.0 - (elapsed - trip) / (trip * 0.5), 0.0, 1.0)
	var from := depot_point.global_position
	var to := road_point.global_position
	global_position = from.lerp(to, progress)
	var heading := (to - from) if outbound else (from - to)
	rotation.y = atan2(heading.x, heading.z)
	name_label.text = UiText.courier_name(courier_id, sim) + (" везёт заказ" if outbound else " возвращается")
	model.play_walk()
