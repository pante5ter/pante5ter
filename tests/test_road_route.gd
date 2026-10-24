extends GutTest

const L_ROUTE: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), Vector3(10.0, 0.0, 10.0)]


func _route() -> PackedVector3Array:
	return PackedVector3Array(L_ROUTE)


func test_length_adds_up_the_legs() -> void:
	assert_almost_eq(RoadRoute.length_of(_route()), 20.0, 0.001)


func test_progress_is_measured_along_the_whole_route() -> void:
	assert_eq(RoadRoute.point_along(_route(), 0.0), Vector3.ZERO)
	assert_almost_eq(RoadRoute.point_along(_route(), 0.25).x, 5.0, 0.001)
	var turn := RoadRoute.point_along(_route(), 0.75)
	assert_almost_eq(turn.x, 10.0, 0.001)
	assert_almost_eq(turn.z, 5.0, 0.001)
	assert_eq(RoadRoute.point_along(_route(), 1.0), Vector3(10.0, 0.0, 10.0))
	assert_eq(RoadRoute.point_along(_route(), 3.0), Vector3(10.0, 0.0, 10.0), "progress is clamped")


func test_heading_follows_the_current_leg() -> void:
	assert_eq(RoadRoute.heading_along(_route(), 0.1), Vector3(1.0, 0.0, 0.0))
	assert_eq(RoadRoute.heading_along(_route(), 0.9), Vector3(0.0, 0.0, 1.0))


func test_repeated_points_are_dropped() -> void:
	var route := PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3(5.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.01)])
	assert_eq(RoadRoute.without_repeats(route).size(), 2)


func test_empty_route_stays_put() -> void:
	assert_eq(RoadRoute.point_along(PackedVector3Array(), 0.5), Vector3.ZERO)
	assert_eq(RoadRoute.heading_along(PackedVector3Array([Vector3.ONE]), 0.5), Vector3.ZERO)
