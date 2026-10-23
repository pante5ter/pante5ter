class_name CourierDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var hire_fee: int = 0
## Share of each paid order the courier keeps.
@export_range(0.0, 1.0) var cut: float = 0.0
## Above 1 delivers faster than the base trip time.
@export var speed: float = 1.0
@export_range(0.0, 1.0) var reliability: float = 0.5
@export_range(0.0, 1.0) var greed: float = 0.0
