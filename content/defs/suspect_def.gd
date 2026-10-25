class_name SuspectDef
extends Resource

## One of the people who could have told the gang about the container.
@export var id: String = ""
@export var display_name: String = ""
## When he is one of Jack's hired couriers, a proven rat loses the job.
@export var courier_id: String = ""
## The story where Jack meets or hears of him. Until it has been told he is kept out of the hunt:
## the intrigue tells it first. Empty for people Jack knows from day one.
@export var intro_story: StoryDef
## Reggie's finding that clears him when he is innocent.
@export_multiline var alibi_clue: String = ""
@export var alibi_place: String = ""
## Looks bad either way: brought whether he is the rat or not.
@export_multiline var herring_clue: String = ""
@export var herring_place: String = ""
## Reggie's findings against him when he is the rat: harmless facts that name him...
@export var guilty_clues: PackedStringArray = PackedStringArray()
@export var guilty_places: PackedStringArray = PackedStringArray()
## ...and facts about the raid that name nobody. Only together do they point at him.
@export var trail_clues: PackedStringArray = PackedStringArray()
@export var trail_places: PackedStringArray = PackedStringArray()
## Neutral: the name and who he is, never a verdict.
@export var accuse_label: String = ""
@export var guilty_reply: Array[DialogueLineDef] = []
@export var innocent_reply: Array[DialogueLineDef] = []
