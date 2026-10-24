class_name ContainerEntrance
extends Elevator
## Jack's own container on the edge of the field: clicking it goes straight down to the plantation.
## The supply parcel waiting by the door is its own ParcelBox.


func hover_text() -> String:
	if not Game.sim.supplies.parcel().is_empty():
		return hover_label + " (у двери посылка)"
	return hover_label
