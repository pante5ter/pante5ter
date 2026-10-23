class_name RaidsDef
extends Resource

@export var start_hours: float = 24.0
@export var night_hour: float = 1.0
@export_range(0.0, 1.0) var chance_per_night: float = 0.0
## Raids only bother small players; above this empire value nobody dares.
@export var max_empire_value: int = 0
@export var deadline_hours: float = 1.0
@export var bribe: int = 0
@export_range(0.0, 1.0) var chase_chance: float = 0.0
@export_range(0.0, 1.0) var chase_bonus_with_worker: float = 0.0
@export var chase_noise: float = 0.0
