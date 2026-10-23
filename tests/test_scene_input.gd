extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const TEST_SAVE_PATH: String = "user://test_hud_save.json"
const SETTLE_FRAMES: int = 4
const WALK_TIMEOUT: float = 12.0
const REACH_TOLERANCE: float = 0.6


func before_each() -> void:
	Game.new_game(7)
	Game.is_running = false
	Game.save_path = TEST_SAVE_PATH


func after_each() -> void:
	Game.is_running = false
	Game.save_path = Game.DEFAULT_SAVE_PATH
	Game.new_game(7)
	SceneRouter.take_spawn()
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _mouse_button(level: Level, at: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	level._unhandled_input(button)


func _click_world(level: Level, point: Vector3) -> void:
	var at := level.camera_rig.camera.unproject_position(point)
	_mouse_button(level, at, true)
	_mouse_button(level, at, false)


func _drag(level: Level, from: Vector2, to: Vector2) -> void:
	_mouse_button(level, from, true)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	level._unhandled_input(motion)
	_mouse_button(level, to, false)


func _press_key(target: Node, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	target._unhandled_input(key)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _interactables(root: Node) -> Array[Interactable]:
	var found: Array[Interactable] = []
	for node: Node in root.find_children("*", "", true, false):
		if node is Interactable:
			found.append(node as Interactable)
	return found


func _path_end(level: Level, from: Vector3, to: Vector3) -> Vector3:
	var path := NavigationServer3D.map_get_path(level.get_world_3d().navigation_map, from, to, true)
	return path[path.size() - 1] if not path.is_empty() else from


func _assert_reachable(level: Level, from: Vector3, to: Vector3, what: String) -> void:
	assert_lt(_flat_distance(_path_end(level, from, to), to), REACH_TOLERANCE, "%s is not reachable" % what)


func test_every_field_interactable_can_be_reached_from_start() -> void:
	var level := await _open(FIELD_SCENE)
	var start := level.jack.global_position
	var targets := _interactables(level)
	assert_eq(targets.size(), 3)
	for target: Interactable in targets:
		_assert_reachable(level, start, target.approach_position(), target.name)
	_assert_reachable(level, start, (level.get_node("SpawnPoints/from_elevator") as Node3D).global_position, "lift exit")


func test_every_bed_and_work_spot_can_be_reached_in_the_plantation() -> void:
	var level := await _open(PLANTATION_SCENE)
	var start := level.jack.global_position
	var targets := _interactables(level).filter(func(target: Interactable) -> bool: return not target is WorkerTalk)
	assert_eq(targets.size(), Game.sim.grow.plots().size() + 1)
	for target: Interactable in targets:
		_assert_reachable(level, start, target.approach_position(), target.name)
		if target is PlotView:
			_assert_reachable(level, start, target.approach_position() + WorkerView.WORK_OFFSET, "work spot of %s" % target.name)
	_assert_reachable(level, start, (level.get_node("SpawnPoints/worker_idle") as Node3D).global_position, "worker idle spot")


func test_clicking_the_ground_walks_jack_there() -> void:
	var level := await _open(FIELD_SCENE)
	var target := level.jack.global_position + Vector3(3.0, 0.0, 1.0)
	_click_world(level, target)
	await wait_until(func() -> bool: return not level.jack.is_moving(), WALK_TIMEOUT)
	assert_lt(_flat_distance(level.jack.global_position, target), REACH_TOLERANCE)


func test_clicking_the_stash_walks_over_and_opens_its_menu() -> void:
	var level := await _open(FIELD_SCENE)
	var stash := level.get_node("NavRegion/Stash") as Stash
	_click_world(level, stash.global_position + Vector3(0.0, 0.4, 0.0))
	await wait_until(func() -> bool: return level.hud.action_menu.visible, WALK_TIMEOUT)
	assert_true(level.hud.action_menu.visible)
	assert_lt(_flat_distance(level.jack.global_position, stash.approach_position()), REACH_TOLERANCE)


func test_clicking_the_candidate_opens_a_hiring_menu() -> void:
	var level := await _open(FIELD_SCENE)
	var candidate := level.get_node("NavRegion/Candidate") as WorkerCandidate
	_click_world(level, candidate.global_position + Vector3(0.0, 0.9, 0.0))
	await wait_until(func() -> bool: return level.hud.action_menu.visible, WALK_TIMEOUT)
	assert_false(Game.sim.workers.hired)
	assert_true(level.hud.action_menu.choose_label("Нанять"))
	assert_true(Game.sim.workers.hired)


func test_clicking_a_bed_walks_over_and_offers_planting() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bed := (level.get_node("NavRegion/PlotsGrid") as PlotsGrid).view_for(4)
	_click_world(level, bed.global_position + Vector3(0.0, 0.3, 0.0))
	await wait_until(func() -> bool: return level.hud.action_menu.visible, WALK_TIMEOUT)
	assert_lt(_flat_distance(level.jack.global_position, bed.approach_position()), REACH_TOLERANCE)
	assert_true(level.hud.action_menu.choose_label("Посадить"))
	assert_eq(Game.sim.grow.plot(4).stage, Plot.Stage.SEED)


func test_clicking_the_world_while_a_menu_is_open_only_closes_it() -> void:
	var level := await _open(FIELD_SCENE)
	var actions: Array[UiAction] = []
	level.hud.show_actions("test", actions)
	var start := level.jack.global_position
	_click_world(level, start + Vector3(3.0, 0.0, 0.0))
	await wait_physics_frames(5)
	assert_false(level.hud.action_menu.visible)
	assert_false(level.jack.is_moving())
	assert_lt(_flat_distance(level.jack.global_position, start), 0.01)


func test_dragging_pans_the_camera_without_walking() -> void:
	var level := await _open(FIELD_SCENE)
	var camera_before := level.camera_rig.position
	var jack_before := level.jack.global_position
	_drag(level, Vector2(800.0, 450.0), Vector2(600.0, 450.0))
	await wait_physics_frames(5)
	assert_gt(level.camera_rig.position.distance_to(camera_before), 1.0)
	assert_false(level.jack.is_moving())
	assert_lt(_flat_distance(level.jack.global_position, jack_before), 0.01)


func test_tab_opens_the_phone_and_buying_there_orders_a_delivery() -> void:
	var level := await _open(FIELD_SCENE)
	_press_key(level.hud, KEY_TAB)
	assert_true(level.hud.phone.visible)
	level.hud.phone.buy(Supplies.FERTILIZER, 1)
	assert_eq(Game.sim.supplies.pending_deliveries().size(), 1)
	assert_string_contains(level.hud.message_label.text, "Доставка")
	_press_key(level.hud, KEY_TAB)
	assert_false(level.hud.phone.visible)


func test_escape_pauses_time_and_closes_menus_first() -> void:
	var level := await _open(FIELD_SCENE)
	Game.is_running = true
	var actions: Array[UiAction] = []
	level.hud.show_actions("test", actions)
	_press_key(level.hud, KEY_ESCAPE)
	assert_false(level.hud.action_menu.visible)
	assert_false(level.hud.pause_menu.visible)
	_press_key(level.hud, KEY_ESCAPE)
	assert_true(level.hud.pause_menu.visible)
	assert_false(Game.is_running)
	var clock := Game.sim.clock.elapsed_game_seconds
	await wait_process_frames(5)
	assert_eq(Game.sim.clock.elapsed_game_seconds, clock)
	_press_key(level.hud, KEY_ESCAPE)
	assert_false(level.hud.pause_menu.visible)
	assert_true(Game.is_running)


func test_lift_exit_spawns_jack_next_to_the_container() -> void:
	SceneRouter.expect_spawn("from_elevator")
	var level := await _open(FIELD_SCENE)
	var exit := (level.get_node("SpawnPoints/from_elevator") as Node3D).global_position
	assert_lt(_flat_distance(level.jack.global_position, exit), 0.01)
	assert_eq(SceneRouter.take_spawn(), "", "spawn request must be consumed once")


func test_unknown_spawn_falls_back_to_default() -> void:
	SceneRouter.expect_spawn("nowhere")
	var level := await _open(PLANTATION_SCENE)
	var exit := (level.get_node("SpawnPoints/from_elevator") as Node3D).global_position
	assert_lt(_flat_distance(level.jack.global_position, exit), 0.01)


func test_hud_shows_the_state_and_the_goal() -> void:
	var level := await _open(FIELD_SCENE)
	await wait_process_frames(2)
	var hud := level.hud
	assert_eq(hud.money_label.text, UiText.money(Game.sim.economy.money))
	assert_string_contains(hud.objective_label.text, "посади")
	assert_null(hud.get_node_or_null("Controls"), "control hints moved to the Esc menu")
	assert_eq(hud.worker_label.text, "Работника нет")


func test_hud_announces_when_the_worker_quits() -> void:
	var level := await _open(FIELD_SCENE)
	await wait_process_frames(2)
	Game.sim.economy.money = Game.sim.workers.definition().daily_wage
	Game.sim.apply(HireWorkerCommand.new())
	Game.sim.apply(AdvanceTimeCommand.new(Game.sim.config.real_seconds_per_game_day * 1.01))
	await wait_process_frames(2)
	assert_false(Game.sim.workers.hired)
	assert_string_contains(level.hud.message_label.text, "ушёл")


func test_hud_keeps_quiet_about_old_news_after_loading() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.apply(WaterCommand.new(0))
	Game.sim.apply(AdvanceTimeCommand.new(Game.sim.config.real_seconds_per_game_day))
	assert_eq(Game.save_game(), OK)
	Game.new_game(8)
	await wait_process_frames(2)
	level.hud.show_message("")
	assert_eq(Game.load_game(), OK)
	await wait_process_frames(2)
	assert_eq(level.hud.message_label.text, "")


func test_f5_and_f9_save_and_load_without_touching_the_players_save() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.apply(PlantCommand.new(2))
	var saved := Game.sim.to_json()
	_press_key(level.hud, KEY_F5)
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_string_contains(level.hud.message_label.text, "сохранена")
	Game.new_game(99)
	_press_key(level.hud, KEY_F9)
	assert_eq(Game.sim.to_json(), saved)
	assert_string_contains(level.hud.message_label.text, "загружена")


func test_camera_turns_zooms_and_stays_in_bounds() -> void:
	var level := await _open(FIELD_SCENE)
	var rig := level.camera_rig
	var yaw_before := rig.rotation.y
	_press_key(rig, KEY_Q)
	for step: int in 20:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		rig._unhandled_input(wheel)
	await wait_seconds(1.0)
	assert_almost_eq(angle_difference(yaw_before, rig.rotation.y), PI / 2.0, 0.05)
	assert_almost_eq(rig.camera.size, rig.zoom_max, 0.5)
	rig.focus(Vector3(500.0, 0.0, -500.0))
	assert_eq(rig.position.x, rig.bounds.end.x)
	assert_eq(rig.position.z, rig.bounds.position.y)


func test_beds_show_one_model_set_per_stage() -> void:
	var level := await _open(PLANTATION_SCENE)
	var bed := (level.get_node("NavRegion/PlotsGrid") as PlotsGrid).view_for(0)
	await wait_process_frames(2)
	assert_eq(_visible_stage_sets(bed), 0)
	Game.sim.apply(PlantCommand.new(0))
	await wait_process_frames(2)
	assert_eq(_visible_stage_sets(bed), 1)
	assert_string_contains(bed.label.text, "СУХО")


func _visible_stage_sets(bed: PlotView) -> int:
	var count := 0
	for holder: Node in bed.plant.get_children():
		if (holder as Node3D).visible:
			count += 1
	return count
