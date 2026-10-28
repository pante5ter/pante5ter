class_name StoryDef
extends Resource

const VILLAGE: String = "village"
const LORD: String = "lord"
const SCRIPT: String = "script"
const ANYWHERE: String = "anywhere"
const MANOR: String = "manor"
## Rings Jack's phone; the talk starts when he answers, not by walking up.
const CALL: String = "call"

@export var id: String = ""
## The director brings "lord" stories as the lord's visit and "village" ones as local trouble;
## "script" stories only come from the first-day script.
@export_enum("village", "lord", "script") var kind: String = VILLAGE
## "manor": the lord sends for Jack and the talk happens when Jack walks up to him.
## "call": a ringing phone first; answering plays the story.
@export_enum("anywhere", "manor", "call") var place: String = ANYWHERE
## A summons left unanswered this many game hours expires.
@export var wait_hours: float = 6.0
## Lord relation change when Jack never turns up.
@export var ignored_relation: int = -1
## The director brings it only after all of these stories have been told...
@export var after_stories: PackedStringArray = PackedStringArray()
## ...and once suspicion has climbed this high.
@export var min_suspicion: float = 0.0
@export var lines: Array[DialogueLineDef] = []
@export var choices: Array[StoryChoiceDef] = []


func choice_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for choice: StoryChoiceDef in choices:
		labels.append(choice.label)
	return labels
