class_name FlashbackCamera
extends Camera3D
## The flashback's own view: the same high angle as Jack's camera, gliding after whoever the scene follows.

const DISTANCE: float = 26.0
const PITCH_DEGREES: float = 45.0
const YAW_DEGREES: float = 45.0
const SMOOTHING: float = 5.0

@export var target: Node3D


func snap() -> void:
	_place(1.0)


func _process(delta: float) -> void:
	_place(1.0 - exp(-SMOOTHING * delta))


func _place(weight: float) -> void:
	if target == null:
		return
	var pitch := deg_to_rad(PITCH_DEGREES)
	var yaw := deg_to_rad(YAW_DEGREES)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * DISTANCE
	position = position.lerp(target.position + offset, clampf(weight, 0.0, 1.0))
	rotation = Vector3(-pitch, yaw, 0.0)
