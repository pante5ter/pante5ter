class_name ChooseCommand
extends SimCommand

var story_id: String = ""
var choice: int = 0


func _init(target_story_id: String, choice_index: int) -> void:
	story_id = target_story_id
	choice = choice_index
