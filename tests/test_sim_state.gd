extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const MAX_CYCLE_STEPS: int = 100

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _real_seconds_for_game_hours(hours: float) -> float:
	return hours * SimClock.GAME_SECONDS_PER_HOUR * _balance.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func _apply_ok(state: SimState, command: SimCommand) -> CommandResult:
	var result := state.apply(command)
	assert_true(result.ok, "command failed: %s" % result.error)
	return result


func _all_plots_ready(state: SimState) -> bool:
	for plot: Plot in state.grow.plots():
		if plot.stage != Plot.Stage.READY:
			return false
	return true


func _play_cycle(state: SimState, watering_interval_hours: float) -> void:
	for plot: Plot in state.grow.plots():
		state.apply(PlantCommand.new(plot.id))
	var steps := 0
	while not _all_plots_ready(state) and steps < MAX_CYCLE_STEPS:
		for plot: Plot in state.grow.plots():
			if plot.is_growing():
				state.apply(WaterCommand.new(plot.id))
		state.apply(AdvanceTimeCommand.new(_real_seconds_for_game_hours(watering_interval_hours)))
		steps += 1
	for plot: Plot in state.grow.plots():
		state.apply(HarvestCommand.new(plot.id))
	for product: Product in state.inventory.products():
		state.apply(SellCommand.new(product.id))


func test_new_state_uses_content() -> void:
	var state := SimState.new(_balance, 1)
	assert_eq(state.grow.plots().size(), _balance.plot_count)
	assert_eq(state.economy.money, _balance.starting_money)
	assert_eq(state.clock.elapsed_game_seconds, 0.0)
	assert_eq(state.event_log.size(), 0)


func test_advance_time_uses_real_seconds_per_game_day() -> void:
	var state := SimState.new(_balance, 1)
	_apply_ok(state, AdvanceTimeCommand.new(_balance.real_seconds_per_game_day))
	assert_eq(state.clock.day(), 1)
	assert_almost_eq(state.clock.hour_of_day(), 0.0, 0.0001)


func test_full_loop_through_commands() -> void:
	var state := SimState.new(_balance, 7)
	_apply_ok(state, PlantCommand.new(0))
	_apply_ok(state, WaterCommand.new(0))
	var growth_hours := _balance.strain.seed_hours + _balance.strain.sprout_hours + _balance.strain.bush_hours
	var elapsed := 0.0
	while elapsed < growth_hours:
		var step := minf(_balance.strain.water_capacity_hours, growth_hours - elapsed)
		_apply_ok(state, AdvanceTimeCommand.new(_real_seconds_for_game_hours(step)))
		elapsed += step
		if state.grow.plot(0).is_growing():
			_apply_ok(state, WaterCommand.new(0))
	assert_eq(state.grow.plot(0).stage, Plot.Stage.READY)

	var product_id := _apply_ok(state, HarvestCommand.new(0)).value
	var quality := state.inventory.find(product_id).quality
	assert_between(quality, 0, 100)
	assert_eq(state.inventory.count(), int(state.event_log.of_type(EventLog.PLOT_HARVESTED)[0].data["quantity"]))

	var earned := 0
	for product: Product in state.inventory.products():
		var price := _apply_ok(state, SellCommand.new(product.id)).value
		assert_eq(price, state.economy.price_for(product.quality))
		earned += price
	assert_eq(state.economy.money, _balance.starting_money + earned)
	assert_eq(state.inventory.count(), 0)
	assert_eq(state.event_log.of_type(EventLog.PLOT_HARVESTED).size(), 1)
	assert_eq(state.event_log.of_type(EventLog.PRODUCT_SOLD).size(), int(state.event_log.of_type(EventLog.PLOT_HARVESTED)[0].data["quantity"]))


func test_growth_finishes_on_time_when_clock_is_not_round() -> void:
	var state := SimState.new(_balance, 1)
	_apply_ok(state, AdvanceTimeCommand.new(0.0173))
	_apply_ok(state, PlantCommand.new(0))
	var strain := _balance.strain
	var hours_left := strain.seed_hours + strain.sprout_hours + strain.bush_hours
	while hours_left > 0.0:
		_apply_ok(state, WaterCommand.new(0))
		var step := minf(hours_left, strain.water_capacity_hours)
		_apply_ok(state, AdvanceTimeCommand.new(_real_seconds_for_game_hours(step)))
		hours_left -= step
	assert_eq(state.grow.plot(0).stage, Plot.Stage.READY)


func test_events_carry_game_time() -> void:
	var state := SimState.new(_balance, 1)
	_apply_ok(state, AdvanceTimeCommand.new(_real_seconds_for_game_hours(3.0)))
	_apply_ok(state, PlantCommand.new(0))
	assert_almost_eq(state.event_log.last().game_time, 3.0 * SimClock.GAME_SECONDS_PER_HOUR, 0.001)


func test_rejected_commands_change_nothing() -> void:
	var state := SimState.new(_balance, 1)
	var before := state.to_json()
	assert_eq(state.apply(HarvestCommand.new(0)).error, CommandResult.PLOT_NOT_READY)
	assert_eq(state.apply(WaterCommand.new(0)).error, CommandResult.PLOT_NOT_GROWING)
	assert_eq(state.apply(PlantCommand.new(_balance.plot_count)).error, CommandResult.INVALID_PLOT)
	assert_eq(state.apply(SellCommand.new(1)).error, CommandResult.UNKNOWN_PRODUCT)
	assert_eq(state.apply(SimCommand.new()).error, CommandResult.UNKNOWN_COMMAND)
	assert_eq(state.to_json(), before)


func test_unwatered_growth_stands_still() -> void:
	var state := SimState.new(_balance, 1)
	_apply_ok(state, PlantCommand.new(0))
	_apply_ok(state, AdvanceTimeCommand.new(_balance.real_seconds_per_game_day * 5.0))
	assert_eq(state.grow.plot(0).stage, Plot.Stage.SEED)
	assert_eq(state.grow.plot(0).progress_seconds, 0.0)


func test_save_then_load_gives_identical_state() -> void:
	var state := SimState.new(_balance, 99)
	_play_cycle(state, 5.0)
	_apply_ok(state, PlantCommand.new(0))
	_apply_ok(state, WaterCommand.new(0))
	_apply_ok(state, AdvanceTimeCommand.new(_real_seconds_for_game_hours(2.5)))
	var saved := state.to_json()

	var loaded := SimState.from_json(saved, _balance)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), saved)
	assert_eq(loaded.economy.money, state.economy.money)
	assert_eq(loaded.event_log.size(), state.event_log.size())
	assert_eq(loaded.grow.plot(0).stage, state.grow.plot(0).stage)


func test_loaded_state_continues_like_original() -> void:
	var original := SimState.new(_balance, 2024)
	_play_cycle(original, 6.0)
	var loaded := SimState.from_json(original.to_json(), _balance)
	_play_cycle(original, 4.0)
	_play_cycle(loaded, 4.0)
	assert_eq(loaded.to_json(), original.to_json())


func test_same_seed_gives_same_result() -> void:
	var first := SimState.new(_balance, 31337)
	var second := SimState.new(_balance, 31337)
	for i: int in 3:
		_play_cycle(first, 5.0)
		_play_cycle(second, 5.0)
	assert_gt(first.event_log.of_type(EventLog.PRODUCT_SOLD).size(), 0)
	assert_eq(first.to_json(), second.to_json())


func test_different_seeds_give_different_harvests() -> void:
	var first := SimState.new(_balance, 1)
	var second := SimState.new(_balance, 2)
	for i: int in 3:
		_play_cycle(first, 5.0)
		_play_cycle(second, 5.0)
	assert_ne(JSON.stringify(first.event_log.to_array()), JSON.stringify(second.event_log.to_array()))


func test_from_json_rejects_garbage() -> void:
	assert_null(SimState.from_json("not json", _balance))
	assert_null(SimState.from_json("[1, 2]", _balance))
	assert_null(SimState.from_json("{\"save_version\": 1}", _balance))


func test_from_json_rejects_unknown_version() -> void:
	var data := SimState.new(_balance, 1).to_dict()
	data["save_version"] = SimState.SAVE_VERSION + 1
	assert_null(SimState.from_json(JSON.stringify(data), _balance))


func test_save_round_trip_is_exact_for_awkward_times() -> void:
	for step: int in 200:
		var state := SimState.new(_balance, 3)
		_apply_ok(state, AdvanceTimeCommand.new(0.0137 * float(step + 1)))
		_apply_ok(state, PlantCommand.new(0))
		_apply_ok(state, WaterCommand.new(0))
		_apply_ok(state, AdvanceTimeCommand.new(0.731 * float(step + 1)))
		var saved := state.to_json()
		var loaded := SimState.from_json(saved, _balance)
		if loaded.to_json() != saved:
			fail_test("save drifted after step %d" % step)
			return
	pass_test("all round trips exact")


func test_from_json_rejects_unreadable_clock() -> void:
	var data := SimState.new(_balance, 1).to_dict()
	data["clock"] = {"elapsed_game_seconds": 12.5}
	assert_null(SimState.from_json(JSON.stringify(data), _balance))
