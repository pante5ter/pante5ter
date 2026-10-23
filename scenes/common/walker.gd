class_name Walker
extends Node3D

@export var speed: float = 3.5
@export var agent: NavigationAgent3D
@export var model: CharacterModel

var _on_arrive: Callable = Callable()
var _moving: bool = false


func move_to(target: Vector3, on_arrive: Callable = Callable()) -> void:
	agent.target_position = target
	_on_arrive = on_arrive
	_moving = true


func stop() -> void:
	_moving = false
	_on_arrive = Callable()
	_play_idle()


func is_moving() -> bool:
	return _moving


func _physics_process(delta: float) -> void:
	if not _moving:
		return
	if agent.is_navigation_finished():
		_arrive()
		return
	var next := agent.get_next_path_position()
	var offset := next - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length() > 0.01:
		rotation.y = atan2(flat.x, flat.z)
	if model != null:
		model.play_walk()
	global_position = global_position.move_toward(next, speed * delta)


func _arrive() -> void:
	_moving = false
	_play_idle()
	var callback := _on_arrive
	_on_arrive = Callable()
	if callback.is_valid():
		callback.call()


func _play_idle() -> void:
	if model != null:
		model.play_idle()
