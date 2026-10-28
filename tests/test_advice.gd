extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


## After the guide: no script, no random trouble, no director.
func _state() -> SimState:
	var config := _balance.duplicate() as BalanceConfig
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.director = null
	config.first_day = null
	var state := SimState.new(config, 9)
	state.economy.money = 0
	return state


func _grow(state: SimState, plot_id: int, stage: Plot.Stage) -> Plot:
	var plot := state.grow.plot(plot_id)
	plot.strain_id = state.config.strain.id
	plot.stage = stage
	plot.water_seconds = SimClock.GAME_SECONDS_PER_HOUR
	return plot


func _kind(state: SimState) -> String:
	return Advice.next(state).kind


func test_an_idle_farm_with_no_money_wants_planting() -> void:
	var state := _state()
	var advice := Advice.next(state)
	assert_eq(advice.kind, Advice.PLANT)
	assert_eq(advice.plot_ids.size(), state.grow.plots().size(), "every empty bed is named")


func test_money_for_a_wage_and_no_gardener_wants_hiring() -> void:
	var state := _state()
	state.economy.money = 5000
	var advice := Advice.next(state)
	assert_eq(advice.kind, Advice.HIRE)
	assert_gt(advice.amount, 0, "the cheapest wage is quoted")


func test_ripe_beds_beat_dry_ones_and_are_listed() -> void:
	var state := _state()
	_grow(state, 0, Plot.Stage.SPROUT).water_seconds = 0.0
	_grow(state, 1, Plot.Stage.READY)
	_grow(state, 2, Plot.Stage.READY)
	var advice := Advice.next(state)
	assert_eq(advice.kind, Advice.HARVEST)
	assert_eq(advice.plot_ids, [1, 2] as Array[int])
	state.grow.plot(1).stage = Plot.Stage.EMPTY
	state.grow.plot(2).stage = Plot.Stage.EMPTY
	assert_eq(_kind(state), Advice.WATER)


func test_a_sick_bed_comes_after_watering() -> void:
	var state := _state()
	_grow(state, 0, Plot.Stage.BUSH).problem = Problems.PESTS
	assert_eq(_kind(state), Advice.PROBLEM)
	_grow(state, 1, Plot.Stage.SPROUT).water_seconds = 0.0
	assert_eq(_kind(state), Advice.WATER)


func test_a_ringing_client_beats_the_beds() -> void:
	var state := _state()
	_grow(state, 0, Plot.Stage.READY)
	state.orders.inject(2, 10, 300, 6.0, 0.0, false, 0.0)
	var advice := Advice.next(state)
	assert_eq(advice.kind, Advice.CALL)
	assert_eq(advice.amount, 1)


func test_crates_on_the_farm_want_hauling() -> void:
	var state := _state()
	_grow(state, 0, Plot.Stage.READY)
	assert_true(state.grow.harvest(0, 0.0, SimCommand.PLAYER_ACTOR).ok)
	var advice := Advice.next(state)
	assert_eq(advice.kind, Advice.HAUL)
	assert_gt(advice.amount, 0)


func test_a_raid_comes_before_everything() -> void:
	var state := _state()
	state.orders.inject(2, 10, 300, 6.0, 0.0, false, 0.0)
	state.raids.pending = true
	assert_eq(_kind(state), Advice.RAID)


func test_rent_due_soon_and_short_purse_comes_before_clients() -> void:
	var state := _state()
	if state.rent.amount() <= 0:
		pass_test("no rent in this balance")
		return
	state.orders.inject(2, 10, 300, 6.0, 0.0, false, 0.0)
	state.rent.next_due_at = state.clock.elapsed_game_seconds + SimClock.GAME_SECONDS_PER_HOUR
	var advice := Advice.next(state)
	assert_eq(advice.kind, Advice.RENT)
	assert_eq(advice.amount, state.rent.owed())
	state.economy.money = state.rent.owed()
	assert_eq(_kind(state), Advice.CALL, "with the rent in the purse it is not the first worry")


func test_spare_money_on_a_calm_farm_wants_a_new_bed() -> void:
	var state := _state()
	state.economy.money = 100000
	state.apply(HireWorkerCommand.new("dave"))
	for plot: Plot in state.grow.plots():
		_grow(state, plot.id, Plot.Stage.SPROUT)
	if state.grow.plots().size() >= state.progress.plot_cap():
		pass_test("no room for another bed at this level")
		return
	assert_eq(_kind(state), Advice.EXPAND)
	state.suspicion.level = state.config.guide.high_suspicion + 1.0
	assert_eq(_kind(state), Advice.LIE_LOW, "a hot farm does not grow")


func test_all_quiet_says_so() -> void:
	var state := _state()
	state.economy.money = 1000
	state.apply(HireWorkerCommand.new("dave"))
	state.economy.money = 0
	for plot: Plot in state.grow.plots():
		_grow(state, plot.id, Plot.Stage.SPROUT)
	assert_eq(_kind(state), Advice.NONE)


func test_every_kind_has_a_line_for_reggie() -> void:
	var state := _state()
	_grow(state, 0, Plot.Stage.BUSH).problem = Problems.PESTS
	for kind: String in [Advice.EVICTED, Advice.RAID, Advice.INSPECTION, Advice.RENT, Advice.CALL, Advice.SEND, Advice.PACK, Advice.HAUL, Advice.HARVEST, Advice.WATER, Advice.PROBLEM, Advice.HIRE, Advice.EXPAND, Advice.LIE_LOW, Advice.PLANT, Advice.WAIT_STOCK, Advice.NONE]:
		var advice := Advice.make(kind, 2)
		advice.plot_ids = [0] as Array[int]
		var line := AdviceText.say(advice, state)
		assert_false(line.is_empty(), kind)
		assert_false(line.contains("%"), "%s: no unformatted placeholders" % kind) if kind != Advice.LIE_LOW else pass_test("percent sign is part of the line")


func test_reggie_states_the_guide_step_while_it_runs() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.director = null
	var state := SimState.new(config, 4)
	assert_true(state.first_day.guide.active())
	var line := AdviceText.text(state, false)
	assert_string_contains(line, "шаг 1 из %d" % Guide.step_count())
	assert_string_contains(line, "Контейнер")
	state.apply(SkipGuideCommand.new())
	assert_false(AdviceText.text(state, false).contains("шаг"), "after the guide Reggie advises from the state")
