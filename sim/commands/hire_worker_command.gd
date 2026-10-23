class_name HireWorkerCommand
extends SimCommand

var worker_id: String = ""


func _init(chosen_worker_id: String = "") -> void:
	worker_id = chosen_worker_id
