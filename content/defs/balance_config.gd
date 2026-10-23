class_name BalanceConfig
extends Resource

@export var real_seconds_per_game_day: float = 600.0
@export var starting_money: int = 0
@export var plot_count: int = 1
@export var strain: StrainDef
@export var extra_strains: Array[StrainDef] = []
@export var worker: WorkerDef
@export var orders: OrdersDef

@export_group("Care")
@export var fertilizer_price: int = 0
@export var fertilizer_bonus: int = 0
@export var prune_bonus: int = 0

@export_group("Shop")
@export var delivery_hours: float = 1.0
@export var plot_price: int = 0
@export var max_plots: int = 1


func strains() -> Array[StrainDef]:
	var all: Array[StrainDef] = [strain]
	all.append_array(extra_strains)
	return all


func find_strain(strain_id: String) -> StrainDef:
	if strain_id.is_empty():
		return strain
	for candidate: StrainDef in strains():
		if candidate.id == strain_id:
			return candidate
	return null
