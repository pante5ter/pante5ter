class_name BalanceConfig
extends Resource

@export var real_seconds_per_game_day: float = 600.0
@export var starting_money: int = 0
@export var plot_count: int = 1
@export var strain: StrainDef
@export var extra_strains: Array[StrainDef] = []
@export var worker: WorkerDef
@export var worker_candidates: Array[WorkerDef] = []
## Hired from the first minute; null plays the farm without him.
@export var helper: WorkerDef
@export var skills: Array[SkillDef] = []
@export var packer_candidates: Array[WorkerDef] = []
@export var courier_candidates: Array[CourierDef] = []
@export var max_couriers: int = 2
@export var orders: OrdersDef
@export var problems: ProblemsDef
@export var suspicion: SuspicionDef
@export var raids: RaidsDef
@export var rent: RentDef
@export var milestones: Array[MilestoneDef] = []
## null plays without the first-day script / without the event director.
@export var first_day: FirstDayDef
@export var director: DirectorDef
## null plays without the rat hunt after the first raid.
@export var intrigue: IntrigueDef
## Finn's call after a courier steals; %s in the texts is the thief's name. Null: no call.
@export var courier_theft_story: StoryDef

@export_group("Care")
@export var fertilizer_price: int = 0
@export var fertilizer_bonus: int = 0
@export var prune_bonus: int = 0

@export_group("Shop")
@export var delivery_hours: float = 1.0
@export var plot_price: int = 0
@export var starting_plot_cap: int = 1
@export var max_plots: int = 1
## One-tap restock tops each item up to this count (stock + parcels on the way).
@export var restock_basket: Dictionary[String, int] = {}
@export var auto_reorder_check_hours: float = 1.0

@export_group("Helper")
## He dims the lights himself this many game hours before an inspection.
@export var helper_lights_out_hours: float = 0.5


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


func find_skill(skill_id: String) -> SkillDef:
	for candidate: SkillDef in skills:
		if candidate.id == skill_id:
			return candidate
	return null


func find_packer(worker_id: String) -> WorkerDef:
	for candidate: WorkerDef in packer_candidates:
		if candidate.id == worker_id:
			return candidate
	return null


func find_courier(courier_id: String) -> CourierDef:
	for candidate: CourierDef in courier_candidates:
		if candidate.id == courier_id:
			return candidate
	return null


func find_strain(strain_id: String) -> StrainDef:
	if strain_id.is_empty():
		return strain
	for candidate: StrainDef in strains():
		if candidate.id == strain_id:
			return candidate
	return null
