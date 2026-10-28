class_name RentDef
extends Resource

@export var amount: int = 0
@export var period_hours: float = 48.0
@export var first_due_hours: float = 48.0
## Consecutive missed payments after which the lord evicts Jack.
@export var evict_after_missed: int = 3
@export var missed_suspicion: float = 0.0
## The lord rings this many game hours before the rent is due: pay now or bring it to the manor.
## Zero: no call, the rent is simply taken when due.
@export var call_ahead_hours: float = 0.0
## A missed payment is not forgiven: it becomes a debt with this fee on top...
@export var late_fee: int = 0
## ...and the lord's man looks into the till this often until he can take the whole debt.
@export var debt_check_hours: float = 1.0
