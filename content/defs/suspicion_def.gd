class_name SuspicionDef
extends Resource

@export_group("Sources")
@export var per_delivery: float = 0.0
@export var per_extra_bed_per_hour: float = 0.0
@export var quiet_beds: int = 6
@export var decay_per_hour: float = 0.0

@export_group("Inspection")
@export var inspection_threshold: float = 100.0
@export var warning_hours: float = 1.0
@export var fine: int = 0
@export var relief_when_hidden: float = 0.0
@export var relief_when_caught: float = 0.0
## Paying off the tip so the inspection never arrives.
@export var bribe_cost: int = 150
@export var bribe_suspicion_relief: float = 10.0
