class_name SkillDef
extends Resource

const CARE: String = "care"
const PRUNE: String = "prune"
const FERTILIZE: String = "fertilize"
const PACK: String = "pack"
const DRIVING: String = "driving"
## Changes burned-out grow lamps (from stock).
const ELECTRICS: String = "electrics"

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_enum("care", "prune", "fertilize", "pack", "driving", "electrics") var kind: String = CARE
@export var price: int = 0
## Game hours away on the course; he does not work the farm meanwhile.
@export var train_hours: float = 1.0
## Driving: multiplies the risk of a stopped delivery when he drives.
@export_range(0.0, 1.0) var trip_risk_factor: float = 1.0
