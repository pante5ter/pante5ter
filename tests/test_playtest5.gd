extends GutTest

## Playtest round 5: Reggie off screen, stale crate label, clicks through the phone, walking at x4,
## raids that took nothing, a gang with no time to answer, dark bunker that is not dark, gardeners
## gone without a word, crowded map, «7:5» for the rent, the Tab hint in the news.

const BALANCE_PATH: String = "res://content/balance.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const VIEWPORT_SIZE: Vector2i = Vector2i(1600, 900)
const SETTLE_FRAMES: int = 4
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func before_each() -> void:
	Game.new_game(7)
	Game.sim.first_day.skip()
	Game.sim.economy.money = 5000
	Game.is_running = false


func after_each() -> void:
	Game.set_speed(0)
	Game.is_running = false
	Game.new_game(7)


func _open(path: String) -> Level:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autoqfree(viewport)
	var level := (load(path) as PackedScene).instantiate() as Level
	viewport.add_child(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	return level


func _calm(money: int = 1000) -> SimState:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	return SimState.new(config, 3)


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(0.25, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / DAY))
		elapsed += step


func _click(viewport: Viewport, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	viewport.push_input(motion, true)
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = at
		button.global_position = at
		viewport.push_input(button, true)
		await wait_process_frames(2)


func _phone_button(level: Level, prefix: String) -> Button:
	for node: Node in level.hud.phone.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(prefix) and not button.disabled and button.is_visible_in_tree():
			return button
	return null


func _helper_view(level: Level) -> WorkerView:
	for node: Node in level.find_children("*", "WorkerView", true, false):
		var view := node as WorkerView
		if view.role == WorkerDef.HELPER:
			return view
	return null


# --- 1. «Реджи есть в подсказках, а на экране его нет»

func test_reggie_stands_in_the_field_with_jack_when_he_is_free() -> void:
	var field := await _open(FIELD_SCENE)
	await wait_process_frames(3)
	var reggie := _helper_view(field)
	assert_not_null(reggie, "the field has Reggie's figure")
	assert_true(reggie.visible, "free and on the farm: he is seen up top")
	assert_lt(reggie.global_position.distance_to(field.jack.global_position), 6.0, "he turns up next to Jack")


func test_reggie_is_not_in_the_field_while_he_is_away_or_busy_below() -> void:
	var field := await _open(FIELD_SCENE)
	Game.is_running = false
	var reggie := _helper_view(field)
	Game.sim.helper.leave_for_haul(Game.sim.clock.elapsed_game_seconds, Game.sim.clock.elapsed_game_seconds + HOUR)
	await wait_process_frames(2)
	assert_false(reggie.visible, "on the road")
	Game.sim.helper.away_reason = ""
	Game.sim.helper.task = Workers.Task.TREAT
	Game.sim.helper.task_plot_id = 0
	await wait_process_frames(2)
	assert_false(reggie.visible, "treating a bed in the bunker")


func test_reggie_keeps_close_to_jack_in_the_bunker() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var reggie := _helper_view(bunker)
	await wait_process_frames(2)
	assert_true(reggie.visible)
	bunker.jack.global_position = Vector3(5.0, 0.0, 3.0)
	await wait_seconds(4.0)
	assert_lt(reggie.global_position.distance_to(bunker.jack.global_position), 3.5, "he follows Jack around")


# --- 2 and 6. Crate label

func test_crate_label_is_gone_once_the_crates_are_gone() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var crates := bunker.get_node("NavRegion/Crates") as CrateStack
	Game.sim.inventory.create("basic", 60)
	await wait_process_frames(2)
	assert_true(crates.count_label.visible)
	assert_string_contains(crates.count_label.text, "1")
	assert_true(Game.sim.apply(HaulCommand.new(Helper.ACTOR)).ok)
	await wait_process_frames(2)
	assert_false(crates.count_label.visible, "nothing left in the bunker: no caption over an empty spot")


func test_new_harvest_shows_up_while_the_last_crates_are_on_the_road() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var crates := bunker.get_node("NavRegion/Crates") as CrateStack
	Game.sim.inventory.create("basic", 60)
	assert_true(Game.sim.apply(HaulCommand.new(Helper.ACTOR)).ok)
	for unit: int in 3:
		Game.sim.inventory.create("basic", 60)
	await wait_process_frames(2)
	assert_true(crates.count_label.visible)
	assert_string_contains(crates.count_label.text, "3", "the fresh crates are counted, not hidden behind «in transit»")
	assert_eq(crates.shown_crates(), 3)


# --- 3. «Нанял — и меня выкинуло наружу»

func test_a_phone_button_click_does_not_walk_jack_into_the_lift() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	await wait_process_frames(2)
	var start := bunker.jack.global_position
	bunker.hud.phone.open(Phone.APP_PEOPLE)
	await wait_process_frames(3)
	var hire := _phone_button(bunker, "Нанять")
	assert_not_null(hire)
	var scroll := bunker.hud.phone.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	scroll.ensure_control_visible(hire)
	await wait_process_frames(3)
	await _click(bunker.get_viewport(), hire.get_global_rect().get_center())
	await wait_process_frames(10)
	assert_eq(Game.sim.workers.gardeners().size(), 1, "the click hired")
	assert_false(bunker.jack.is_moving(), "and did not reach the world behind the phone")
	assert_almost_eq(bunker.jack.global_position.distance_to(start), 0.0, 0.05)
	assert_false(SceneRouter.is_busy(), "nobody rides the lift")


func test_a_world_click_beside_the_phone_still_walks_jack() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	bunker.hud.phone.open(Phone.APP_PEOPLE)
	await wait_process_frames(3)
	var phone_rect := bunker.hud.phone.get_global_rect()
	var camera := bunker.get_viewport().get_camera_3d()
	var floor_spot := Vector2.INF
	for offset: Vector3 in [Vector3(-3.0, 0.0, 0.0), Vector3(3.0, 0.0, 0.0), Vector3(0.0, 0.0, 3.0), Vector3(0.0, 0.0, -3.0)]:
		var on_screen := camera.unproject_position(bunker.jack.global_position + offset)
		if not phone_rect.has_point(on_screen) and not bunker._pick(on_screen).is_empty():
			floor_spot = on_screen
			break
	assert_ne(floor_spot, Vector2.INF, "some floor next to Jack is visible beside the phone")
	await _click(bunker.get_viewport(), floor_spot)
	await wait_process_frames(4)
	assert_true(bunker.jack.is_moving(), "positive control: the world outside the phone is clickable")


# --- 4. «Ускорение не действует на ходьбу»

func test_walking_speeds_up_with_the_game_clock() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var distances: Array[float] = []
	for speed: int in [0, 2]:
		Game.set_speed(speed)
		bunker.jack.stop()
		bunker.jack.global_position = Vector3(-6.0, 0.0, -2.0)
		await wait_physics_frames(2)
		var from := bunker.jack.global_position
		bunker.jack.move_to(Vector3(6.0, 0.0, -2.0))
		await wait_physics_frames(20)
		distances.append(bunker.jack.global_position.distance_to(from))
	assert_gt(distances[1], distances[0] * 3.0, "x4 walks about four times as far")


# --- 5. «Написано: напали, а товар не пропал»

func test_raid_news_says_how_many_crates_the_gang_took() -> void:
	var state := _calm()
	for unit: int in 4:
		state.inventory.create("basic", 60)
	var stash_crate := state.inventory.create("basic", 60)
	stash_crate.at_stash = true
	state.raids.pending = true
	state.raids.deadline = state.clock.elapsed_game_seconds + HOUR
	state.raids.attach_helper(null)
	_advance(state, 1.25)
	var resolved := state.event_log.of_type(EventLog.RAID_RESOLVED)
	assert_eq(resolved.size(), 1)
	assert_eq(int(resolved[0].data["taken"]), 4)
	var text := UiText.announcement(resolved[0], state)
	assert_string_contains(text, "4", "the news names the loss")
	assert_string_contains(text, "тайник", "and says the stash is safe")
	assert_eq(state.inventory.count(), 1, "the stash crate is still there")


func test_raid_that_found_nothing_does_not_claim_a_robbery() -> void:
	var state := _calm()
	state.raids.pending = true
	state.raids.deadline = state.clock.elapsed_game_seconds + HOUR
	state.raids.attach_helper(null)
	_advance(state, 1.25)
	var text := UiText.announcement(state.event_log.of_type(EventLog.RAID_RESOLVED)[0], state)
	assert_false(text.contains("обчистили всё"), "nothing was there to take: %s" % text)


func test_give_half_offers_half_of_the_farm_crates_not_the_stash() -> void:
	Game.sim.raids.pending = true
	Game.sim.raids.deadline = Game.sim.clock.elapsed_game_seconds + HOUR
	for unit: int in 4:
		Game.sim.inventory.create("basic", 60)
	for unit: int in 6:
		Game.sim.inventory.create("basic", 60).at_stash = true
	assert_eq(RaiderGang.choice_labels(Game.sim)[1], "Отдать половину товара с фермы (2 шт.)")


# --- 7. «Вредители пропали после полива»

func test_watering_never_clears_pests() -> void:
	var state := _calm()
	assert_true(state.apply(PlantCommand.new(0)).ok)
	assert_true(state.problems.force(0, Problems.PESTS, 0.0))
	assert_true(state.apply(WaterCommand.new(0)).ok)
	assert_eq(state.grow.plot(0).problem, Problems.PESTS)


func test_reggie_curing_pests_is_news() -> void:
	var state := _calm()
	state.supplies._stock(Supplies.PESTICIDE, 1)
	assert_true(state.apply(PlantCommand.new(0)).ok)
	state.apply(WaterCommand.new(0))
	state.problems.force(0, Problems.PESTS, 0.0)
	_advance(state, 1.0)
	var treated := state.event_log.of_type(EventLog.PLOT_TREATED)
	assert_eq(treated.size(), 1, "Reggie used the pesticide")
	assert_string_contains(UiText.announcement(treated[0], state), "Реджи")


# --- 8. «Подошёл к гопникам — не успел выбрать»

func test_the_gang_waits_long_enough_to_walk_up_and_choose() -> void:
	assert_gte(_balance.raids.deadline_hours * _balance.real_seconds_per_game_day / 24.0, 60.0, "at least a real minute at x1")


func test_a_raid_drops_the_game_back_to_x1() -> void:
	var event := SimEvent.new(EventLog.RAID_STARTED, 0.0, PackedStringArray(), {})
	assert_true(Stories.is_beat(event))


func test_talking_to_the_gang_stops_the_clock_until_jack_answers() -> void:
	var field := await _open(FIELD_SCENE)
	Game.is_running = true
	Game.sim.inventory.create("basic", 60)
	Game.sim.raids.pending = true
	Game.sim.raids.deadline = Game.sim.clock.elapsed_game_seconds + HOUR
	var gang := field.get_node("NavRegion/Raiders") as RaiderGang
	gang.interact(field)
	assert_true(field.hud.is_dialogue_open())
	assert_false(Game.is_running, "the gang is not going anywhere while Jack talks")
	field.hud.dialogue_box.skip()
	field.hud.dialogue_box.choose(0)
	assert_false(Game.sim.raids.pending, "the choice reached the sim")
	assert_eq(String(Game.sim.event_log.of_type(EventLog.RAID_RESOLVED)[0].data["outcome"]), "paid")


# --- 9. «Выключил свет — не видно»

func test_the_bunker_goes_dark_when_the_lights_are_off() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	Game.sim.apply(PlantCommand.new(0))
	var plot := bunker.get_node("NavRegion/PlotsGrid").find_children("*", "PlotView", true, false)[0] as PlotView
	var grow_light := plot.get_node("GrowLight") as OmniLight3D
	var environment := (bunker.get_node("WorldEnvironment") as WorldEnvironment).environment
	await wait_process_frames(2)
	var lit := environment.ambient_light_energy
	assert_true(grow_light.visible)
	assert_true(Game.sim.apply(LieLowCommand.new(true)).ok)
	await wait_process_frames(2)
	assert_false(grow_light.visible, "grow lamps off")
	assert_lt(environment.ambient_light_energy, lit * 0.5, "the room is visibly darker")
	Game.sim.apply(LieLowCommand.new(false))
	await wait_process_frames(2)
	assert_true(grow_light.visible)
	assert_almost_eq(environment.ambient_light_energy, lit, 0.001)


func test_a_burned_lamp_leaves_its_bed_dark() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.problems.force(0, Problems.LAMP, 0.0)
	var plot := bunker.get_node("NavRegion/PlotsGrid").find_children("*", "PlotView", true, false)[0] as PlotView
	await wait_process_frames(2)
	assert_false((plot.get_node("GrowLight") as OmniLight3D).visible)


# --- 10. «Работник снова пропал незаметно»

func _hire_and_go_broke(state: SimState) -> Gardener:
	assert_true(state.apply(HireWorkerCommand.new("dave")).ok)
	state.economy.money = 0
	return state.workers.find("dave")


func test_an_unpaid_gardener_gives_a_day_before_he_quits() -> void:
	var state := _calm()
	_hire_and_go_broke(state)
	_advance(state, 24.25)
	assert_true(state.workers.is_hired("dave"), "one missed wage: he grumbles and stays")
	assert_eq(state.event_log.of_type(EventLog.WORKER_UNPAID).size(), 1)
	_advance(state, 24.0 * float(state.config.unpaid_days_before_quit - 1))
	assert_false(state.workers.is_hired("dave"), "after %d missed days he is gone" % state.config.unpaid_days_before_quit)
	assert_eq(state.event_log.of_type(EventLog.WORKER_QUIT).size(), 1)


func test_money_in_time_pays_the_debt_and_keeps_him() -> void:
	var state := _calm()
	_hire_and_go_broke(state)
	_advance(state, 24.25)
	state.economy.money = 1000
	_advance(state, 24.0)
	assert_true(state.workers.is_hired("dave"))
	var wage := state.config.find_worker("dave").daily_wage
	var paid := state.event_log.of_type(EventLog.WORKER_PAID).filter(func(event: SimEvent) -> bool: return String(event.data["worker_id"]) == "dave")
	assert_eq(paid.size(), 1)
	assert_eq(int((paid[0] as SimEvent).data["wage"]), wage * 2, "today's wage plus yesterday's debt")
	assert_eq(state.workers.find("dave").wage_debt, 0)


func test_gardener_debt_survives_save_and_load() -> void:
	var state := _calm()
	_hire_and_go_broke(state)
	_advance(state, 24.25)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.workers.find("dave").wage_debt, state.workers.find("dave").wage_debt)
	assert_gt(loaded.workers.find("dave").wage_debt, 0)


func test_leaving_and_unpaid_gardeners_get_a_banner() -> void:
	var state := _calm()
	_hire_and_go_broke(state)
	_advance(state, 24.0 * float(state.config.unpaid_days_before_quit) + 0.25)
	for type: String in [EventLog.WORKER_UNPAID, EventLog.WORKER_QUIT]:
		var event := state.event_log.of_type(type)[0]
		var alert := Alert.from_event(event, state)
		assert_not_null(alert, "%s is shown in the top banner" % type)
		assert_string_contains(alert.title + alert.body, state.config.find_worker("dave").display_name)


# --- 11. «Подписи на карте наезжают друг на друга»

func test_map_captions_do_not_overlap() -> void:
	var font := ThemeDB.fallback_font
	for map_size: Vector2 in [Vector2(300.0, 236.0), Vector2(360.0, 236.0)]:
		var boxes := PhoneMap.caption_boxes(map_size, font)
		assert_gt(boxes.size(), 3)
		for a: int in boxes.size():
			assert_true(Rect2(Vector2.ZERO, map_size).encloses(boxes[a]), "caption %d stays on the map at %s" % [a, map_size])
			for b: int in range(a + 1, boxes.size()):
				assert_false(boxes[a].intersects(boxes[b]), "captions %d and %d overlap at %s" % [a, b, map_size])


# --- 12. «Аренда лорду через 7:5»

func test_durations_read_as_minutes_and_seconds_in_words() -> void:
	var state := _calm()
	var real_second := DAY / state.config.real_seconds_per_game_day
	assert_eq(UiText.real_duration(real_second * 425.0, state), "7 мин 5 с")
	assert_eq(UiText.real_duration(real_second * 420.0, state), "7 мин")
	assert_eq(UiText.real_duration(real_second * 45.0, state), "45 с")
	assert_eq(UiText.real_duration(-5.0, state), "0 с")


# --- News: no «(Tab)» hint

func test_client_calls_in_the_news_carry_no_key_hint() -> void:
	var state := _calm()
	state.orders.inject(2, 0, 300, 5.0, 0.0, false, 0.0)
	state.orders.inject(2, 0, 600, 5.0, 0.0, true, 0.0)
	for event: SimEvent in state.event_log.of_type(EventLog.ORDER_RECEIVED):
		var text := UiText.announcement(event, state)
		assert_false(text.is_empty())
		assert_false(text.contains("Tab"), text)
