extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


## The script alone: no random trouble, no director, no inspections.
func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.director = null
	config.stash = _balance.stash.duplicate() as StashDef
	config.stash.base_risk = 0.0
	return config


func _real(hours: float, state: SimState) -> float:
	return hours * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(STEP_HOURS, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(_real(step, state)))
		elapsed += step


func _advance_to(state: SimState, hour: float) -> void:
	_advance(state, hour - state.clock.elapsed_game_seconds / HOUR)


func _tend_until(state: SimState, plot_id: int, stage: Plot.Stage, limit_hours: float) -> void:
	var elapsed := 0.0
	while state.grow.plot(plot_id).stage != stage and elapsed < limit_hours:
		state.apply(WaterCommand.new(plot_id))
		_advance(state, STEP_HOURS)
		elapsed += STEP_HOURS


func _call_delay_hours(state: SimState) -> float:
	return state.config.first_day.call_after_real_seconds * SimClock.GAME_SECONDS_PER_DAY / state.config.real_seconds_per_game_day / HOUR


func _step(state: SimState) -> FirstDay.Step:
	return state.first_day.step


func test_content_wires_the_script() -> void:
	var def := _balance.first_day
	assert_not_null(def, "balance.tres carries the first-day script")
	assert_not_null(def.lord_story)
	assert_not_null(def.trouble_story)
	assert_eq(def.lord_story.choices.size(), 2)
	assert_almost_eq(def.call_after_real_seconds, 60.0, 15.0, "the first call comes about a minute after planting")
	assert_lt(def.lord_hour, 24.0, "the lord calls on the first evening")
	assert_gt(def.trouble_hour, 24.0, "trouble waits for day two")
	for line: String in [def.plant_field_line, def.plant_bunker_line, def.call_line, def.answer_line, def.harvest_line, def.haul_line, def.pack_line, def.send_line, def.paid_line, def.evening_line, def.morning_line, def.trouble_line]:
		assert_false(line.is_empty(), "every step has a line for Reggie")
	assert_false(def.plant_bunker_line.contains("контейнер"), "in the bunker Reggie does not send Jack down the container")


func test_regular_callers_wait_for_the_scripted_call() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(_step(state), FirstDay.Step.PLANT)
	_advance(state, 3.0)
	assert_eq(state.orders.all().size(), 0, "nobody calls before anything grows")
	state.apply(PlantCommand.new(0))
	assert_eq(_step(state), FirstDay.Step.CALL)
	var delay := _call_delay_hours(state)
	_advance(state, delay - STEP_HOURS)
	assert_eq(state.orders.all().size(), 0)
	_advance(state, STEP_HOURS * 2.0)
	assert_eq(state.orders.all().size(), 1, "the scripted client calls on time")
	var order := state.orders.all()[0]
	assert_eq(order.quantity, 1, "one bed is enough for the first client")
	assert_eq(order.min_quality, 0)
	assert_eq(order.reward, state.config.first_day.call_reward)
	assert_eq(_step(state), FirstDay.Step.ANSWER)


func test_full_first_day_walks_through_every_step() -> void:
	var state := SimState.new(_config(), 3)
	var start_money := state.economy.money
	state.apply(PlantCommand.new(0))
	_tend_until(state, 0, Plot.Stage.READY, 1.0 + _call_delay_hours(state))
	assert_eq(_step(state), FirstDay.Step.ANSWER)
	var order := state.first_day.script_order()
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	assert_eq(_step(state), FirstDay.Step.HARVEST)
	_tend_until(state, 0, Plot.Stage.READY, 8.0)
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_eq(_step(state), FirstDay.Step.HAUL)
	assert_true(state.apply(HaulCommand.new(Helper.ACTOR)).ok)
	_advance(state, state.config.stash.haul_hours + STEP_HOURS)
	assert_eq(_step(state), FirstDay.Step.PACK)
	assert_true(state.apply(PackCommand.new()).ok)
	_advance(state, 0.75)
	assert_eq(_step(state), FirstDay.Step.SEND)
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)
	assert_eq(_step(state), FirstDay.Step.PAID)
	assert_false(state.orders.hold_calls, "regular callers resume once the lesson's order is on the road")
	_advance(state, state.config.orders.trip_hours + STEP_HOURS)
	assert_eq(_step(state), FirstDay.Step.EVENING)
	assert_eq(state.economy.money, start_money + state.config.first_day.call_reward, "Reggie brings the whole reward home")
	_advance_to(state, state.config.first_day.lord_hour - STEP_HOURS)
	assert_false(state.stories.is_pending())
	_advance(state, STEP_HOURS * 2.0)
	assert_eq(_step(state), FirstDay.Step.LORD)
	assert_eq(state.stories.pending_id, state.config.first_day.lord_story.id, "the lord calls in the evening")
	assert_true(state.apply(ChooseCommand.new(state.stories.pending_id, 1)).ok)
	assert_eq(_step(state), FirstDay.Step.MORNING)
	_advance_to(state, state.config.first_day.trouble_hour - 3.0)
	state.apply(PlantCommand.new(1))
	_advance_to(state, state.config.first_day.trouble_hour + STEP_HOURS)
	assert_eq(_step(state), FirstDay.Step.TROUBLE)
	assert_eq(state.first_day.trouble_plot_id, 1)
	assert_eq(state.grow.plot(1).problem, Problems.PESTS, "day two starts with pests on a growing bed")
	state.apply(BuyCommand.new(Supplies.PESTICIDE, 1))
	_advance(state, state.config.delivery_hours + STEP_HOURS)
	state.apply(PickUpParcelCommand.new())
	if not state.grow.plot(1).problem.is_empty():
		assert_true(state.apply(TreatCommand.new(1)).ok)
	_advance(state, STEP_HOURS)
	assert_eq(_step(state), FirstDay.Step.DONE)
	assert_false(state.first_day.active())


func test_playing_ahead_completes_the_steps_at_once() -> void:
	var state := SimState.new(_config(), 5)
	state.inventory.create(state.config.strain.id, 60).packed = true
	state.apply(PlantCommand.new(0))
	_advance(state, _call_delay_hours(state) + STEP_HOURS)
	var order := state.first_day.script_order()
	assert_not_null(order)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	assert_eq(_step(state), FirstDay.Step.SEND, "a packed box already on the shelf skips harvest and packing")
	state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	assert_eq(_step(state), FirstDay.Step.PAID)


func test_declining_the_scripted_call_moves_on_to_the_evening() -> void:
	var state := SimState.new(_config(), 5)
	state.apply(PlantCommand.new(0))
	_advance(state, _call_delay_hours(state) + STEP_HOURS)
	state.apply(AnswerOrderCommand.new(state.first_day.script_order().id, Orders.DECLINE))
	assert_eq(_step(state), FirstDay.Step.EVENING)
	assert_false(state.orders.hold_calls)
	_advance(state, state.config.orders.interval_hours + STEP_HOURS)
	assert_gt(state.event_log.of_type(EventLog.ORDER_RECEIVED).size(), 1, "regular calls come again")


func test_without_a_growing_bed_day_two_brings_the_neighbour() -> void:
	var state := SimState.new(_config(), 5)
	state.apply(PlantCommand.new(0))
	_advance(state, _call_delay_hours(state) + STEP_HOURS)
	state.apply(AnswerOrderCommand.new(state.first_day.script_order().id, Orders.DECLINE))
	_advance_to(state, state.config.first_day.lord_hour + STEP_HOURS)
	state.apply(ChooseCommand.new(state.stories.pending_id, 0))
	_tend_until(state, 0, Plot.Stage.READY, 10.0)
	state.apply(HarvestCommand.new(0))
	_advance_to(state, state.config.first_day.trouble_hour + STEP_HOURS)
	assert_eq(_step(state), FirstDay.Step.TROUBLE)
	assert_eq(state.stories.pending_id, state.config.first_day.trouble_story.id)
	state.apply(ChooseCommand.new(state.stories.pending_id, 0))
	assert_eq(_step(state), FirstDay.Step.DONE)


func test_the_lord_waits_while_another_story_is_open() -> void:
	var config := _config()
	# The director's stories are needed, its timing is not.
	config.director = _balance.director.duplicate() as DirectorDef
	config.director.quiet_real_seconds = 1000000.0
	var state := SimState.new(config, 5)
	state.apply(PlantCommand.new(0))
	_advance(state, _call_delay_hours(state) + STEP_HOURS)
	state.apply(AnswerOrderCommand.new(state.first_day.script_order().id, Orders.DECLINE))
	assert_eq(_step(state), FirstDay.Step.EVENING)
	assert_true(state.stories.start(state.stories.find("hiker"), state.clock.elapsed_game_seconds, Director.ACTOR))
	_advance_to(state, state.config.first_day.lord_hour + 1.0)
	assert_eq(_step(state), FirstDay.Step.EVENING, "the lord does not cut into another conversation")
	assert_true(state.apply(ChooseCommand.new("hiker", 0)).ok)
	assert_eq(_step(state), FirstDay.Step.LORD, "and calls right after it")
	assert_eq(state.stories.pending_id, state.config.first_day.lord_story.id)


func _scripted_run(state: SimState, big_steps: bool) -> void:
	state.apply(PlantCommand.new(0))
	state.apply(WaterCommand.new(0))
	if big_steps:
		state.apply(AdvanceTimeCommand.new(_real(3.0, state)))
	else:
		_advance(state, 3.0)
	var order := state.first_day.script_order()
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	state.inventory.create(state.config.strain.id, 50).packed = true
	state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	if big_steps:
		state.apply(AdvanceTimeCommand.new(_real(40.0, state)))
	else:
		_advance(state, 40.0)


func test_one_big_step_equals_many_small_steps() -> void:
	var big := SimState.new(_balance, 21)
	var small := SimState.new(_balance, 21)
	_scripted_run(big, true)
	_scripted_run(small, false)
	assert_gte(big.event_log.of_type(EventLog.FIRST_DAY_STEP).size(), 5)
	assert_eq(JSON.stringify(big.event_log.to_array()), JSON.stringify(small.event_log.to_array()))
	assert_eq(big.to_json(), small.to_json())


func test_save_and_load_mid_script_continues_identically() -> void:
	var state := SimState.new(_balance, 9)
	state.apply(PlantCommand.new(0))
	_advance(state, 1.0)
	assert_eq(_step(state), FirstDay.Step.CALL)
	var loaded := SimState.from_json(state.to_json(), _balance)
	assert_not_null(loaded)
	assert_eq(loaded.first_day.step, FirstDay.Step.CALL)
	assert_true(loaded.orders.hold_calls, "the hold on regular calls survives a load")
	for copy: SimState in [state, loaded]:
		_advance(copy, 2.0)
		var order := copy.first_day.script_order()
		copy.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
		_advance_to(copy, copy.config.first_day.lord_hour + STEP_HOURS)
	assert_eq(loaded.to_json(), state.to_json())
	# By the evening either the lord or a director story waits for Jack.
	assert_true(state.stories.is_pending())
	var mid_story := SimState.from_json(state.to_json(), _balance)
	assert_eq(mid_story.stories.pending_id, state.stories.pending_id, "a pending story survives a load")
	for copy: SimState in [state, mid_story]:
		assert_true(copy.apply(ChooseCommand.new(copy.stories.pending_id, 0)).ok)
		_advance(copy, 1.0)
	assert_eq(mid_story.to_json(), state.to_json())


func test_old_saves_skip_the_script() -> void:
	var state := SimState.new(_balance, 2)
	_advance(state, 2.0)
	var data := JSON.parse_string(state.to_json()) as Dictionary
	for key: String in SimState.V9_SAVE_KEYS:
		data.erase(key)
	data["save_version"] = SimState.V8_VERSION
	var loaded := SimState.from_json(JSON.stringify(data), _balance)
	assert_not_null(loaded, "a v8 save still loads")
	assert_false(loaded.first_day.active(), "a game in progress gets no tutorial")
	assert_false(loaded.orders.hold_calls)
	assert_almost_eq(loaded.director.last_notable_at, loaded.clock.elapsed_game_seconds, 0.001, "the director starts counting at load")
	data["save_version"] = SimState.SAVE_VERSION
	assert_null(SimState.from_json(JSON.stringify(data), _balance), "a v9 save must carry the new sections")
