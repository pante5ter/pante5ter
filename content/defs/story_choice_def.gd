class_name StoryChoiceDef
extends Resource

@export var label: String = ""
## Below 1 the choice is a gamble rolled with the sim's RNG; the fail_* fields apply when it goes wrong.
@export_range(0.0, 1.0) var chance: float = 1.0
## Negative is a cost: the choice is refused when Jack cannot cover it.
@export var money: int = 0
@export var suspicion: float = 0.0
## Whose opinion of Jack moves: "lord", "village" or "crew"; empty for none.
@export var relation: String = ""
@export var relation_change: int = 0
## Paid ahead to the lord: taken off the next rent.
@export var rent_credit: int = 0
@export var reply: Array[DialogueLineDef] = []

@export_group("If it goes wrong")
@export var fail_money: int = 0
@export var fail_suspicion: float = 0.0
@export var fail_relation_change: int = 0
@export var fail_reply: Array[DialogueLineDef] = []


func cost() -> int:
	return maxi(-money, 0)
