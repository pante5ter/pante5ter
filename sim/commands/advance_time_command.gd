class_name AdvanceTimeCommand
extends SimCommand

var real_seconds: float = 0.0


func _init(elapsed_real_seconds: float) -> void:
	real_seconds = elapsed_real_seconds
