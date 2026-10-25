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
## Each harvest rolls uniformly in yield_min..yield_max, never the same total as the strain's last harvest;
## care adds on top. Equal bounds harvest the same every time.
@export var yield_min: int = 1
@export var yield_max: int = 1
@export var fertilizer_yield: int = 0
@export var prune_yield: int = 0

@export_group("Price")
@export var base_price: int = 1
@export var price_mult_at_q0: float = 1.0
@export var price_mult_at_q100: float = 1.0


func growth_hours() -> float:
	return seed_hours + sprout_hours + bush_hours


func care_yield(fertilized: bool, pruned: bool) -> int:
	return (fertilizer_yield if fertilized else 0) + (prune_yield if pruned else 0)


func top_yield() -> int:
	return maxi(yield_max, yield_min)


## Before care.
func mean_yield() -> float:
	return float(yield_min + top_yield()) / 2.0


func needs_seeds() -> bool:
	return seed_price > 0
