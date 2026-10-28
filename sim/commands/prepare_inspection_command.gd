class_name PrepareInspectionCommand
extends SimCommand

## Jack's answer to the call about an inspection: one of Suspicion.PREPS.
var choice: String = ""


func _init(answer: String) -> void:
	choice = answer
