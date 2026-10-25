class_name FlashbackContainer
extends Node3D
## Jack's container as the gang saw it: the doors swing, then the shelf slides the way only insiders know.

const DOOR_SECONDS: float = 0.5
const DOOR_SWING_DEGREES: float = 100.0
const DOOR_NAMES: PackedStringArray = ["DoorLeft", "DoorRight"]
const DOOR_GLOW_NAME: String = "GapGlow"
## The same slide as Jack's own way down: the robber knows the shelf moves (the clue in Reggie's clip).
const SHELF_OPEN_OFFSET: Vector3 = Vector3(0.0, 0.0, -1.4)

@export var model: Node3D
@export var shelf: Node3D

var is_open: bool = false


## Seconds until the way in is open; zero once it already is.
func open() -> float:
	if is_open:
		return 0.0
	is_open = true
	var glow := model.find_child(DOOR_GLOW_NAME, true, false) as Node3D
	if glow != null:
		glow.visible = false
	var tween := create_tween()
	var doors: Array[Node3D] = []
	for door_name: String in DOOR_NAMES:
		var door := model.find_child(door_name, true, false) as Node3D
		if door != null:
			doors.append(door)
	for index: int in doors.size():
		var side := 1.0 if index % 2 == 0 else -1.0
		var step := tween.parallel() if index > 0 else tween
		step.tween_property(doors[index], "rotation:y", doors[index].rotation.y + deg_to_rad(DOOR_SWING_DEGREES) * side, DOOR_SECONDS)
	tween.tween_property(shelf, "position", shelf.position + SHELF_OPEN_OFFSET, DOOR_SECONDS).set_trans(Tween.TRANS_SINE)
	return DOOR_SECONDS * 2.0
