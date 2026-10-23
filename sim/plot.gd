class_name Plot
extends RefCounted

enum Stage { EMPTY, SEED, SPROUT, BUSH, READY }

var id: int = 0
var stage: Stage = Stage.EMPTY
var progress_seconds: float = 0.0
var water_seconds: float = 0.0
var dry_seconds: float = 0.0


func _init(plot_id: int = 0) -> void:
	id = plot_id


func is_growing() -> bool:
	return stage == Stage.SEED or stage == Stage.SPROUT or stage == Stage.BUSH


func reset() -> void:
	stage = Stage.EMPTY
	progress_seconds = 0.0
	water_seconds = 0.0
	dry_seconds = 0.0


static func stage_name(value: Stage) -> String:
	return String(Stage.keys()[value]).to_lower()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"stage": stage_name(stage),
		"progress_seconds": progress_seconds,
		"water_seconds": water_seconds,
		"dry_seconds": dry_seconds,
	}


static func from_dict(data: Dictionary) -> Plot:
	var plot := Plot.new(int(data["id"]))
	plot.stage = Stage.get(String(data["stage"]).to_upper(), Stage.EMPTY) as Stage
	plot.progress_seconds = float(data["progress_seconds"])
	plot.water_seconds = float(data["water_seconds"])
	plot.dry_seconds = float(data["dry_seconds"])
	return plot
