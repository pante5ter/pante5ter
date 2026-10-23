class_name OrdersDef
extends Resource

@export_group("Timing (game hours)")
@export var first_order_hours: float = 0.5
@export var interval_hours: float = 2.0
@export var deadline_hours: float = 8.0
@export var pickup_hours: float = 1.0

@export_group("Size")
@export var max_open: int = 3
@export var quantity_min: int = 2
@export var quantity_max: int = 5
@export var quality_min: int = 40
@export var quality_max: int = 70
@export var quality_step: int = 5

@export_group("Pay")
@export var reward_multiplier: float = 1.3
