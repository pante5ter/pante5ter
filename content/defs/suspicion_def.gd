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

@export_group("Preparation")
## Jack's answer to the warning call. Lights out passes for sure but the beds stop growing until it is over.
## The other answers keep the lamps on and roll: chance of a clean visit minus this much per point of suspicion.
@export var pass_chance_per_suspicion: float = 0.0
@export var min_pass_chance: float = 0.05
## Crates carried out into the wheat: the inspector finds less to wonder about, but the field takes its share.
@export var hide_pass_chance: float = 0.7
@export var hide_loss_chance: float = 0.0
@export var hide_loss_share: float = 0.5
## A word with the inspector through a friend at the station.
@export var bribe_price: int = 0
@export var bribe_pass_chance: float = 0.9
## Nothing done: the lamps glow and the inspector looks around.
@export var nothing_pass_chance: float = 0.4
