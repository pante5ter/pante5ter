class_name OrdersDef
extends Resource

@export_group("Calls (game hours)")
@export var first_order_hours: float = 0.5
@export var interval_hours: float = 2.0
## How long a caller waits for an answer before hanging up.
@export var answer_hours: float = 1.0
@export var deadline_hours: float = 8.0

@export_group("Size")
@export var max_open: int = 3
@export var quantity_min: int = 2
@export var quantity_max: int = 5
@export var quality_min: int = 40
@export var quality_max: int = 70
@export var quality_step: int = 5

@export_group("Pay")
@export var reward_multiplier: float = 1.3
@export_range(0.0, 1.0) var haggle_success: float = 0.5
@export var haggle_bonus: float = 0.25

@export_group("Packing")
@export var pack_minutes_per_unit: float = 10.0

@export_group("Delivery")
@export var trip_hours: float = 1.5
@export_range(0.0, 1.0) var base_trip_risk: float = 0.15
## Each point of suspicion adds this share of the base risk.
@export var suspicion_risk_factor: float = 0.02
@export_range(0.0, 1.0) var jack_reliability: float = 0.7
@export var stopped_suspicion: float = 10.0
