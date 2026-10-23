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
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _plots_grid(level: Level) -> PlotsGrid:
	return level.get_node("NavRegion/PlotsGrid") as PlotsGrid


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _hours_to_real(hours: float) -> float:
	return hours * Game.sim.config.real_seconds_per_game_day / 24.0


func _choose(level: Level, label: String) -> void:
	assert_true(level.hud.action_menu.visible, "a menu should be open before choosing '%s'" % label)
	assert_true(level.hud.action_menu.choose_label(label), "no action starting with '%s'" % label)


func _grow_to_ready(plot_id: int) -> void:
	var guard := 0
	while Game.sim.grow.plot(plot_id).stage != Plot.Stage.READY and guard < 200:
		Game.sim.apply(WaterCommand.new(plot_id))
		Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(0.25)))
		guard += 1


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


func test_bed_menu_plants_waters_and_cares() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bed := _plots_grid(level).view_for(0)
	bed.interact(level)
	_choose(level, "Посадить «%s»" % Game.sim.config.strain.display_name)
	assert_eq(Game.sim.grow.plot(0).stage, Plot.Stage.SEED)
	bed.interact(level)
	_choose(level, "Полить")
	assert_gt(Game.sim.grow.plot(0).water_seconds, 0.0)
	bed.interact(level)
	var fertilize := level.hud.action_menu.actions().filter(func(action: UiAction) -> bool: return action.label.begins_with("Удобрить"))
	assert_eq(fertilize.size(), 1)
	assert_false((fertilize[0] as UiAction).enabled, "no fertilizer bought yet")


func test_bed_menu_offers_premium_only_with_seeds() -> void:
	var level := await _open(PLANTATION_SCENE)
	var premium := Game.sim.config.extra_strains[0]
	var bed := _plots_grid(level).view_for(2)
	var before := bed.actions(level).filter(func(action: UiAction) -> bool: return action.label.contains(premium.display_name))
	assert_false((before[0] as UiAction).enabled)
	Game.sim.economy.earn(1000)
	Game.sim.apply(BuyCommand.new(Supplies.seed_item(premium.id), 1))
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.delivery_hours + 0.01)))
	Game.sim.apply(PickUpParcelCommand.new())
	bed.interact(level)
	_choose(level, "Посадить «%s»" % premium.display_name)
	assert_eq(Game.sim.grow.plot(2).strain_id, premium.id)


func test_ripe_bed_menu_harvests() -> void:
	var level := await _open(PLANTATION_SCENE)
	Game.sim.apply(PlantCommand.new(1))
	_grow_to_ready(1)
	_plots_grid(level).view_for(1).interact(level)
	_choose(level, "Собрать урожай")
	assert_eq(Game.sim.grow.plot(1).stage, Plot.Stage.EMPTY)
	assert_eq(Game.sim.inventory.count(), 1)


func test_buying_a_bed_adds_it_to_the_plantation() -> void:
	var level := await _open(PLANTATION_SCENE)
	var before := _plots_grid(level).views().size()
	Game.sim.economy.earn(Game.sim.config.plot_price)
	assert_true(Game.sim.apply(BuyPlotCommand.new()).ok)
	await wait_process_frames(2)
	assert_eq(_plots_grid(level).views().size(), before + 1)


func test_candidate_asks_before_hiring_and_then_walks_to_the_container() -> void:
	var level := await _open(FIELD_SCENE)
	var candidate := level.get_node("NavRegion/Candidate") as WorkerCandidate
	candidate.interact(level)
	assert_false(Game.sim.workers.hired, "opening the menu must not hire")
	_choose(level, "Нанять")
	assert_true(Game.sim.workers.hired)
	await wait_process_frames(2)
	assert_false(candidate.visual.visible)
	assert_eq(candidate.collision_layer, 0)
	var walkers := level.get_node("NavRegion").get_children().filter(func(node: Node) -> bool: return node is Walker)
	assert_eq(walkers.size(), 1, "the new hand walks off visibly")
	var walker := walkers[0] as Walker
	var target := (level.get_node("NavRegion/Container/Approach") as Node3D).global_position
	var start := _flat_distance(walker.global_position, target)
	await wait_seconds(1.0)
	assert_lt(_flat_distance(walker.global_position, target), start)


func test_fresh_hire_arrives_from_the_lift_and_walks_to_his_bed() -> void:
	Game.sim.apply(HireWorkerCommand.new())
	Game.sim.apply(AdvanceTimeCommand.new(0.0))
	var level := await _open(PLANTATION_SCENE)
	var worker := level.get_node("Worker") as WorkerView
	var bed := _plots_grid(level).view_for(Game.sim.workers.task_plot_id)
	assert_true(worker.visible)
	await wait_until(func() -> bool: return _flat_distance(worker.global_position, bed.approach_position()) < 1.2, 8.0)
	assert_lt(_flat_distance(worker.global_position, bed.approach_position()), 1.2)


func test_talking_to_the_worker_can_fire_him() -> void:
	Game.sim.apply(HireWorkerCommand.new())
	var level := await _open(PLANTATION_SCENE)
	await wait_process_frames(2)
	var talk := level.get_node("Worker/Talk") as WorkerTalk
	assert_eq(talk.collision_layer, WorkerView.WORKER_LAYER)
	talk.interact(level)
	_choose(level, "Уволить")
	assert_false(Game.sim.workers.hired)
	await wait_process_frames(2)
	assert_eq(talk.collision_layer, 0)
	assert_false((level.get_node("Worker") as WorkerView).visible)


func test_worker_is_hidden_until_hired() -> void:
	var level := await _open(PLANTATION_SCENE)
	await wait_process_frames(2)
	assert_false((level.get_node("Worker") as WorkerView).visible)


func test_beds_stay_centred_in_the_room() -> void:
	var level := await _open(PLANTATION_SCENE)
	var grid := _plots_grid(level)
	var centre := Vector3.ZERO
	for view: PlotView in grid.views():
		centre += view.position
	centre /= float(grid.views().size())
	assert_almost_eq(centre.z, 0.0, 0.01)
	Game.sim.economy.earn(Game.sim.config.plot_price * 3)
	for index: int in 3:
		Game.sim.apply(BuyPlotCommand.new())
	await wait_process_frames(2)
	centre = Vector3.ZERO
	for view: PlotView in grid.views():
		centre += view.position
	centre /= float(grid.views().size())
	assert_almost_eq(centre.z, 0.0, 0.01)



func test_inspector_walks_up_while_an_inspection_is_pending() -> void:
	var level := await _open(FIELD_SCENE)
	var inspector := level.get_node("Inspector") as InspectorView
	await wait_process_frames(2)
	assert_false(inspector.visible)
	Game.sim.suspicion.add(Game.sim.config.suspicion.inspection_threshold + 10.0)
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(1.0)))
	await wait_process_frames(2)
	assert_true(inspector.visible)
	assert_string_contains(level.hud.suspicion_label.text, "ПРОВЕРКА")
	assert_string_contains(level.hud.objective_label.text, "выключите свет")


func test_raiders_show_up_and_can_be_paid_off() -> void:
	var level := await _open(FIELD_SCENE)
	var gang := level.get_node("NavRegion/Raiders") as RaiderGang
	await wait_process_frames(2)
	assert_false(gang.visual.visible)
	assert_eq(gang.collision_layer, 0)
	Game.sim.raids.pending = true
	Game.sim.raids.deadline = Game.sim.clock.elapsed_game_seconds + SimClock.GAME_SECONDS_PER_HOUR
	await wait_process_frames(2)
	assert_true(gang.visual.visible)
	assert_ne(gang.collision_layer, 0)
	var money := Game.sim.economy.money
	gang.interact(level)
	_choose(level, "Откупиться")
	assert_false(Game.sim.raids.pending)
	assert_eq(Game.sim.economy.money, money - Game.sim.config.raids.bribe)


func test_each_candidate_hires_their_own_worker() -> void:
	var level := await _open(FIELD_SCENE)
	var dave := level.get_node("NavRegion/CandidateDave") as WorkerCandidate
	dave.interact(level)
	assert_string_contains((level.hud.action_menu.get_child(0).get_child(0) as Label).text, Game.sim.config.find_worker("dave").description)
	_choose(level, "Нанять")
	assert_eq(Game.sim.workers.definition().id, "dave")
	await wait_process_frames(2)
	for node_name: String in ["Candidate", "CandidateDave", "CandidateBarry"]:
		assert_false((level.get_node("NavRegion/" + node_name) as WorkerCandidate).visual.visible)


func test_a_sick_bed_offers_the_cure() -> void:
	var level := await _open(PLANTATION_SCENE)
	Game.sim.apply(PlantCommand.new(3))
	Game.sim.grow.plot(3).problem = Problems.MOLD
	var bed := _plots_grid(level).view_for(3)
	await wait_process_frames(2)
	assert_string_contains(bed.label.text, "Плесень")
	bed.interact(level)
	_choose(level, "Убрать плесень")
	assert_eq(Game.sim.grow.plot(3).problem, "")


func test_hud_shows_empire_value_and_the_next_goal() -> void:
	var level := await _open(FIELD_SCENE)
	await wait_process_frames(2)
	assert_string_contains(level.hud.empire_label.text, UiText.money(Game.sim.empire_value()))
	assert_string_contains(level.hud.empire_label.text, Game.sim.config.milestones[0].title)
	level.hud.phone.open(Phone.TAB_EMPIRE)
	assert_eq(level.hud.phone.current_tab(), Phone.TAB_EMPIRE)


func test_locked_strain_is_not_offered_for_planting() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bed := _plots_grid(level).view_for(0)
	var labels := bed.actions(level).map(func(action: UiAction) -> String: return action.label)
	var elite := Game.sim.config.find_strain("elite")
	for label: Variant in labels:
		assert_false(String(label).contains(elite.display_name))


func _accept_first_call() -> Order:
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.orders.first_order_hours + 0.01)))
	var order := Game.sim.orders.all()[0]
	Game.sim.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	return order


func test_computer_answers_calls_and_ships_orders() -> void:
	var level := await _open(PLANTATION_SCENE)
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.orders.first_order_hours + 0.01)))
	var order := Game.sim.orders.all()[0]
	var desk := level.get_node("NavRegion/Computer") as ComputerDesk
	await wait_process_frames(2)
	assert_true(desk.screen_glow.visible, "a ringing computer glows")
	desk.interact(level)
	assert_true(level.hud.computer.visible)
	assert_eq(level.hud.computer.current_tab(), ComputerScreen.TAB_CALLS)
	level.hud.computer.answer(order.id, Orders.ACCEPT)
	assert_eq(order.status, Order.Status.ACCEPTED)
	for index: int in order.quantity:
		Game.sim.inventory.create(Game.sim.config.strain.id, 100).packed = true
	level.hud.computer.dispatch(order.id, Couriers.JACK)
	assert_eq(order.status, Order.Status.IN_TRANSIT)
	await wait_physics_frames(2)
	assert_false(level.jack.visible, "Jack is away delivering")


func test_bench_packs_the_harvest_onto_the_shelf() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bench := level.get_node("NavRegion/Bench") as PackingBench
	var shelf := level.get_node("NavRegion/Shelf/Stock") as StockShelf
	Game.sim.inventory.create(Game.sim.config.strain.id, 60)
	Game.sim.inventory.create(Game.sim.config.strain.id, 70)
	await wait_process_frames(2)
	assert_true(bench.sacks.visible)
	assert_eq(shelf.shown_boxes(), 0)
	bench.interact(level)
	_choose(level, "Расфасовать")
	assert_true(Game.sim.packing.busy())
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.orders.pack_minutes_per_unit * 2.0 / 60.0 + 0.01)))
	await wait_process_frames(2)
	assert_eq(shelf.shown_boxes(), 2)
	assert_false(bench.sacks.visible)
	assert_string_contains(level.hud.stock_label.text, "2 коробок")


func test_parcels_wait_at_the_container_and_can_be_picked_up() -> void:
	var level := await _open(FIELD_SCENE)
	var entrance := level.get_node("NavRegion/Container") as ContainerEntrance
	Game.sim.apply(BuyCommand.new(Supplies.FERTILIZER, 2))
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.delivery_hours + 0.01)))
	await wait_process_frames(2)
	assert_true(entrance.parcel_box.visible)
	entrance.interact(level)
	_choose(level, "Забрать посылку")
	assert_eq(Game.sim.supplies.fertilizer, 2)
	await wait_process_frames(2)
	assert_false(entrance.parcel_box.visible)


func test_hired_couriers_walk_the_road_with_orders() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.economy.earn(1000)
	Game.sim.apply(HireCourierCommand.new("harry"))
	var order := _accept_first_call()
	for index: int in order.quantity:
		Game.sim.inventory.create(Game.sim.config.strain.id, 100).packed = true
	var courier := level.get_node("CourierA") as CourierView
	await wait_process_frames(2)
	assert_false(courier.visible)
	Game.sim.apply(DispatchCommand.new(order.id, "harry"))
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(0.2)))
	await wait_process_frames(2)
	assert_true(courier.visible)
	assert_string_contains(courier.name_label.text, "Гарри")
	assert_false((level.get_node("CourierB") as CourierView).visible)
