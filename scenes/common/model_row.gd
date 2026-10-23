class_name ModelRow
extends Node3D

const YAW_STEP_DEGREES: float = 47.0

@export var model: PackedScene
@export var count: int = 1
@export var spacing: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var model_scale: float = 1.0
@export var vary_yaw: bool = true
@export var yaw_degrees: float = 0.0


func _ready() -> void:
	var start := -spacing * float(count - 1) / 2.0
	for index: int in count:
		var instance := model.instantiate() as Node3D
		instance.position = start + spacing * float(index)
		instance.scale = Vector3.ONE * model_scale
		instance.rotation.y = deg_to_rad(yaw_degrees + (YAW_STEP_DEGREES * float(index) if vary_yaw else 0.0))
		add_child(instance)
