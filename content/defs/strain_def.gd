class_name StrainDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""

@export_group("Growth (game hours)")
@export var seed_hours: float = 1.0
@export var sprout_hours: float = 1.0
@export var bush_hours: float = 1.0
@export var water_capacity_hours: float = 1.0

@export_group("Quality")
@export_range(0, 100) var base_quality: int = 50
@export_range(0, 100) var quality_variance: int = 0
@export var dry_penalty_per_hour: float = 0.0

@export_group("Price")
@export var base_price: int = 1
@export var price_mult_at_q0: float = 1.0
@export var price_mult_at_q100: float = 1.0
