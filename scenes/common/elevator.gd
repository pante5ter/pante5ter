class_name Elevator
extends Interactable

const OPEN_SECONDS: float = 0.6

@export var door: Node3D
@export var door_open_offset: Vector3 = Vector3(1.9, 0.0, 0.0)
## Parts inside an imported model, looked up by name because instanced scenes hide their children.
@export var model: Node3D
@export var model_door_name: String = ""
@export var swing_door_names: PackedStringArray = PackedStringArray()
@export var swing_degrees: float = 100.0
@export var hide_when_open_names: PackedStringArray = PackedStringArray()
@export_file("*.tscn") var destination: String = ""
@export var destination_spawn: String = "from_elevator"

var _opening: bool = false


func interact(_level: Level) -> void:
	ride()


func ride() -> void:
	if _opening or SceneRouter.is_busy():
		return
	_opening = true
	await _swing_doors()
	if door == null and model != null and not model_door_name.is_empty():
		door = model.find_child(model_door_name, true, false) as Node3D
	if door != null:
		var tween := create_tween()
		tween.tween_property(door, "position", door.position + door_open_offset, OPEN_SECONDS).set_trans(Tween.TRANS_SINE)
		await tween.finished
	SceneRouter.go_to(destination, destination_spawn)



func _swing_doors() -> void:
	if model == null or swing_door_names.is_empty():
		return
	for part_name: String in hide_when_open_names:
		var part := model.find_child(part_name, true, false) as Node3D
		if part != null:
			part.visible = false
	var swings: Array[Node3D] = []
	for door_name: String in swing_door_names:
		var swing := model.find_child(door_name, true, false) as Node3D
		if swing != null:
			swings.append(swing)
	if swings.is_empty():
		return
	var tween := create_tween().set_parallel(true)
	for index: int in swings.size():
		var side := 1.0 if index % 2 == 0 else -1.0
		tween.tween_property(swings[index], "rotation:y", swings[index].rotation.y + deg_to_rad(swing_degrees) * side, OPEN_SECONDS).set_trans(Tween.TRANS_SINE)
	await tween.finished
