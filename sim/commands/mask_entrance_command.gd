class_name MaskEntranceCommand
extends SimCommand

var masked: bool = true


func _init(should_mask: bool) -> void:
	masked = should_mask
