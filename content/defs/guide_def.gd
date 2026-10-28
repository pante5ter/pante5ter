class_name GuideDef
extends Resource

## The first-minutes guide and Reggie's «Что делать?» once it is over.

@export_group("Advice")
## Reggie brings up the rent this many game hours before it is due, when the purse is short of it.
@export var rent_warning_hours: float = 12.0
## From this suspicion on Reggie wants the farm quiet rather than bigger.
@export var high_suspicion: float = 45.0
## What Reggie wants left in the purse after a new bed.
@export var spare_money: int = 300
