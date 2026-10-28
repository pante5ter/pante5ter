extends GutTest

const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 3


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()

	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(42)


func _open() -> Level:
	var level := (load(PLANTATION_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _grid(level: Level) -> PlotsGrid:
	return level.get_node("NavRegion/PlotsGrid") as PlotsGrid


func _positions(grid: PlotsGrid) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for view: PlotView in grid.views():
		result.append(view.position)
	return result


func _buy_beds_up_to_the_cap() -> void:
	Game.sim.progress.reached = Game.sim.config.milestones.size()
	while Game.sim.grow.plots().size() < Game.sim.config.max_plots:
		Game.sim.economy.earn(Game.sim.config.plot_price)
		assert_true(Game.sim.apply(BuyPlotCommand.new()).ok)


func test_buying_beds_never_moves_the_ones_already_there() -> void:
	var level := await _open()
	var grid := _grid(level)
	Game.sim.progress.reached = Game.sim.config.milestones.size()
	while Game.sim.grow.plots().size() < Game.sim.config.max_plots:
		var before := _positions(grid)
		Game.sim.economy.earn(Game.sim.config.plot_price)
		assert_true(Game.sim.apply(BuyPlotCommand.new()).ok)
		await wait_process_frames(2)
		var after := _positions(grid)
		assert_eq(after.size(), before.size() + 1)
		for index: int in before.size():
			assert_almost_eq(after[index].distance_to(before[index]), 0.0, 0.001, "bed %d moved when bed %d was bought" % [index + 1, after.size()])


func test_every_bed_gets_its_own_slot() -> void:
	var level := await _open()
	_buy_beds_up_to_the_cap()
	await wait_process_frames(2)
	var positions := _positions(_grid(level))
	for a: int in positions.size():
		for b: int in range(a + 1, positions.size()):
			assert_gt(positions[a].distance_to(positions[b]), 2.0, "beds %d and %d overlap" % [a + 1, b + 1])


func test_the_full_grid_sits_centred_in_the_room() -> void:
	var level := await _open()
	_buy_beds_up_to_the_cap()
	await wait_process_frames(2)
	var centre := Vector3.ZERO
	var positions := _positions(_grid(level))
	for position: Vector3 in positions:
		centre += position
	centre /= float(positions.size())
	assert_almost_eq(centre.x, 0.0, 0.01)
	assert_almost_eq(centre.z, 0.0, 0.01)


func test_a_full_farm_keeps_every_bed_and_work_spot_reachable() -> void:
	var level := await _open()
	_buy_beds_up_to_the_cap()
	await wait_process_frames(2)
	await wait_physics_frames(SETTLE_FRAMES)
	var map := level.get_world_3d().navigation_map
	await wait_until(func() -> bool: return NavigationServer3D.map_get_iteration_id(map) > 0, 2.0)
	var start := level.jack.global_position
	for view: PlotView in _grid(level).views():
		for spot: Vector3 in [view.approach_position(), view.approach_position() + WorkerView.WORK_OFFSET]:
			var path := NavigationServer3D.map_get_path(map, start, spot, true)
			var end := path[path.size() - 1] if not path.is_empty() else start
			assert_lt(Vector2(end.x, end.z).distance_to(Vector2(spot.x, spot.z)), 0.6, "%s is not reachable" % view.title())
