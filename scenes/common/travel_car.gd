class_name TravelCar
extends Interactable
## The Land Rover at the door of the house or the stash.


func hover_text() -> String:
	return "Лендровер — поехать (%s)" % Travel.driver_note()


func interact(level: Level) -> void:
	level.hud.show_actions("Лендровер · %s" % Travel.driver_note(), actions(level))


func actions(level: Level) -> Array[UiAction]:
	return Travel.actions_from(level.place, level)
