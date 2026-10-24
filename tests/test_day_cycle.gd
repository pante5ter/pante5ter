extends GutTest

## Jack's day: drives between the farm, home and the stash, Reggie's evening call, the cost of a
## night out, and sleep that runs to the morning unless the farm raises an alarm.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = 5000
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.suspicion.decay_per_hour = 0.0
	config.first_day = null
	config.director = null
	return config


func _advance(state: SimState, hours: float, step: float = 0.25) -> void:
	var done := 0.0
	while done < hours - 0.0001:
		var chunk := minf(step, hours - done)
		state.apply(AdvanceTimeCommand.new(chunk * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		done += chunk


func _advance_to_hour(state: SimState, hour: float) -> void:
	var target := float(state.clock.day()) * SimClock.GAME_SECONDS_PER_DAY + hour * HOUR
	if target <= state.clock.elapsed_game_seconds:
		target += SimClock.GAME_SECONDS_PER_DAY
	_advance(state, (target - state.clock.elapsed_game_seconds) / HOUR)


func _go(state: SimState, place: String) -> CommandResult:
	return state.apply(TravelCommand.new(place))


func test_content_is_sane() -> void:
	var def := _balance.day
	assert_not_null(def, "balance.tres carries the day rhythm")
	assert_between(def.evening_hour, 17.0, 22.0)
	assert_gt(def.late_hour, def.evening_hour, "Reggie calls before the night counts")
	assert_lt(def.wake_hour, 10.0)
	assert_lt(def.late_until_hour, def.wake_hour)
	assert_gt(def.late_suspicion_per_hour, 0.0, "a night out has a price")
	assert_between(def.travel_minutes, 5.0, 60.0)


func test_jack_starts_on_the_farm_and_drives_between_places() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.day.place, DayCycle.FARM)
	var start := state.clock.elapsed_game_seconds
	assert_true(_go(state, DayCycle.HOME).ok)
	assert_eq(state.day.place, DayCycle.HOME)
	assert_false(state.day.travelling())
	assert_almost_eq(state.clock.elapsed_game_seconds - start, state.day.travel_seconds(), 0.001)
	assert_eq(state.event_log.of_type(EventLog.JACK_LEFT).size(), 1)
	assert_eq(state.event_log.of_type(EventLog.JACK_ARRIVED).size(), 1)
	assert_true(_go(state, DayCycle.STASH).ok)
	assert_eq(state.day.place, DayCycle.STASH)
	assert_eq(_go(state, DayCycle.STASH).error, CommandResult.ALREADY_DONE)
	assert_eq(_go(state, "london").error, CommandResult.UNKNOWN_PLACE)


func test_the_world_keeps_turning_during_a_drive() -> void:
	var big := SimState.new(_config(), 3)
	var steps := SimState.new(_config(), 3)
	for state: SimState in [big, steps]:
		state.apply(HireWorkerCommand.new("tom"))
		state.apply(PlantCommand.new(0))
	_go(big, DayCycle.HOME)
	_advance(steps, big.day.travel_seconds() / HOUR, 0.05)
	assert_eq(big.clock.elapsed_game_seconds, steps.clock.elapsed_game_seconds)
	assert_eq(big.grow.to_array(), steps.grow.to_array(), "beds grow on while Jack drives")


func test_reggie_calls_jack_home_in_the_evening_unless_he_is_there() -> void:
	var state := SimState.new(_config(), 1)
	_advance_to_hour(state, state.config.day.evening_hour + 0.25)
	assert_eq(state.event_log.of_type(EventLog.EVENING_CALL).size(), 1)
	_go(state, DayCycle.HOME)
	_advance(state, 24.0, 1.0)
	assert_eq(state.event_log.of_type(EventLog.EVENING_CALL).size(), 1, "no call when he is already home")


func test_a_night_away_from_home_raises_suspicion_once_noticed() -> void:
	var state := SimState.new(_config(), 1)
	_advance_to_hour(state, state.config.day.late_hour - 0.25)
	var before := state.suspicion.level
	_advance_to_hour(state, state.config.day.late_until_hour + 0.25)
	var late_hours := 24.0 - state.config.day.late_hour + state.config.day.late_until_hour
	assert_almost_eq(state.suspicion.level - before, late_hours * state.config.day.late_suspicion_per_hour, 0.001)
	assert_eq(state.event_log.of_type(EventLog.JACK_OUT_LATE).size(), 1, "the village talks once a night")


func test_a_night_at_home_costs_nothing() -> void:
	var state := SimState.new(_config(), 1)
	_go(state, DayCycle.HOME)
	var before := state.suspicion.level
	_advance(state, 30.0, 1.0)
	assert_eq(state.suspicion.level, before)
	assert_eq(state.event_log.of_type(EventLog.JACK_OUT_LATE).size(), 0)


func test_sleep_needs_home_and_evening() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(SleepCommand.new()).error, CommandResult.NOT_AT_HOME)
	_go(state, DayCycle.HOME)
	_advance_to_hour(state, 12.0)
	assert_eq(state.apply(SleepCommand.new()).error, CommandResult.TOO_EARLY_TO_SLEEP)


func test_sleep_runs_to_the_morning() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(HireWorkerCommand.new("tom"))
	_go(state, DayCycle.HOME)
	_advance_to_hour(state, state.config.day.sleep_from_hour + 3.0)
	var day := state.clock.day()
	var result := state.apply(SleepCommand.new())
	assert_true(result.ok)
	assert_eq(result.value, -1, "slept through")
	assert_eq(state.clock.day(), day + 1)
	assert_almost_eq(state.clock.hour_of_day(), state.config.day.wake_hour, 0.0001)
	assert_eq(state.event_log.of_type(EventLog.JACK_SLEPT).size(), 1)
	assert_eq(state.event_log.of_type(EventLog.JACK_WOKE).size(), 1)
	assert_eq(state.day.day_started_at, state.clock.elapsed_game_seconds)
	assert_gt(state.event_log.of_type(EventLog.WORKER_TASK_STARTED).size(), 0, "the gardener worked the night")


func test_sleeping_after_midnight_wakes_the_same_morning() -> void:
	var state := SimState.new(_config(), 1)
	_go(state, DayCycle.HOME)
	_advance_to_hour(state, 2.0)
	var day := state.clock.day()
	assert_true(state.apply(SleepCommand.new()).ok)
	assert_eq(state.clock.day(), day)
	assert_almost_eq(state.clock.hour_of_day(), state.config.day.wake_hour, 0.0001)


func test_sleep_equals_waiting_the_night_out() -> void:
	var slept := SimState.new(_config(), 8)
	var waited := SimState.new(_config(), 8)
	for state: SimState in [slept, waited]:
		state.apply(HireWorkerCommand.new("dave"))
		state.apply(PlantCommand.new(1))
		_go(state, DayCycle.HOME)
		_advance_to_hour(state, 22.0)
	slept.apply(SleepCommand.new())
	_advance_to_hour(waited, slept.config.day.wake_hour)
	assert_eq(slept.clock.elapsed_game_seconds, waited.clock.elapsed_game_seconds)
	assert_eq(slept.grow.to_array(), waited.grow.to_array())
	assert_eq(slept.economy.money, waited.economy.money)


func test_a_raid_wakes_jack_on_the_spot_and_sleeping_on_lets_reggie_handle_it() -> void:
	var config := _config()
	config.raids.chance_per_night = 1.0
	config.starting_money = 1000
	var state := SimState.new(config, 2)
	state.inventory.create(config.strain.id, 60)
	_go(state, DayCycle.HOME)
	_advance(state, config.raids.start_hours - 2.0, 1.0)
	var result := state.apply(SleepCommand.new())
	assert_true(result.ok)
	assert_ne(result.value, -1, "an alarm cut the night short")
	var alarm := state.event_log.entries()[result.value]
	assert_eq(alarm.type, EventLog.RAID_STARTED)
	assert_eq(state.clock.elapsed_game_seconds, alarm.game_time, "the clock stops at the alarm")
	assert_true(state.raids.pending)
	assert_eq(state.event_log.of_type(EventLog.SLEEP_INTERRUPTED).size(), 1)
	assert_eq(state.event_log.of_type(EventLog.JACK_WOKE).size(), 0)
	assert_true(state.apply(SleepCommand.new()).ok, "sleeping on is allowed")
	assert_false(state.raids.pending, "Reggie dealt with them while Jack slept")
	var outcome := String(state.event_log.of_type(EventLog.RAID_RESOLVED)[0].data["outcome"])
	assert_true(outcome.begins_with("helper_"), outcome)
	assert_almost_eq(state.clock.hour_of_day(), config.day.wake_hour, 0.0001)


func test_an_inspection_warning_is_an_alarm_too() -> void:
	var config := _config()
	config.suspicion.inspection_threshold = 30.0
	var state := SimState.new(config, 2)
	_go(state, DayCycle.HOME)
	_advance_to_hour(state, 22.0)
	state.suspicion.add(40.0)
	var result := state.apply(SleepCommand.new())
	assert_eq(state.event_log.entries()[result.value].type, EventLog.INSPECTION_WARNED)


func test_travelling_to_the_farm_after_an_alarm_takes_the_drive_time() -> void:
	var config := _config()
	config.raids.chance_per_night = 1.0
	config.starting_money = 1000
	config.helper = null
	var state := SimState.new(config, 2)
	state.inventory.create(config.strain.id, 60)
	_go(state, DayCycle.HOME)
	_advance(state, config.raids.start_hours - 2.0, 1.0)
	state.apply(SleepCommand.new())
	assert_true(state.raids.pending)
	assert_true(_go(state, DayCycle.FARM).ok)
	assert_true(state.raids.pending, "the gang waits an hour; the drive is shorter")
	assert_true(state.apply(RaidCommand.new(Raids.PAY)).ok)


func test_the_day_survives_save_and_load() -> void:
	var state := SimState.new(_config(), 4)
	_go(state, DayCycle.STASH)
	_advance_to_hour(state, 23.5)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.to_json(), state.to_json())
	assert_eq(loaded.day.place, DayCycle.STASH)
	_advance(state, 10.0)
	_advance(loaded, 10.0)
	assert_eq(loaded.to_json(), state.to_json())


func test_without_a_day_rhythm_travel_is_instant_and_nights_are_free() -> void:
	var config := _config()
	config.day = null
	var state := SimState.new(config, 1)
	var start := state.clock.elapsed_game_seconds
	assert_true(_go(state, DayCycle.HOME).ok)
	assert_eq(state.clock.elapsed_game_seconds, start)
	_go(state, DayCycle.FARM)
	_advance(state, 30.0, 1.0)
	assert_eq(state.suspicion.level, 0.0)
	assert_eq(state.apply(SleepCommand.new()).error, CommandResult.UNKNOWN_COMMAND)
