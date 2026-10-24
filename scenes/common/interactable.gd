class_name Interactable
extends StaticBody3D

@export var approach: Marker3D
@export var hover_label: String = ""

## Set by the level while the mouse rests on this object.
var hovered: bool = false


func approach_position() -> Vector3:
	if approach == null:
		return global_position
	return approach.global_position


func hover_text() -> String:
	return hover_label


func interact(_level: Level) -> void:
	pass
