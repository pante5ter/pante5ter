class_name WorkerDef
extends Resource

const FARMHAND: String = "farmhand"
const PACKER: String = "packer"
const HELPER: String = "helper"

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var daily_wage: int = 0
@export_enum("farmhand", "packer", "helper") var role: String = FARMHAND
## Russian texts agree verbs with it: «нанят» / «нанята».
@export var male: bool = true

@export_group("Work (game minutes)")
@export var task_minutes: float = 1.0
@export var idle_check_minutes: float = 1.0

@export_group("Care")
@export var water_below_hours: float = 0.0

@export_group("Traits")
## Above 1 works faster than task_minutes, below 1 slower.
@export var competence: float = 1.0
@export_range(0.0, 1.0) var loyalty: float = 1.0
@export_range(0.0, 1.0) var greed: float = 0.0
## Suspicion added each paid day: he talks in the pub.
@export var talkativeness: float = 0.0

@export_group("Helper")
## Delivery reliability when he drives an order himself.
@export_range(0.0, 1.0) var reliability: float = 0.7
@export var starting_skills: Array[String] = []


func task_seconds() -> float:
	return task_minutes * 60.0 / maxf(competence, 0.1)


func steal_chance() -> float:
	return clampf(greed * (1.0 - loyalty * 0.5), 0.0, 1.0)
