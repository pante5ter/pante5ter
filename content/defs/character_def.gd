class_name CharacterDef
extends Resource

## Met on the opening night, together with the prologue.
const OPENING: String = "opening"
## Met when `meet_event` first happens in the sim.
const EVENT: String = "event"
## Only in the bible: introduced by their own story.
const NONE: String = "none"

@export var id: String = ""
@export var display_name: String = ""
## The backstory bible entry: who this is and how they came into Jack's life.
@export_multiline var bio: String = ""
@export_enum("opening", "event", "none") var meeting: String = NONE
## The event type of the first meeting.
@export var meet_event: String = ""
## When set, the event's data must hold `meet_value` under this key.
@export var meet_key: String = ""
@export var meet_value: String = ""
## The intro waits until Jack is at this place; empty plays anywhere.
@export var place: String = ""
@export var intro: Array[DialogueLineDef] = []


func is_met_by(event: SimEvent) -> bool:
	if meeting != EVENT or event.type != meet_event:
		return false
	return meet_key.is_empty() or str(event.data.get(meet_key, "")) == meet_value
