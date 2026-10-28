extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _calm() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.director = null
	return config


func _state() -> SimState:
	return SimState.new(_calm(), 5)


func _log(state: SimState, type: String, actors: Array[String] = [SimCommand.PLAYER_ACTOR], data: Dictionary = {}) -> void:
	state.event_log.record(type, state.clock.elapsed_game_seconds, PackedStringArray(actors), data)
	state.first_day.update(state.clock.elapsed_game_seconds)


func _guide(state: SimState) -> Guide:
	return state.first_day.guide


func test_content_wires_the_guide() -> void:
	assert_not_null(_balance.guide, "balance.tres carries the guide numbers")
	assert_gt(_balance.guide.rent_warning_hours, 0.0)
	assert_gt(_balance.guide.high_suspicion, 0.0)


func test_a_new_game_starts_with_going_down() -> void:
	var state := _state()
	assert_true(_guide(state).active())
	assert_eq(_guide(state).current(), Guide.Step.GO_DOWN)
	assert_eq(Guide.step_count(), 9, "nine small goals, from the lift to the first order")


func test_the_chain_follows_real_events_in_order() -> void:
	var state := _state()
	var chain: Array[Array] = [
		[EventLog.BUNKER_ENTERED, Guide.Step.PLANT],
		[EventLog.PLOT_PLANTED, Guide.Step.WATER],
		[EventLog.PLOT_WATERED, Guide.Step.PRUNE],
		[EventLog.PLOT_PRUNED, Guide.Step.HIRE],
		[EventLog.WORKER_HIRED, Guide.Step.HARVEST],
		[EventLog.PLOT_HARVESTED, Guide.Step.HAUL],
		[EventLog.HAUL_ARRIVED, Guide.Step.PACK],
		[EventLog.PACKING_DONE, Guide.Step.SEND],
		[EventLog.ORDER_DISPATCHED, Guide.Step.DONE],
	]
	for link: Array in chain:
		_log(state, String(link[0]), [SimCommand.PLAYER_ACTOR], {"role": WorkerDef.FARMHAND})
		assert_eq(_guide(state).current(), link[1] as Guide.Step, "after %s" % link[0])
	assert_false(_guide(state).active())


func test_every_step_change_is_logged_once() -> void:
	var state := _state()
	var before := state.event_log.of_type(EventLog.GUIDE_STEP).size()
	_log(state, EventLog.BUNKER_ENTERED)
	_log(state, EventLog.BUNKER_ENTERED)
	var steps := state.event_log.of_type(EventLog.GUIDE_STEP)
	assert_eq(steps.size(), before + 1)
	assert_eq(String(steps[-1].data["step"]), "plant")


func test_doing_a_later_thing_early_ticks_it_off() -> void:
	var state := _state()
	_log(state, EventLog.WORKER_HIRED, ["dave"], {"role": WorkerDef.FARMHAND})
	assert_true(_guide(state).is_done(Guide.Step.HIRE))
	assert_eq(_guide(state).current(), Guide.Step.GO_DOWN, "the first unmet goal still shows")
	_log(state, EventLog.PLOT_PLANTED)
	assert_eq(_guide(state).current(), Guide.Step.WATER, "planting means Jack has been down")


func test_a_harvest_without_pruning_stops_waiting_for_the_pruning() -> void:
	var state := _state()
	for type: String in [EventLog.BUNKER_ENTERED, EventLog.PLOT_PLANTED, EventLog.PLOT_WATERED]:
		_log(state, type)
	_log(state, EventLog.PLOT_HARVESTED)
	assert_true(_guide(state).is_done(Guide.Step.PRUNE))
	assert_eq(_guide(state).current(), Guide.Step.HIRE)


func test_hiring_a_packer_is_not_hiring_a_gardener() -> void:
	var state := _state()
	_log(state, EventLog.WORKER_HIRED, [SimCommand.PLAYER_ACTOR], {"role": WorkerDef.PACKER})
	assert_false(_guide(state).is_done(Guide.Step.HIRE))


func test_the_lift_counts_once_and_only_at_the_farm() -> void:
	var state := _state()
	assert_true(state.apply(EnterBunkerCommand.new()).ok)
	assert_true(state.apply(EnterBunkerCommand.new()).ok)
	assert_eq(state.event_log.of_type(EventLog.BUNKER_ENTERED).size(), 1, "only the first trip down is news")
	assert_eq(_guide(state).current(), Guide.Step.PLANT)
	var away := SimState.new(_calm(), 6)
	away.day.place = DayCycle.HOME
	assert_false(away.apply(EnterBunkerCommand.new()).ok)


func test_real_commands_drive_the_first_steps() -> void:
	var state := _state()
	state.apply(EnterBunkerCommand.new())
	assert_true(state.apply(PlantCommand.new(0)).ok)
	assert_eq(_guide(state).current(), Guide.Step.WATER)
	assert_true(state.apply(WaterCommand.new(0)).ok)
	assert_eq(_guide(state).current(), Guide.Step.PRUNE)
	state.economy.earn(1000)
	assert_true(state.apply(HireWorkerCommand.new("dave")).ok)
	assert_true(_guide(state).is_done(Guide.Step.HIRE))


func test_skipping_ends_the_guide_and_says_so() -> void:
	var state := _state()
	var result := state.apply(SkipGuideCommand.new())
	assert_true(result.ok)
	assert_false(_guide(state).active())
	var skipped := state.event_log.of_type(EventLog.GUIDE_SKIPPED)
	assert_eq(skipped.size(), 1)
	assert_eq(String(skipped[0].data["step"]), "go_down")
	assert_eq(state.apply(SkipGuideCommand.new()).error, CommandResult.ALREADY_DONE)
	assert_true(state.first_day.active(), "the first-day story goes on; only the lessons stop")


func test_progress_survives_a_save() -> void:
	var state := _state()
	_log(state, EventLog.BUNKER_ENTERED)
	_log(state, EventLog.PLOT_PLANTED)
	var loaded := SimState.from_json(state.to_json(), _calm())
	assert_not_null(loaded)
	assert_eq(_guide(loaded).current(), Guide.Step.WATER)
	assert_eq(_guide(loaded).seen_events, _guide(state).seen_events)
	var before := loaded.event_log.size()
	loaded.first_day.update(loaded.clock.elapsed_game_seconds)
	assert_eq(loaded.event_log.size(), before, "a loaded guide does not re-announce its step")


func test_a_skipped_guide_stays_skipped_after_loading() -> void:
	var state := _state()
	state.apply(SkipGuideCommand.new())
	var loaded := SimState.from_json(state.to_json(), _calm())
	assert_false(_guide(loaded).active())


func test_a_save_from_before_the_guide_has_it_done() -> void:
	var state := _state()
	var data := JSON.parse_string(state.to_json()) as Dictionary
	(data["first_day"] as Dictionary).erase("guide")
	var loaded := SimState.from_json(JSON.stringify(data), _calm())
	assert_not_null(loaded)
	assert_false(_guide(loaded).active(), "an old save is a game under way")


func test_no_lessons_without_the_first_day_or_the_guide() -> void:
	var config := _calm()
	config.guide = null
	assert_false(SimState.new(config, 1).first_day.guide.active())
	var plain := _calm()
	plain.first_day = null
	assert_false(SimState.new(plain, 1).first_day.guide.active())
	var skipped := _state()
	skipped.first_day.skip()
	assert_false(skipped.first_day.guide.active(), "skipping the first day skips its lessons")
