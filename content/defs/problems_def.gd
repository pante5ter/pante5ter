class_name ProblemsDef
extends Resource

@export var start_hours: float = 24.0
@export_range(0.0, 1.0) var chance_per_hour: float = 0.0
@export var pesticide_price: int = 0
@export var lamp_price: int = 0
## Every this many game hours of untreated pests eat one unit of the harvest; 0 = they eat nothing.
@export var pest_hours_per_lost_unit: float = 0.0
