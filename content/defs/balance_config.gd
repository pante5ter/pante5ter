class_name BalanceConfig
extends Resource

@export var real_seconds_per_game_day: float = 600.0
@export var starting_money: int = 0
@export var plot_count: int = 1
@export var strain: StrainDef
@export var extra_strains: Array[StrainDef] = []
@export var worker: WorkerDef
@export var worker_candidates: Array[WorkerDef] = []
@export var orders: OrdersDef
@export var problems: ProblemsDef
@export var suspicion: SuspicionDef
@export var raids: RaidsDef
@export var milestones: Array[MilestoneDef] = []

@export_group("Care")
@export var fertilizer_price: int = 0
@export var fertilizer_bonus: int = 0
@export var prune_bonus: int = 0

@export_group("Shop")
@export var delivery_hours: float = 1.0
@export var plot_price: int = 0
@export var starting_plot_cap: int = 1
@export var max_plots: int = 1


func strains() -> Array[StrainDef]:
	var all: Array[StrainDef] = [strain]
	all.append_array(extra_strains)
	return all


func candidates() -> Array[WorkerDef]:
	if worker_candidates.is_empty():
		var only: Array[WorkerDef] = [worker]
		return only
	return worker_candidates


func find_worker(worker_id: String) -> WorkerDef:
	if worker_id.is_empty():
		return worker
	for candidate: WorkerDef in candidates():
		if candidate.id == worker_id:
			return candidate
	return null


func find_strain(strain_id: String) -> StrainDef:
	if strain_id.is_empty():
		return strain
	for candidate: StrainDef in strains():
		if candidate.id == strain_id:
			return candidate
	return null
