class_name CourierView
extends Node3D
## One hired courier, by slot in name order. Couriers must not know where the farm is: idle ones wait
## at the drop point, a lay-by at the village end of the road, and leave from there with the boxes.

const IDLE_STEP: Vector3 = Vector3(-1.2, 0.0, 0.0)

@export var slot: int = 0
@export var depot_point: Marker3D
@export var route: RoadRoute
@export var model: CharacterModel
@export var name_label: Label3D


func _process(_delta: float) -> void:
	var sim := Game.sim
	var couriers: Array[String] = []
	for courier_id: String in sim.couriers.hired:
		if courier_id != Couriers.JACK:
			couriers.append(courier_id)
	couriers.sort()
	visible = slot < couriers.size()
	if not visible:
		return
	var courier_id := couriers[slot]
	var now := sim.clock.elapsed_game_seconds
	var courier_name := "Курьер " + UiText.courier_name(courier_id, sim)
	if sim.couriers.is_free(courier_id, now):
		global_position = depot_point.global_position + IDLE_STEP * float(slot)
		rotation.y = depot_point.global_rotation.y
		name_label.text = courier_name + " · ждёт товар у дороги"
		model.play_idle()
		return
	var trip := sim.couriers.trip_seconds(courier_id)
	var left_at := sim.couriers.busy_until[courier_id] - trip * 1.5
	var elapsed := now - left_at
	var outbound := elapsed < trip
	var progress := clampf(elapsed / trip if outbound else 1.0 - (elapsed - trip) / (trip * 0.5), 0.0, 1.0)
	global_position = route.sample(progress)
	var heading := route.heading(progress) * (1.0 if outbound else -1.0)
	if heading.length() > 0.0:
		rotation.y = atan2(heading.x, heading.z)
	name_label.text = courier_name + (" везёт заказ" if outbound else " возвращается")
	model.play_walk()
