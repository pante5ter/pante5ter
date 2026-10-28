class_name PrepareInspectionCommand
extends SimCommand

const QUIET: String = "quiet"
const BRIBE: String = "bribe"
const NOTHING: String = "nothing"

var choice: String = NOTHING


func _init(prepare_choice: String = NOTHING) -> void:
	choice = prepare_choice
