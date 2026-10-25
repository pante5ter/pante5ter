class_name MeetCommand
extends SimCommand

var character_id: String = ""


func _init(target_character_id: String) -> void:
	character_id = target_character_id
