class_name HaulCommand
extends SimCommand

## Helper.ACTOR (Reggie drives) or DayCycle.JACK (Jack drives and stays at the stash).
var driver: String = ""


func _init(chosen_driver: String) -> void:
	driver = chosen_driver
