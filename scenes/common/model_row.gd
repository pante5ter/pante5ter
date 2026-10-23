class_name ModelRow
extends Node3D

const YAW_STEP_DEGREES: float = 47.0

@export var model: PackedScene
@export var count: int = 1
@export var spacing: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var model_scale: float = 1.0
@export var vary_yaw: bool = true


func _ready() -> void:
	var start := -spacing * float(count - 1) / 2.0
	for index: int in count:
		var instance := model.instantiate() as Node3D
		instance.position = start + spacing * float(index)
		instance.scale = Vector3.ONE * model_scale
		if vary_yaw:
			instance.rotation.y = deg_to_rad(YAW_STEP_DEGREES * float(index))
		add_child(instance)
