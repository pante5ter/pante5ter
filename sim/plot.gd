class_name Plot
extends RefCounted

enum Stage { EMPTY, SEED, SPROUT, BUSH, READY }

var id: int = 0
var stage: Stage = Stage.EMPTY
var progress_seconds: float = 0.0
var water_seconds: float = 0.0
var dry_seconds: float = 0.0
var strain_id: String = ""
var last_strain_id: String = ""
var fertilized: bool = false
var pruned: bool = false
var problem: String = ""


func _init(plot_id: int = 0) -> void:
	id = plot_id


func is_growing() -> bool:
	return stage == Stage.SEED or stage == Stage.SPROUT or stage == Stage.BUSH


func reset() -> void:
	stage = Stage.EMPTY
	progress_seconds = 0.0
	water_seconds = 0.0
	dry_seconds = 0.0
	strain_id = ""
	fertilized = false
	pruned = false
	problem = ""


static func stage_name(value: Stage) -> String:
	return String(Stage.keys()[value]).to_lower()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"stage": stage_name(stage),
		"progress_seconds": ExactFloat.encode(progress_seconds),
		"water_seconds": ExactFloat.encode(water_seconds),
		"dry_seconds": ExactFloat.encode(dry_seconds),
		"strain_id": strain_id,
		"last_strain_id": last_strain_id,
		"fertilized": fertilized,
		"pruned": pruned,
		"problem": problem,
	}


static func from_dict(data: Dictionary) -> Plot:
	var plot := Plot.new(int(data["id"]))
	plot.stage = Stage.get(String(data["stage"]).to_upper(), Stage.EMPTY) as Stage
	plot.progress_seconds = ExactFloat.decode(data["progress_seconds"])
	plot.water_seconds = ExactFloat.decode(data["water_seconds"])
	plot.dry_seconds = ExactFloat.decode(data["dry_seconds"])
	plot.strain_id = String(data["strain_id"])
	plot.last_strain_id = String(data["last_strain_id"])
	plot.fertilized = data["fertilized"] == true
	plot.pruned = data["pruned"] == true
	plot.problem = String(data["problem"])
	return plot
