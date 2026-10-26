class_name PackByHandCommand
extends SimCommand

## Grams each bag ended off the target on the scale, signed: over is positive.
var misses: Array[float] = []


func _init(bag_misses: Array[float] = []) -> void:
	misses = bag_misses.duplicate()
