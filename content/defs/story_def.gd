class_name StoryDef
extends Resource

const VILLAGE: String = "village"
const LORD: String = "lord"
const SCRIPT: String = "script"
const ANYWHERE: String = "anywhere"
const MANOR: String = "manor"
const HOME: String = "home"

@export var id: String = ""
## The director brings "lord" stories as the lord's visit and "village" ones as local trouble;
## "script" stories only come from the first-day script.
@export_enum("village", "lord", "script") var kind: String = VILLAGE
## "manor": the lord sends for Jack and the talk happens when Jack walks up to him.
## "home": the visitor comes to Jack's cottage and the talk waits until Jack is there.
@export_enum("anywhere", "manor", "home") var place: String = ANYWHERE
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

@export_group("Phone call")
## Who rings first; empty: no call, the story just happens.
@export var caller: String = ""
## Said when Jack picks up.
@export var call_lines: Array[DialogueLineDef] = []
## Jack's task under the clock once he has answered.
@export var call_task: String = ""


func choice_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for choice: StoryChoiceDef in choices:
		labels.append(choice.label)
	return labels


## Told somewhere Jack has to go: the manor or his own cottage.
func waits_for_jack() -> bool:
	return place == MANOR or place == HOME
