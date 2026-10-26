class_name CourierView
extends Interactable
## One hired courier, by slot in name order. Couriers must not know where the farm is: idle ones wait
## at the lay-by where the field path meets the road — close enough to see from the wheat, never at
## the container door — and leave from there with the boxes.

const IDLE_STEP: Vector3 = Vector3(-1.6, 0.0, 0.0)
const HIT_RADIUS: float = 0.55
const HIT_HEIGHT: float = 1.8
## Same click layer as the parcel box and the Land Rover: outside the navmesh bake.
const LAYER: int = 4

@export var slot: int = 0
@export var depot_point: Marker3D
@export var route: RoadRoute
@export var model: CharacterModel
@export var name_label: Label3D

var _courier_id: String = ""


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	if get_node_or_null("Hit") == null:
		var hit := CollisionShape3D.new()
		hit.name = "Hit"
		var capsule := CapsuleShape3D.new()
		capsule.radius = HIT_RADIUS
		capsule.height = HIT_HEIGHT
		hit.shape = capsule
		hit.position = Vector3(0.0, HIT_HEIGHT * 0.5, 0.0)
		add_child(hit)


func _process(_delta: float) -> void:
	var sim := Game.sim
	var couriers: Array[String] = []
	for courier_id: String in sim.couriers.hired:
		if courier_id != Couriers.JACK:
			couriers.append(courier_id)
	couriers.sort()
	visible = slot < couriers.size()
	collision_layer = LAYER if visible else 0
	if not visible:
		_courier_id = ""
		return
	_courier_id = couriers[slot]
	var now := sim.clock.elapsed_game_seconds
	var courier_name := UiText.courier_name(_courier_id, sim)
	if sim.couriers.is_free(_courier_id, now):
		global_position = depot_point.global_position + IDLE_STEP * float(slot)
		rotation.y = depot_point.global_rotation.y
		name_label.text = "%s · ждёт у дороги у поля" % courier_name
		model.play_idle()
		return
	var trip := sim.couriers.trip_seconds(_courier_id)
	var left_at := sim.couriers.busy_until[_courier_id] - trip * 1.5
	var elapsed := now - left_at
	var outbound := elapsed < trip
	var progress := clampf(elapsed / trip if outbound else 1.0 - (elapsed - trip) / (trip * 0.5), 0.0, 1.0)
	global_position = route.sample(progress)
	var heading := route.heading(progress) * (1.0 if outbound else -1.0)
	if heading.length() > 0.0:
		rotation.y = atan2(heading.x, heading.z)
	name_label.text = courier_name + (" · везёт заказ" if outbound else " · возвращается")
	model.play_walk()


func hover_text() -> String:
	if _courier_id.is_empty():
		return ""
	var sim := Game.sim
	var courier_name := UiText.courier_name(_courier_id, sim)
	if sim.couriers.is_free(_courier_id, sim.clock.elapsed_game_seconds):
		return "%s — поговорить" % courier_name
	return "%s — в дороге" % courier_name


func interact(level: Level) -> void:
	if _courier_id.is_empty():
		return
	var sim := Game.sim
	var courier_name := UiText.courier_name(_courier_id, sim)
	if not sim.couriers.is_free(_courier_id, sim.clock.elapsed_game_seconds):
		level.show_message("%s уже уехал с заказом. Дождитесь возвращения у дороги у поля." % courier_name)
		return
	level.hud.play_dialogue(_chat_lines(courier_name))


func _chat_lines(courier_name: String) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(UiText.REGGIE, "Вот %s. Стоит у дороги у поля — до контейнера ему незачем, и лучше так." % courier_name),
	]
	match _courier_id:
		"harry":
			lines.append(DialogueLineDef.make(courier_name, "Машина тёплая, маршрут знаю. Давайте коробки — и тридцать минут, как в Оксфорде."))
		"frank":
			lines.append(DialogueLineDef.make(courier_name, "Не гоню. Зато доеду. Королевская почта меня так научила."))
		"pete":
			lines.append(DialogueLineDef.make(courier_name, "Я местный. Если что — в пабе найдёте. Посылку тоже, иногда."))
		_:
			lines.append(DialogueLineDef.make(courier_name, "Жду товар. У дороги удобнее, чем у вас на поле."))
	return lines
