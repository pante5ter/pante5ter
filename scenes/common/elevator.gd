class_name Elevator
extends Interactable

const OPEN_SECONDS: float = 0.6

@export var door: Node3D
@export var door_open_offset: Vector3 = Vector3(1.9, 0.0, 0.0)
@export_file("*.tscn") var destination: String = ""
@export var destination_spawn: String = "from_elevator"

var _opening: bool = false


func interact(_level: Level) -> void:
	if _opening or SceneRouter.is_busy():
		return
	_opening = true
	if door != null:
		var tween := create_tween()
		tween.tween_property(door, "position", door.position + door_open_offset, OPEN_SECONDS).set_trans(Tween.TRANS_SINE)
		await tween.finished
	SceneRouter.go_to(destination, destination_spawn)
