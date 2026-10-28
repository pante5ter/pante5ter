class_name AnswerCallCommand
extends SimCommand

## Jack picks up the phone to whoever rang about the pending story.
var story_id: String = ""


func _init(ringing_story_id: String) -> void:
	story_id = ringing_story_id
