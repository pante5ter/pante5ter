class_name ParkingSpot
extends Marker3D
## Where a Land Rover can stop. Cars reach it from the main road: road junction -> lane end -> bay.

@export var title: String = ""
@export var lane_end: Marker3D
@export var junction: Marker3D
## The second car parks this far from the first.
@export var bay_offset: Vector3 = Vector3(3.0, 0.0, 0.0)


func bay_position(bay: int) -> Vector3:
	return global_position + global_basis * (bay_offset * float(bay))


## The way in from the main road, ending in `bay`.
func approach_route(bay: int) -> PackedVector3Array:
	return PackedVector3Array([junction.global_position, lane_end.global_position, bay_position(bay)])
