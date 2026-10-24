class_name VentilationDef
extends Resource

## One setting of the bunker's air handling.
@export var display_name: String = ""
@export var humidity_drop: float = 0.0
@export var cooling: float = 0.0
## Electricity, charged on the next bill.
@export var power_per_hour: int = 0
