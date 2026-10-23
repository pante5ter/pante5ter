class_name PlantCommand
extends SimCommand

var plot_id: int = 0
var strain_id: String = ""


func _init(target_plot_id: int, chosen_strain_id: String = "") -> void:
	plot_id = target_plot_id
	strain_id = chosen_strain_id
