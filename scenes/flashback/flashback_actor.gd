class_name FlashbackActor
extends Node3D
## A robber in the raid flashback: walks straight to a point on the open yard, no navigation mesh needed.

const ARRIVE_DISTANCE: float = 0.05

@export var speed: float = 4.0
@export var model: CharacterModel

var _target: Vector3 = Vector3.ZERO
var _on_arrive: Callable = Callable()
var _moving: bool = false


func move_to(target: Vector3, on_arrive: Callable = Callable()) -> void:
	_target = Vector3(target.x, 0.0, target.z)
	_on_arrive = on_arrive
	_moving = true


func stop() -> void:
	_moving = false
	_on_arrive = Callable()
	if model != null:
		model.play_idle()


func is_moving() -> bool:
	return _moving


func face(point: Vector3) -> void:
	var flat := Vector3(point.x - position.x, 0.0, point.z - position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(flat.x, flat.z)


func _process(delta: float) -> void:
	if not _moving:
		return
	face(_target)
	if model != null:
		model.play_walk()
	position = position.move_toward(_target, speed * delta)
	if position.distance_to(_target) > ARRIVE_DISTANCE:
		return
	_moving = false
	if model != null:
		model.play_idle()
	var callback := _on_arrive
	_on_arrive = Callable()
	if callback.is_valid():
		callback.call()
