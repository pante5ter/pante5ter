class_name StashDef
extends Resource

## The crates' drive from the farm to the stash in the village.

## Game hours one way when Reggie drives them.
@export var haul_hours: float = 0.5
## Chance the police stop a haul, before heat and the driver.
@export_range(0.0, 1.0) var base_risk: float = 0.0
## Each suspicion point adds this share to the risk.
@export var suspicion_risk_factor: float = 0.0
## Jack is no professional driver.
@export_range(0.0, 1.0) var jack_risk_factor: float = 1.0
@export var per_haul_suspicion: float = 0.0
@export var stopped_suspicion: float = 0.0
## Game minutes to carry the crates in from the car; the packer starts on them after that.
@export var unload_minutes: float = 0.0
