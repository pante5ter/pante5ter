extends GutTest

## Playtest round 5, UI: who is on the road and when they are back, the shop and the people on
## the computer, where to hire, and what «Пополнить запас» is paying for.

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
	Game.is_running = false
	return level


func _calm(money: int = 5000) -> SimState:
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


func _accepted_order(state: SimState) -> Order:
	var order := state.orders.inject(1, 0, 200, 5.0, 0.0, false, state.clock.elapsed_game_seconds)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	state.inventory.create(state.config.strain.id, 60).packed = true
	return order


func _trip_of(state: SimState, who: String) -> RoadText.Trip:
	for trip: RoadText.Trip in RoadText.trips(state):
		if trip.who == who:
			return trip
	return null


func _buttons(root: Node, prefix: String) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and not button.disabled and button.text.begins_with(prefix):
			found.append(button)
	return found


func _texts(root: Node) -> String:
	var parts := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).is_visible_in_tree():
			parts.append((node as Label).text)
	return "\n".join(parts)


# --- 1. People on the road

func test_nobody_is_on_the_road_at_the_start() -> void:
	assert_eq(RoadText.trips(_calm()).size(), 0)


func test_reggie_hauling_crates_shows_where_and_when_he_is_back() -> void:
	var state := _calm()
	state.inventory.create(state.config.strain.id, 60)
	assert_true(state.apply(HaulCommand.new(Helper.ACTOR)).ok)
	var trip := _trip_of(state, Helper.ACTOR)
	assert_not_null(trip, "Reggie is on the road")
	assert_eq(trip.name, "Реджи")
	assert_string_contains(trip.doing, "тайник")
	var left := state.helper.away_until - state.clock.elapsed_game_seconds
	assert_eq(trip.countdown(state), UiText.real_duration(left, state), "the countdown is his way there and back")
	assert_string_contains(trip.tooltip(state), "вернётся через")


func test_reggie_on_a_delivery_and_on_a_course() -> void:
	var state := _calm()
	var order := _accepted_order(state)
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)
	assert_string_contains(_trip_of(state, Helper.ACTOR).doing, "заказ #%d" % order.id)
	var course := _calm()
	assert_true(course.apply(LearnSkillCommand.new("driving")).ok)
	assert_string_contains(_trip_of(course, Helper.ACTOR).doing, course.config.find_skill("driving").display_name)


func test_a_courier_on_a_delivery_and_on_his_way_back() -> void:
	var state := _calm()
	var courier := state.config.courier_candidates[0]
	assert_true(state.apply(HireCourierCommand.new(courier.id)).ok)
	var order := _accepted_order(state)
	assert_true(state.apply(DispatchCommand.new(order.id, courier.id)).ok)
	var trip := _trip_of(state, courier.id)
	assert_not_null(trip)
	assert_eq(trip.name, courier.display_name)
	assert_string_contains(trip.doing, "заказ #%d" % order.id)
	assert_eq(trip.countdown(state), UiText.real_duration(state.couriers.busy_until[courier.id] - state.clock.elapsed_game_seconds, state))
	_advance(state, state.couriers.trip_seconds(courier.id) / HOUR + 0.25)
	var back := _trip_of(state, courier.id)
	if state.couriers.hired.has(courier.id):
		assert_not_null(back, "the drive back still counts")
		assert_string_contains(back.doing, "обратно")
	_advance(state, state.couriers.trip_seconds(courier.id) / HOUR)
	assert_null(_trip_of(state, courier.id), "home again: off the strip")


## The drive itself skips the clock, so Jack is seen mid-trip only in a save made on the road.
func test_jack_mid_trip_counts_down_to_his_arrival() -> void:
	var state := _calm()
	assert_true(state.day.start_trip(DayCycle.HOME, state.clock.elapsed_game_seconds, "test").ok)
	var trip := _trip_of(state, DayCycle.JACK)
	assert_not_null(trip)
	assert_eq(trip.name, "Джек")
	assert_string_contains(trip.doing, "домой")
	assert_string_contains(trip.tooltip(state), "приедет через")
	assert_eq(trip.countdown(state), UiText.real_duration(state.day.trip_arrives_at - state.clock.elapsed_game_seconds, state))


func test_jack_mid_trip_with_the_crates() -> void:
	var state := _calm()
	var now := state.clock.elapsed_game_seconds
	state.inventory.create(state.config.strain.id, 60)
	assert_true(state.stash.load_for_jack(now, now + state.day.travel_seconds(), "test").ok)
	assert_true(state.day.start_trip(DayCycle.STASH, now, "test").ok)
	assert_string_contains(_trip_of(state, DayCycle.JACK).doing, "ящики")


func test_jack_on_a_delivery_from_an_old_save() -> void:
	var state := _calm()
	state.couriers.busy_until[Couriers.JACK] = state.clock.elapsed_game_seconds + HOUR
	var trip := _trip_of(state, DayCycle.JACK)
	assert_not_null(trip)
	assert_string_contains(trip.tooltip(state), "вернётся через")
	assert_eq(RoadText.trips(state).size(), 1, "not counted twice as a courier")


func test_hud_strip_appears_with_someone_away_and_hides_when_all_are_back() -> void:
	var field := await _open(FIELD_SCENE)
	var strip := field.hud.road_panel
	await wait_process_frames(3)
	assert_false(strip.visible, "nobody away: nothing on screen")
	Game.sim.inventory.create(Game.sim.config.strain.id, 60)
	assert_true(Game.sim.apply(HaulCommand.new(Helper.ACTOR)).ok)
	await wait_seconds(RoadPanel.REFRESH_SECONDS * 2.0)
	assert_true(strip.visible)
	var text := _texts(strip)
	assert_string_contains(text, "Реджи")
	assert_string_contains(text, UiText.real_duration(Game.sim.helper.away_until - Game.sim.clock.elapsed_game_seconds, Game.sim))
	assert_eq(strip.row_count(), 1)
	assert_string_contains(strip.row_tooltip(0), "тайник")
	Game.sim.apply(AdvanceTimeCommand.new((Game.sim.helper.away_until - Game.sim.clock.elapsed_game_seconds + HOUR) * Game.sim.config.real_seconds_per_game_day / DAY))
	await wait_seconds(RoadPanel.REFRESH_SECONDS * 2.0)
	assert_true(Game.sim.helper.present())
	assert_false(strip.visible, "everyone back: the strip is gone")


# --- 2. The shop on the computer

func test_the_computer_has_a_shop_with_the_phone_goods() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var computer := bunker.hud.computer
	bunker.hud.open_computer()
	computer.open(ComputerScreen.TAB_SHOP)
	await wait_process_frames(2)
	assert_eq(computer.current_tab(), ComputerScreen.TAB_SHOP)
	assert_gt(_buttons(computer, "Купить 1").size(), 0, "the same goods as the phone")
	var restock := _buttons(computer, "Пополнить запас")
	assert_eq(restock.size(), 1)
	restock[0].pressed.emit()
	assert_false(Game.sim.supplies.pending_deliveries().is_empty(), "the computer button goes through the same command")
	await wait_process_frames(2)
	assert_eq(_buttons(computer, "Пополнить запас").size(), 0, "the screen refreshes at once: nothing left to restock")


# --- 3. Where to hire

func test_the_computer_has_a_people_tab_that_hires_gardeners() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var computer := bunker.hud.computer
	bunker.hud.open_computer()
	computer.open(ComputerScreen.TAB_PEOPLE)
	await wait_process_frames(2)
	var hire := _buttons(computer, "Нанять")
	assert_gt(hire.size(), 0)
	hire[0].pressed.emit()
	assert_eq(Game.sim.workers.gardeners().size(), 1)


func test_couriers_tab_points_gardeners_to_the_people_tab() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	var computer := bunker.hud.computer
	bunker.hud.open_computer()
	computer.open(ComputerScreen.TAB_COURIERS)
	await wait_process_frames(2)
	assert_string_contains(_texts(computer), "«Люди»")


func test_crew_line_says_where_to_hire_while_there_are_no_gardeners() -> void:
	var state := _calm()
	assert_string_contains(StoryText.crew_status(state), "«Люди»")
	assert_true(state.apply(HireWorkerCommand.new("dave")).ok)
	assert_false(StoryText.crew_status(state).contains("«Люди»"), "hired: no more nagging")


func test_hiring_objective_names_the_place() -> void:
	var state := _calm()
	state.apply(PlantCommand.new(0))
	state.apply(WaterCommand.new(0))
	var text := UiText.objective(state)
	assert_string_contains(text, "Найми")
	assert_string_contains(text, "«Люди»")
	assert_string_contains(text, "компьютер")


func test_no_courier_line_names_the_couriers_tab() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.helper = null
	config.first_day = null
	var state := SimState.new(config, 3)
	var order := _accepted_order(state)
	Game.sim = state
	var computer := ComputerScreen.new()
	add_child_autoqfree(computer)
	computer.open(ComputerScreen.TAB_ORDERS)
	assert_eq(state.couriers.drivers().size(), 0)
	assert_not_null(order)
	assert_string_contains(_texts(computer), "«Курьеры»")


# --- 4. What the restock buys

func test_restock_breakdown_adds_up_to_the_price() -> void:
	var state := _calm()
	var total := 0
	for line: PhoneShop.Shortfall in PhoneShop.shortfalls(state):
		total += line.cost()
	assert_eq(total, state.supplies.basket_cost())
	assert_gt(total, 0)


func test_restock_breakdown_drops_what_is_already_there_or_on_the_way() -> void:
	var state := _calm()
	var keep := state.config.restock_basket[Supplies.FERTILIZER]
	assert_true(state.apply(BuyCommand.new(Supplies.FERTILIZER, keep)).ok)
	for line: PhoneShop.Shortfall in PhoneShop.shortfalls(state):
		if line.item == Supplies.FERTILIZER:
			assert_eq(line.need, 0, "bought and on the way: nothing more to buy")
			assert_eq(line.have, keep)
	var total := 0
	for line: PhoneShop.Shortfall in PhoneShop.shortfalls(state):
		total += line.cost()
	assert_eq(total, state.supplies.basket_cost())


func test_shop_shows_each_missing_item_with_quantity_and_cost() -> void:
	var field := await _open(FIELD_SCENE)
	field.hud.phone.open(Phone.APP_SHOP)
	await wait_process_frames(2)
	var text := _texts(field.hud.phone)
	assert_string_contains(text, "только недостающ")
	for line: PhoneShop.Shortfall in PhoneShop.shortfalls(Game.sim):
		if line.need > 0:
			assert_string_contains(text, "%d × %s = %s" % [line.need, UiText.money(line.price), UiText.money(line.cost())])
