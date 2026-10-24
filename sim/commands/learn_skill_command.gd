class_name LearnSkillCommand
extends SimCommand

var skill_id: String = ""


func _init(chosen_skill_id: String) -> void:
	skill_id = chosen_skill_id
