extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const STASH_SCENE: String = "res://scenes/stash/stash.tscn"
const SETTLE_FRAMES: int = 3


func before_each() -> void:
	Game.new_game(42)
	# Regular calls from the first minute: the first-day script is tested on its own.
	Game.sim.first_day.skip()
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
	var harvested := Game.sim.event_log.of_type(EventLog.PLOT_HARVESTED)
	assert_eq(harvested.size(), 1)
	assert_eq(Game.sim.inventory.count(), int(harvested[0].data["quantity"]))


func test_buying_a_bed_adds_it_to_the_plantation() -> void:
	var level := await _open(PLANTATION_SCENE)
	var before := _plots_grid(level).views().size()
	Game.sim.economy.earn(Game.sim.config.plot_price)
	assert_true(Game.sim.apply(BuyPlotCommand.new()).ok)
	await wait_process_frames(2)
	assert_eq(_plots_grid(level).views().size(), before + 1)


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


## Bought beds take fixed slots and never re-centre the others: see test_bed_grid.gd.
func test_starting_beds_sit_centred_in_the_room() -> void:
	var level := await _open(PLANTATION_SCENE)
	var grid := _plots_grid(level)
	var centre := Vector3.ZERO
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
	assert_true(level.hud.is_dialogue_open())
	level.hud.dialogue_box.skip()
	level.hud.dialogue_box.choose(0)
	assert_false(Game.sim.raids.pending)
	assert_eq(Game.sim.economy.money, money - Game.sim.config.raids.bribe)


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
	level.hud.phone.open(Phone.APP_EMPIRE)
	assert_eq(level.hud.phone.current_app(), Phone.APP_EMPIRE)


func test_locked_strain_is_not_offered_for_planting() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bed := _plots_grid(level).view_for(0)
	var labels := bed.actions(level).map(func(action: UiAction) -> String: return action.label)
	var elite := Game.sim.config.find_strain("elite")
	for label: Variant in labels:
		assert_false(String(label).contains(elite.display_name))


## Boxes for an order must be of the strain the client asked for.
func _strain_for(order: Order) -> String:
	return order.strain_id if not order.strain_id.is_empty() else Game.sim.config.strain.id


func _accept_first_call() -> Order:
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.orders.first_order_hours + 0.01)))
	var order := Game.sim.orders.all()[0]
	Game.sim.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	return order


func test_phone_answers_calls_and_the_computer_ships_orders() -> void:
	var level := await _open(PLANTATION_SCENE)
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.orders.first_order_hours + 0.01)))
	var order := Game.sim.orders.all()[0]
	var desk := level.get_node("NavRegion/Computer") as ComputerDesk
	level.hud.toggle_phone()
	assert_true(level.hud.phone.visible)
	assert_eq(level.hud.phone.current_app(), Phone.APP_CALLS, "a ringing phone opens on the calls")
	level.hud.phone.answer(order.id, Orders.ACCEPT)
	assert_eq(order.status, Order.Status.ACCEPTED)
	level.hud.phone.close()
	await wait_process_frames(2)
	assert_false(desk.screen_glow.visible, "nothing to ship yet")
	for index: int in order.quantity:
		Game.sim.inventory.create(_strain_for(order), 100).packed = true
	await wait_process_frames(2)
	assert_true(desk.screen_glow.visible, "boxes ready: the computer glows")
	desk.interact(level)
	assert_true(level.hud.computer.visible)
	assert_eq(level.hud.computer.current_tab(), ComputerScreen.TAB_ORDERS)
	level.hud.computer.dispatch(order.id, Helper.ACTOR)
	assert_eq(order.status, Order.Status.IN_TRANSIT)
	await wait_process_frames(2)
	assert_true(level.jack.visible, "Jack stays on the farm")
	assert_false((level.get_node("Helper") as WorkerView).visible, "the helper is on the road")


func _phone_buttons(level: Level, prefix: String) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in level.hud.phone.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(prefix):
			found.append(button)
	return found


func test_phone_people_hire_and_shop_restock() -> void:
	var level := await _open(PLANTATION_SCENE)
	level.hud.phone.open(Phone.APP_PEOPLE)
	assert_eq(level.hud.phone.current_app(), Phone.APP_PEOPLE)
	var crew_hire := Game.sim.config.candidates().size() + Game.sim.config.packer_candidates.size()
	var courier_hire := Game.sim.config.courier_candidates.size()
	assert_eq(_phone_buttons(level, "Нанять").size(), crew_hire + courier_hire)
	level.hud.phone.hire("dave")
	level.hud.phone.hire("gladys")
	assert_eq(Game.sim.workers.definition().id, "dave")
	assert_true(Game.sim.packer.hired)
	assert_eq(_phone_buttons(level, "Уволить").size(), 2)
	assert_eq(_phone_buttons(level, "Нанять").size(), Game.sim.config.candidates().size() - 1 + courier_hire, "the rest of the crew can still be hired")
	assert_eq(_phone_buttons(level, "Место занято").size(), 0, "Gladys is the only packer")
	assert_gt(_phone_buttons(level, "Учить").size(), 0, "the helper's courses are listed")
	assert_null(level.get_node_or_null("Packer"), "the packer works at the stash, not in the bunker")
	level.hud.phone.fire("gladys")
	assert_false(Game.sim.packer.hired)
	Game.sim.economy.earn(1000)
	level.hud.phone.open_app(Phone.APP_SHOP)
	var restock := _phone_buttons(level, "Пополнить запас")
	assert_eq(restock.size(), 1)
	restock[0].pressed.emit()
	assert_false(Game.sim.supplies.pending_deliveries().is_empty())
	assert_eq(_phone_buttons(level, "Запас полный").size(), 1)


func test_dispatch_buttons_need_matching_packed_boxes() -> void:
	var level := await _open(PLANTATION_SCENE)
	var order := _accept_first_call()
	for index: int in order.quantity:
		Game.sim.inventory.create(_strain_for(order), order.min_quality - 1).packed = true
		Game.sim.inventory.create(_strain_for(order), 100)
	level.hud.open_computer()
	var buttons := level.hud.computer.dispatch_buttons(order.id)
	assert_gt(buttons.size(), 0)
	for button: Button in buttons:
		assert_true(button.disabled, "%s must be disabled without the right boxes" % button.text)
	assert_false(buttons.any(func(button: Button) -> bool: return button.text.contains("Отвезти самому")), "Jack does not drive")
	for index: int in order.quantity:
		Game.sim.inventory.create(_strain_for(order), order.min_quality).packed = true
	level.hud.computer.refresh()
	buttons = level.hud.computer.dispatch_buttons(order.id)
	assert_false(buttons[0].disabled, "the helper can take it now")
	buttons[0].pressed.emit()
	assert_eq(order.status, Order.Status.IN_TRANSIT)


func test_bench_packs_the_harvest_onto_the_shelf() -> void:
	Game.sim.apply(TravelCommand.new(DayCycle.STASH))
	var level := await _open(STASH_SCENE)
	var bench := level.get_node("NavRegion/Bench") as PackingBench
	var shelf := level.get_node("NavRegion/Shelf/Stock") as StockShelf
	for quality: int in [60, 70]:
		Game.sim.inventory.create(Game.sim.config.strain.id, quality).at_stash = true
	await wait_process_frames(2)
	assert_gt(bench.shown_heaps(), 0, "the loose harvest lies on the bench")
	assert_eq(shelf.shown_boxes(), 0, "nothing is boxed before packing")
	bench.interact(level)
	_choose(level, "Расфасовать")
	assert_true(Game.sim.packing.busy())
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.orders.pack_minutes_per_unit * 2.0 / 60.0 + 0.01)))
	await wait_process_frames(2)
	assert_eq(shelf.shown_boxes(), 2)
	assert_eq(bench.shown_heaps(), 0)
	assert_string_contains(level.hud.stock_label.text, "2 коробки")


func test_bench_heap_grows_with_the_unpacked_harvest() -> void:
	var level := await _open(STASH_SCENE)
	var bench := level.get_node("NavRegion/Bench") as PackingBench
	bench.show_pile(1)
	var small := bench.shown_heaps()
	assert_gt(small, 0)
	bench.show_pile(10)
	assert_gt(bench.shown_heaps(), small)
	bench.show_pile(0)
	assert_eq(bench.shown_heaps(), 0)


func test_parcel_waits_by_the_container_and_is_picked_up_by_clicking_it() -> void:
	var level := await _open(FIELD_SCENE)
	var parcel := level.get_node("NavRegion/Parcel") as ParcelBox
	var container := level.get_node("NavRegion/Container") as Node3D
	await wait_process_frames(2)
	assert_false(parcel.visual.visible)
	assert_eq(parcel.collision_layer, 0, "no parcel, nothing to click")
	Game.sim.apply(BuyCommand.new(Supplies.FERTILIZER, 2))
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.delivery_hours + 0.01)))
	await wait_process_frames(2)
	assert_true(parcel.visual.visible)
	assert_ne(parcel.collision_layer, 0)
	assert_lt(_flat_distance(parcel.global_position, container.global_position), 8.0, "the parcel is left at the container")
	parcel.interact(level)
	assert_eq(Game.sim.supplies.fertilizer, 2)
	await wait_process_frames(2)
	assert_false(parcel.visual.visible)


func test_container_goes_down_without_a_parcel_menu() -> void:
	var level := await _open(FIELD_SCENE)
	var container := level.get_node("NavRegion/Container") as ContainerEntrance
	Game.sim.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.config.delivery_hours + 0.01)))
	assert_string_contains(container.hover_text(), "посылка")
	container.interact(level)
	assert_false(level.hud.action_menu.visible, "the container no longer hands out parcels")
	await wait_until(func() -> bool: return SceneRouter.is_busy(), 3.0)
	assert_true(SceneRouter.is_busy(), "clicking the container starts the ride down")
	await wait_until(func() -> bool: return not SceneRouter.is_busy(), 5.0)
	SceneRouter.take_spawn()


func test_hired_couriers_wait_at_the_drop_point_off_the_farm_and_walk_the_road_with_orders() -> void:
	var level := await _open(FIELD_SCENE)
	var courier := level.get_node("CourierA") as CourierView
	await wait_process_frames(2)
	assert_false(courier.visible, "nobody hired yet")
	Game.sim.economy.earn(1000)
	Game.sim.apply(HireCourierCommand.new("harry"))
	var order := _accept_first_call()
	for index: int in order.quantity:
		Game.sim.inventory.create(_strain_for(order), 100).packed = true
	await wait_process_frames(2)
	var container := level.get_node("NavRegion/Container") as Node3D
	assert_true(courier.visible, "an idle courier stands about")
	assert_string_contains(courier.name_label.text, "Гарри · ждёт у дороги у поля")
	var drop := level.get_node("Routes/CourierIdle") as Node3D
	assert_lt(_flat_distance(courier.global_position, drop.global_position), 2.0, "he waits at the drop point")
	assert_gt(_flat_distance(courier.global_position, container.global_position), 25.0, "couriers must not learn where the farm is")
	assert_false((level.get_node("CourierB") as CourierView).visible)
	Game.sim.apply(DispatchCommand.new(order.id, "harry"))
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(Game.sim.couriers.trip_seconds("harry") * 0.5 / SimClock.GAME_SECONDS_PER_HOUR)))
	await wait_process_frames(2)
	assert_true(courier.visible)
	assert_string_contains(courier.name_label.text, "Гарри · везёт заказ")
	var road_z := (level.get_node("SpawnPoints/road_west") as Node3D).global_position.z
	assert_almost_eq(courier.global_position.z, road_z, 0.5, "half way out he is walking the main road")
	assert_gt(_flat_distance(courier.global_position, container.global_position), 25.0, "the trip never passes the farm")


func test_estate_is_large_with_the_lord_at_the_manor() -> void:
	var level := await _open(FIELD_SCENE)
	var manor := level.get_node("NavRegion/Manor") as Node3D
	var lord := level.get_node("NavRegion/Lord") as Node3D
	var container := level.get_node("NavRegion/Container") as Node3D
	var crops := level.get_node("NavRegion/Crops") as Node3D
	assert_lt(_flat_distance(lord.global_position, manor.global_position), 15.0, "the lord stands at his house")
	assert_gt(_flat_distance(container.global_position, manor.global_position), 80.0, "the container is far from the house")
	assert_gt(_flat_distance(crops.global_position, manor.global_position), 60.0, "the field is far from the house")
	assert_lt(_flat_distance(level.jack.global_position, lord.global_position), 4.0, "a new game starts beside the lord")


func test_wheat_field_is_drawn_as_one_multimesh() -> void:
	var level := await _open(FIELD_SCENE)
	var wheat := level.get_node("NavRegion/Crops/Wheat") as ScatterField
	assert_gt(wheat.instance_count(), 1000)
	assert_eq(level.get_node("NavRegion/Crops").find_children("*", "MeshInstance3D", false, false).size(), 1, "only the soil, no per-tuft meshes")


func test_lanes_meet_the_road_at_junction_tiles() -> void:
	var level := await _open(FIELD_SCENE)
	for pair: Array in [["DriveToManor", "JunctionManor"], ["PathToContainer", "JunctionContainer"]]:
		var lane := level.get_node("NavRegion/" + String(pair[0])) as Node3D
		var junction := level.get_node("NavRegion/" + String(pair[1])) as Node3D
		var nearest := INF
		for tile: Node in lane.get_children():
			var at := (tile as Node3D).global_position
			nearest = minf(nearest, Vector2(at.x, at.z).distance_to(Vector2(junction.global_position.x, junction.global_position.z)))
			assert_almost_eq(at.x, junction.global_position.x, 0.01, "%s runs straight into its junction" % pair[0])
		assert_almost_eq(nearest, 2.0, 0.05, "%s's last tile touches the junction tile" % pair[0])


func test_land_rover_drives_jack_to_the_container_and_back() -> void:
	var level := await _open(FIELD_SCENE)
	var rover := level.get_node("NavRegion/RoverManor") as LandRover
	var container_spot := level.get_node("Parking/Container") as ParkingSpot
	var labels := rover.actions(level).map(func(action: UiAction) -> String: return action.label)
	assert_eq(labels.size(), 4, "the other two estate spots, home and the stash")
	assert_true(labels.has("Ехать: к контейнеру"))
	assert_true(labels.any(func(label: String) -> bool: return label.begins_with("Ехать домой")))
	assert_true(labels.any(func(label: String) -> bool: return label.begins_with("Ехать в тайник")))
	rover.drive_to(level, container_spot)
	await wait_physics_frames(2)
	assert_true(rover.is_driving())
	assert_false(level.jack.visible, "Jack is in the car")
	var started := Time.get_ticks_msec()
	await wait_until(func() -> bool: return not rover.is_driving(), LandRover.DRIVE_SECONDS + 3.0)
	assert_false(rover.is_driving())
	assert_lt(float(Time.get_ticks_msec() - started) / 1000.0, LandRover.DRIVE_SECONDS + 1.0, "a quick drive")
	await wait_physics_frames(2)
	assert_true(level.jack.visible)
	assert_eq(rover.spot, container_spot)
	var other := level.get_node("NavRegion/RoverContainer") as LandRover
	assert_gt(_flat_distance(rover.global_position, other.global_position), 2.5, "it parks beside the other car")
	var container := level.get_node("NavRegion/Container") as Node3D
	assert_lt(_flat_distance(level.jack.global_position, container.global_position), 15.0)
	rover.drive_to(level, level.get_node("Parking/Manor") as ParkingSpot)
	await wait_until(func() -> bool: return not rover.is_driving(), LandRover.DRIVE_SECONDS + 3.0)
	assert_lt(_flat_distance(level.jack.global_position, (level.get_node("NavRegion/Lord") as Node3D).global_position), 15.0)


func test_world_clicks_do_nothing_while_driving() -> void:
	var level := await _open(FIELD_SCENE)
	var rover := level.get_node("NavRegion/RoverManor") as LandRover
	rover.drive_to(level, level.get_node("Parking/Road") as ParkingSpot)
	level._click(Vector2(800.0, 450.0))
	assert_false(level.jack.is_moving())
	await wait_until(func() -> bool: return not rover.is_driving(), LandRover.DRIVE_SECONDS + 3.0)
	var road_z := (level.get_node("SpawnPoints/road_west") as Node3D).global_position.z
	assert_lt(absf(level.jack.global_position.z - road_z), 6.0, "dropped off by the road")


func test_lord_ashcombe_waits_at_the_manor_and_talks() -> void:
	var level := await _open(FIELD_SCENE)
	var lord := level.get_node("NavRegion/Lord") as LordAshcombe
	assert_ne(lord.collision_layer, 0, "the lord can be clicked")
	assert_string_contains(lord.hover_text(), "Эшкомб")
	var money := Game.sim.economy.money
	lord.interact(level)
	assert_true(level.hud.is_dialogue_open())
	assert_eq(Game.sim.economy.money, money, "talking costs nothing")
	level.hud.dialogue_box.skip()
	assert_false(level.hud.is_dialogue_open())
