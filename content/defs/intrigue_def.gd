class_name IntrigueDef
extends Resource

## The opening story's choices, in this order.
const INVESTIGATE: int = 0
const PAY_BOSS: int = 1
const RETALIATE: int = 2

## Told after the first raid: who tipped the gang off about the container?
@export var opening_story: StoryDef
@export var suspects: Array[SuspectDef] = []
@export var clue_interval_hours: float = 5.0

@export_group("Accusation")
@export var accuse_lines: Array[DialogueLineDef] = []
## Speaker of the clue recap lines.
@export var finn_speaker: String = "Финн"
## The gang's boss names the rat; %s is the name.
@export var boss_speaker: String = "Гаффер"
@export var boss_name_line: String = ""

@export_group("Consequences")
@export var caught_calm_days: float = 5.0
@export var paid_calm_days: float = 2.0
@export var retaliated_calm_days: float = 4.0
@export var caught_relief: float = 10.0
@export var caught_crew: int = 1
@export var wrong_suspicion: float = 5.0
@export var wrong_village: int = -2


func suspect(suspect_id: String) -> SuspectDef:
	for candidate: SuspectDef in suspects:
		if candidate.id == suspect_id:
			return candidate
	return null
