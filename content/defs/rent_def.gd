class_name RentDef
extends Resource

@export var amount: int = 0
@export var period_hours: float = 48.0
@export var first_due_hours: float = 48.0
## Consecutive missed payments after which the lord evicts Jack.
@export var evict_after_missed: int = 3
@export var missed_suspicion: float = 0.0
