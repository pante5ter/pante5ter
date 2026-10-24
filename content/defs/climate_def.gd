class_name ClimateDef
extends Resource

## Bought once; until then Jack sees no readings.
@export var sensor_price: int = 0
@export var rooms: Array[RoomDef] = []
## Index 0 is what the bunker has from the start; a quiet farm runs on it too.
@export var ventilation: Array[VentilationDef] = []
@export var bill_every_hours: int = 24

@export_group("Mold")
## Humidity up to this is safe.
@export var mold_safe_humidity: float = 60.0
## Per humidity point above the safe level: how many times the farm's hourly trouble chance
## a bed has of catching mold. A calm farm (no trouble chance) grows no mold however damp.
@export var mold_factor_per_point: float = 0.0
@export var mold_factor_max: float = 1.0
