class_name RentDef
extends Resource

@export var amount: int = 0
@export var period_hours: float = 48.0
@export var first_due_hours: float = 48.0
## Consecutive missed payments after which the lord evicts Jack.
@export var evict_after_missed: int = 3
@export var missed_suspicion: float = 0.0
## Added to the debt when a payment is missed; collected with the next successful payment.
@export var late_fee: int = 0
## The lord rings this many game hours before the rent is due: pay now or bring it to the manor.
## Zero: no call, the rent is simply taken when due.
@export var call_ahead_hours: float = 0.0
