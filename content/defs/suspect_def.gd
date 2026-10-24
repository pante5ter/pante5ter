class_name SuspectDef
extends Resource

## One of the people who could have told the gang about the container.
@export var id: String = ""
@export var display_name: String = ""
## When he is one of Jack's hired couriers, a proven rat loses the job.
@export var courier_id: String = ""
## Reggie's finding that clears him when he is innocent.
@export_multiline var alibi_clue: String = ""
## Reggie's findings against him when he is the rat.
@export var guilty_clues: PackedStringArray = PackedStringArray()
@export var accuse_label: String = ""
@export var guilty_reply: Array[DialogueLineDef] = []
@export var innocent_reply: Array[DialogueLineDef] = []
