class_name StrainDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
## Zero means the strain is the house stock: unlimited and free to plant.
@export var seed_price: int = 0

@export_group("Growth (game hours)")
@export var seed_hours: float = 1.0
@export var sprout_hours: float = 1.0
@export var bush_hours: float = 1.0
@export var water_capacity_hours: float = 1.0

@export_group("Quality")
@export_range(0, 100) var base_quality: int = 50
@export_range(0, 100) var quality_variance: int = 0
@export var dry_penalty_per_hour: float = 0.0

@export_group("Yield (units per harvest)")
@export var base_yield: int = 1
@export var fertilizer_yield: int = 0
@export var prune_yield: int = 0
## Each harvest rolls 0..this many extra units on top; zero harvests the same every time.
@export var bonus_yield_max: int = 0

@export_group("Price")
@export var base_price: int = 1
@export var price_mult_at_q0: float = 1.0
@export var price_mult_at_q100: float = 1.0


func growth_hours() -> float:
	return seed_hours + sprout_hours + bush_hours


func yield_for(fertilized: bool, pruned: bool) -> int:
	return maxi(base_yield + (fertilizer_yield if fertilized else 0) + (prune_yield if pruned else 0), 1)


func needs_seeds() -> bool:
	return seed_price > 0
