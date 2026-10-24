class_name StoryDef
extends Resource

const VILLAGE: String = "village"
const LORD: String = "lord"
const SCRIPT: String = "script"

@export var id: String = ""
## The director brings "lord" stories as the lord's visit and "village" ones as local trouble;
## "script" stories only come from the first-day script.
@export_enum("village", "lord", "script") var kind: String = VILLAGE
@export var lines: Array[DialogueLineDef] = []
@export var choices: Array[StoryChoiceDef] = []


func choice_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for choice: StoryChoiceDef in choices:
		labels.append(choice.label)
	return labels
