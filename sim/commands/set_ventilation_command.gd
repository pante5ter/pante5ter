class_name SetVentilationCommand
extends SimCommand

var level: int = 0


func _init(ventilation_level: int) -> void:
	level = ventilation_level
