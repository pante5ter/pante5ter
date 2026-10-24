class_name RoadRoute
extends Node3D
## A polyline through the child markers, in child order. Walkers and cars follow it by progress 0..1.


func points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for child: Node in get_children():
		var marker := child as Node3D
		if marker != null:
			result.append(marker.global_position)
	return result


func sample(progress: float) -> Vector3:
	return RoadRoute.point_along(points(), progress)


func heading(progress: float) -> Vector3:
	return RoadRoute.heading_along(points(), progress)


static func length_of(route: PackedVector3Array) -> float:
	var total := 0.0
	for index: int in range(1, route.size()):
		total += route[index - 1].distance_to(route[index])
	return total


static func point_along(route: PackedVector3Array, progress: float) -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	var remaining := clampf(progress, 0.0, 1.0) * length_of(route)
	for index: int in range(1, route.size()):
		var step := route[index - 1].distance_to(route[index])
		if remaining <= step and step > 0.0:
			return route[index - 1].lerp(route[index], remaining / step)
		remaining -= step
	return route[route.size() - 1]


## Direction of travel at `progress`; zero for a route with no length.
static func heading_along(route: PackedVector3Array, progress: float) -> Vector3:
	var remaining := clampf(progress, 0.0, 1.0) * length_of(route)
	var last := Vector3.ZERO
	for index: int in range(1, route.size()):
		var segment := route[index] - route[index - 1]
		var step := segment.length()
		if step > 0.0:
			last = segment / step
			if remaining <= step:
				return last
		remaining -= step
	return last


## Drops consecutive points closer than `epsilon`, so routes built from shared junctions have no zero legs.
static func without_repeats(route: PackedVector3Array, epsilon: float = 0.05) -> PackedVector3Array:
	var result := PackedVector3Array()
	for point: Vector3 in route:
		if result.is_empty() or result[result.size() - 1].distance_to(point) > epsilon:
			result.append(point)
	return result
