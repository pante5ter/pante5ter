class_name TravelCommand
extends SimCommand

## DayCycle.FARM, HOME or STASH.
var place: String = ""


func _init(destination: String) -> void:
	place = destination
