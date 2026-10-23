extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 3


func before_each() -> void:
	Game.new_game(42)
	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(42)


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _plots_grid(level: Level) -> PlotsGrid:
	return level.get_node("NavRegion/PlotsGrid") as PlotsGrid


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func test_field_bakes_navigation_and_places_jack_at_start() -> void:
	var level := await _open(FIELD_SCENE)
	assert_gt(level.nav_region.navigation_mesh.get_polygon_count(), 0)
	var start := (level.get_node("SpawnPoints/start") as Node3D).global_position
	assert_almost_eq(_flat_distance(level.jack.global_position, start), 0.0, 0.01)


func test_jack_walks_to_a_clicked_point() -> void:
	var level := await _open(FIELD_SCENE)
	var target := level.jack.global_position + Vector3(4.0, 0.0, 0.0)
	var arrived := [false]
	level.jack.move_to(target, func() -> void: arrived[0] = true)
	await wait_until(func() -> bool: return arrived[0] == true, 5.0)
	assert_true(arrived[0] == true, "Jack never arrived")
	assert_lt(_flat_distance(level.jack.global_position, target), 0.6)


func test_plantation_shows_one_bed_per_plot() -> void:
	var level := await _open(PLANTATION_SCENE)
	assert_eq(_plots_grid(level).views().size(), Game.sim.grow.plots().size())
	assert_gt(level.nav_region.navigation_mesh.get_polygon_count(), 0)


func test_clicking_beds_plants_then_waters() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bed := _plots_grid(level).view_for(0)
	bed.interact(level)
	assert_eq(Game.sim.grow.plot(0).stage, Plot.Stage.SEED)
	assert_eq(Game.sim.grow.plot(0).water_seconds, 0.0)
	bed.interact(level)
	assert_gt(Game.sim.grow.plot(0).water_seconds, 0.0)
	assert_eq(Game.sim.event_log.last().type, EventLog.PLOT_WATERED)


func test_clicking_a_ripe_bed_harvests_it() -> void:
	var level := await _open(PLANTATION_SCENE)
	var strain := Game.sim.config.strain
	var growth_hours := strain.seed_hours + strain.sprout_hours + strain.bush_hours
	Game.sim.apply(PlantCommand.new(1))
	var hours_left := growth_hours
	while hours_left > 0.0:
		Game.sim.apply(WaterCommand.new(1))
		var step := minf(hours_left, strain.water_capacity_hours)
		Game.sim.apply(AdvanceTimeCommand.new(step * Game.sim.config.real_seconds_per_game_day / 24.0))
		hours_left -= step
	assert_eq(Game.sim.grow.plot(1).stage, Plot.Stage.READY)
	_plots_grid(level).view_for(1).interact(level)
	assert_eq(Game.sim.grow.plot(1).stage, Plot.Stage.EMPTY)
	assert_eq(Game.sim.inventory.count(), 1)


func test_buyer_sells_everything_on_hand() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.inventory.create(Game.sim.config.strain.id, 40)
	Game.sim.inventory.create(Game.sim.config.strain.id, 80)
	var money := Game.sim.economy.money
	(level.get_node("NavRegion/Buyer") as Buyer).interact(level)
	assert_eq(Game.sim.inventory.count(), 0)
	assert_eq(Game.sim.economy.money, money + Game.sim.economy.price_for(40) + Game.sim.economy.price_for(80))
	assert_eq(Game.sim.event_log.of_type(EventLog.PRODUCT_SOLD).size(), 2)


func test_candidate_gets_hired_and_leaves_the_field() -> void:
	var level := await _open(FIELD_SCENE)
	var candidate := level.get_node("NavRegion/Candidate") as WorkerCandidate
	candidate.interact(level)
	assert_true(Game.sim.workers.hired)
	await wait_process_frames(2)
	assert_false(candidate.visual.visible)
	assert_eq(candidate.collision_layer, 0)


func test_hired_worker_walks_to_his_bed() -> void:
	Game.sim.apply(HireWorkerCommand.new())
	Game.sim.apply(AdvanceTimeCommand.new(0.0))
	var level := await _open(PLANTATION_SCENE)
	var worker := level.get_node("Worker") as WorkerView
	var bed := _plots_grid(level).view_for(Game.sim.workers.task_plot_id)
	assert_true(worker.visible)
	var start_distance := _flat_distance(worker.global_position, bed.approach_position())
	await wait_until(func() -> bool: return _flat_distance(worker.global_position, bed.approach_position()) < 1.2, 6.0)
	assert_lt(_flat_distance(worker.global_position, bed.approach_position()), minf(start_distance, 1.2))


func test_worker_is_hidden_until_hired() -> void:
	var level := await _open(PLANTATION_SCENE)
	await wait_process_frames(2)
	assert_false((level.get_node("Worker") as WorkerView).visible)
