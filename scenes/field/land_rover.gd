class_name LandRover
extends Interactable
## Estate car for fast travel. Jack gets in, the car drives the lanes and the main road to another
## parking spot in a few seconds, and Jack steps out there. Scene-only: the sim never hears of it.

const DRIVE_SECONDS: float = 3.0
const GROUP: StringName = &"land_rovers"
## Layer 3 is clickable but stays out of the navmesh bake, so a car leaves no hole where it was parked.
const LAYER: int = 4

@export var parking: Node3D
@export var spot: ParkingSpot
@export var bay: int = 0

var _level: Level = null
var _route: PackedVector3Array = PackedVector3Array()
var _elapsed: float = 0.0
var _destination: ParkingSpot = null
var _destination_bay: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = LAYER
	_park()


func hover_text() -> String:
	return "Лендровер — поехать"


func interact(level: Level) -> void:
	level.hud.show_actions("Лендровер", actions(level))


func actions(level: Level) -> Array[UiAction]:
	var result: Array[UiAction] = []
	for destination: ParkingSpot in destinations():
		result.append(UiAction.make("Ехать: %s" % destination.title, drive_to.bind(level, destination)))
	return result


func destinations() -> Array[ParkingSpot]:
	var result: Array[ParkingSpot] = []
	for child: Node in parking.get_children():
		var other := child as ParkingSpot
		if other != null and other != spot:
			result.append(other)
	return result


func is_driving() -> bool:
	return _level != null


func drive_to(level: Level, destination: ParkingSpot) -> void:
	if is_driving() or SceneRouter.is_busy() or destination == spot:
		return
	_destination = destination
	_destination_bay = _free_bay(destination)
	var way_out := spot.approach_route(bay)
	way_out.reverse()
	var route := PackedVector3Array([global_position])
	route.append_array(way_out)
	route.append_array(destination.approach_route(_destination_bay))
	_route = RoadRoute.without_repeats(route)
	_elapsed = 0.0
	_level = level
	collision_layer = 0
	level.jack.stop()
	level.jack_in_vehicle = true


func _process(delta: float) -> void:
	if not is_driving():
		return
	_elapsed += delta
	var progress := clampf(_elapsed / DRIVE_SECONDS, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	global_position = RoadRoute.point_along(_route, eased)
	var heading := RoadRoute.heading_along(_route, eased)
	if heading.length() > 0.0:
		rotation.y = atan2(heading.x, heading.z)
	_level.camera_rig.focus(global_position)
	if progress >= 1.0:
		_arrive()


func _arrive() -> void:
	var level := _level
	spot = _destination
	bay = _destination_bay
	_destination = null
	_level = null
	_park()
	collision_layer = LAYER
	level.jack.global_position = approach_position()
	level.jack_in_vehicle = false
	level.camera_rig.focus(global_position)
	level.show_message("Приехали: %s." % spot.title)


func _park() -> void:
	global_position = spot.bay_position(bay)
	rotation.y = spot.global_rotation.y


func _free_bay(destination: ParkingSpot) -> int:
	var taken: Array[int] = []
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		var other := node as LandRover
		if other == null or other == self:
			continue
		if other.spot == destination and not other.is_driving():
			taken.append(other.bay)
		if other._destination == destination:
			taken.append(other._destination_bay)
	var free := 0
	while taken.has(free):
		free += 1
	return free
