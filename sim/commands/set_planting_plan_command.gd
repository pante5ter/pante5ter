class_name SetPlantingPlanCommand
extends SimCommand

var strain_id: String = ""
## PlantingPlan.AUTO drops the count and leaves the strain to the best-seeds rule.
var beds: int = PlantingPlan.AUTO


func _init(plan_strain_id: String, plan_beds: int) -> void:
	strain_id = plan_strain_id
	beds = plan_beds
