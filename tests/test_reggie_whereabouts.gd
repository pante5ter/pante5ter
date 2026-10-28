extends GutTest

## Playtest: "Реджи куда-то пропал". He must always come back, and the crew line must say where he is.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(courier_trouble: bool = false) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.first_day = null
	config.starting_money = 5000
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.director = _balance.director.duplicate() as DirectorDef
	if courier_trouble:
		config.director.quiet_real_seconds = 10.0
		config.director.urgent_order_weight = 0.0
		config.director.lord_visit_weight = 0.0
		config.director.rumour_weight = 0.0
		config.director.breakdown_weight = 0.0
		config.director.story_weight = 0.0
	else:
		config.director.quiet_real_seconds = 1000000.0
	return config


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(STEP_HOURS, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		elapsed += step


func _send_reggie(state: SimState) -> Order:
	var order := state.orders.inject(1, 0, 200, 5.0, 0.0, false, state.clock.elapsed_game_seconds)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	state.inventory.create(state.config.strain.id, 60).packed = true
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)
	return order


func test_reggie_comes_back_from_a_delayed_delivery_even_across_a_load() -> void:
	var state := SimState.new(_config(true), 3)
	_send_reggie(state)
	assert_false(state.helper.present())
	_advance(state, 0.5)
	assert_gt(state.event_log.of_type(EventLog.DIRECTOR_EVENT).size(), 0, "the delivery got held up")
	var loaded := SimState.from_json(state.to_json(), state.config)
	for copy: SimState in [state, loaded]:
		_advance(copy, state.config.orders.trip_hours * 1.5 + state.config.director.courier_delay_hours * 3.0)
		assert_true(copy.helper.present(), "Reggie is back on the farm")
		assert_eq(copy.helper.away_reason, "")
	assert_eq(loaded.to_json(), state.to_json())


func test_reggie_comes_back_from_his_courses() -> void:
	var state := SimState.new(_config(), 3)
	assert_true(state.apply(LearnSkillCommand.new("driving")).ok)
	_advance(state, state.config.find_skill("driving").train_hours + STEP_HOURS)
	assert_true(state.helper.present())


func test_crew_line_says_which_order_he_drives_and_when_he_is_back() -> void:
	var state := SimState.new(_config(), 3)
	var order := _send_reggie(state)
	var line := StoryText.crew_status(state)
	assert_string_contains(line, "Реджи везёт заказ #%d" % order.id)
	assert_string_contains(line, "вернётся через")
	_advance(state, state.config.orders.trip_hours + STEP_HOURS)
	assert_false(state.helper.present(), "the way back takes a while too")
	assert_string_contains(StoryText.crew_status(state), "Реджи возвращается")
	assert_string_contains(StoryText.crew_status(state), "будет через")


func test_crew_line_names_his_course() -> void:
	var state := SimState.new(_config(), 3)
	state.apply(LearnSkillCommand.new("driving"))
	var line := StoryText.crew_status(state)
	assert_string_contains(line, "Реджи на курсах")
	assert_string_contains(line, state.config.find_skill("driving").display_name)
	assert_string_contains(line, "вернётся через")
