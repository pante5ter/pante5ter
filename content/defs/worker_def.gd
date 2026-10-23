class_name WorkerDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var daily_wage: int = 0

@export_group("Work (game minutes)")
@export var task_minutes: float = 1.0
@export var idle_check_minutes: float = 1.0

@export_group("Care")
@export var water_below_hours: float = 0.0
