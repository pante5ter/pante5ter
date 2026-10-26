extends GutTest

## Reggie's on-demand advice and the first-day tips.


func _state() -> SimState:
	var config := (load("res://content/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	config.first_day = null
	config.director = null
	config.problems = config.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	return SimState.new(config, 1)


func test_advice_follows_the_objective() -> void:
	var state := _state()
	assert_eq(Advice.line(state), UiText.objective(state))
	state.apply(PlantCommand.new(0))
	assert_string_contains(Advice.line(state, true), "Полей")


func test_first_tip_fires_once() -> void:
	var state := _state()
	var tip := Advice.first_tip(state, "prune")
	assert_false(tip.is_empty())
	assert_string_contains(tip, "+%d" % state.config.prune_bonus)
	Advice.mark_tip(state, "prune")
	assert_eq(Advice.first_tip(state, "prune"), "")


func test_tips_survive_a_save() -> void:
	var state := _state()
	Advice.mark_tip(state, "water")
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_true(loaded.tips_seen.has("water"))
	assert_eq(Advice.first_tip(loaded, "water"), "")


func test_time_of_day_follows_the_clock() -> void:
	var state := _state()
	assert_eq(Advice.time_of_day(state), "ночь")
	var hours := 8.0
	state.apply(AdvanceTimeCommand.new(hours * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
	assert_eq(Advice.time_of_day(state), "утро")


func test_sleep_opens_after_the_evening_call() -> void:
	var state := _state()
	state.apply(TravelCommand.new(DayCycle.HOME))
	var evening := state.config.day.evening_hour
	var target := float(state.clock.day()) * SimClock.GAME_SECONDS_PER_DAY + evening * SimClock.GAME_SECONDS_PER_HOUR
	var hours := (target - state.clock.elapsed_game_seconds) / SimClock.GAME_SECONDS_PER_HOUR
	state.apply(AdvanceTimeCommand.new(hours * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
	assert_eq(state.day.can_sleep(state.clock.elapsed_game_seconds), "")


func test_unhired_courier_is_not_a_suspect() -> void:
	var state := _state()
	var pete: SuspectDef = null
	for person: SuspectDef in state.config.intrigue.suspects:
		if person.courier_id == "pete":
			pete = person
	assert_not_null(pete)
	assert_false(state.intrigue.is_introduced(pete), "Pete is not on the board until hired")
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	assert_true(state.intrigue.is_introduced(pete))
