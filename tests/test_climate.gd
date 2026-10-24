extends GutTest

## Playtest round 4: prevent mold instead of only curing it — a sensor, humidity and ventilation.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 5000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.helper = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.rent = null
	return config


func _advance(state: SimState, hours: float) -> void:
	state.apply(AdvanceTimeCommand.new(hours * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


func _advance_in_steps(state: SimState, hours: float) -> void:
	var done := 0.0
	while done < hours - 0.000001:
		_advance(state, minf(STEP_HOURS, hours - done))
		done += STEP_HOURS


## Unwatered seeds stay "growing" and breathe into the room all day.
func _fill_beds(state: SimState) -> void:
	for plot: Plot in state.grow.plots():
		assert_true(state.apply(PlantCommand.new(plot.id)).ok)


func _strongest(state: SimState) -> int:
	return state.config.climate.ventilation.size() - 1


func _molds(state: SimState) -> int:
	return state.event_log.of_type(EventLog.PLOT_PROBLEM).filter(func(event: SimEvent) -> bool: return String(event.data["problem"]) == Problems.MOLD).size()


func test_content_is_sane() -> void:
	var def := _balance.climate
	assert_not_null(def, "balance.tres carries the bunker climate")
	assert_gt(def.sensor_price, 0)
	assert_gte(def.rooms.size(), 2)
	assert_eq(def.rooms.filter(func(room: RoomDef) -> bool: return room.has_beds).size(), 1, "one room holds the beds")
	assert_gte(def.ventilation.size(), 3)
	assert_eq(def.ventilation[0].power_per_hour, 0, "the built-in vent is free")
	for index: int in range(1, def.ventilation.size()):
		assert_gt(def.ventilation[index].power_per_hour, def.ventilation[index - 1].power_per_hour)
		assert_gt(def.ventilation[index].humidity_drop, def.ventilation[index - 1].humidity_drop)
		assert_false(def.ventilation[index].display_name.is_empty())
	assert_gt(def.bill_every_hours, 0)


func test_growing_beds_raise_humidity_and_ventilation_takes_it_down() -> void:
	var state := SimState.new(_config(), 1)
	var room := state.climate.bed_room()
	var empty := state.climate.humidity(room)
	_fill_beds(state)
	var full := state.climate.humidity(room)
	assert_gt(full, empty)
	assert_true(state.apply(SetVentilationCommand.new(_strongest(state))).ok)
	assert_lt(state.climate.humidity(room), full)
	assert_lt(state.climate.temperature(room), room.base_temperature + room.heat_per_bed * float(state.grow.plots().size()))


func test_a_quiet_farm_switches_the_vents_off() -> void:
	var state := SimState.new(_config(), 1)
	_fill_beds(state)
	assert_true(state.apply(SetVentilationCommand.new(_strongest(state))).ok)
	var room := state.climate.bed_room()
	var aired := state.climate.humidity(room)
	assert_true(state.apply(LieLowCommand.new(true)).ok)
	assert_gt(state.climate.humidity(room), aired)


func _troubled(seed_value: int) -> SimState:
	var config := _config()
	config.problems.chance_per_hour = _balance.problems.chance_per_hour
	return SimState.new(config, seed_value)


func test_mold_risk_follows_humidity() -> void:
	var state := _troubled(1)
	assert_eq(state.problems.mold_chance(), 0.0, "an empty bunker is dry enough")
	_fill_beds(state)
	var damp := state.problems.mold_chance()
	assert_gt(damp, 0.0, "a full room without extra air is damp")
	assert_true(state.apply(SetVentilationCommand.new(1)).ok)
	assert_lt(state.problems.mold_chance(), damp)
	assert_true(state.apply(SetVentilationCommand.new(_strongest(state))).ok)
	assert_eq(state.problems.mold_chance(), 0.0)


func test_a_calm_farm_grows_no_mold_however_damp() -> void:
	var state := SimState.new(_config(), 1)
	_fill_beds(state)
	assert_gt(state.climate.mold_factor(), 0.0)
	assert_eq(state.problems.mold_chance(), 0.0)


func test_damp_rooms_grow_mold_and_dry_ones_do_not() -> void:
	var damp_molds := 0
	var dry_molds := 0
	for seed_value: int in range(1, 6):
		var damp := _troubled(seed_value)
		var dry := _troubled(seed_value)
		_fill_beds(damp)
		_fill_beds(dry)
		assert_true(dry.apply(SetVentilationCommand.new(_strongest(dry))).ok)
		var hours := damp.config.problems.start_hours + 48.0
		_advance(damp, hours)
		_advance(dry, hours)
		damp_molds += _molds(damp)
		dry_molds += _molds(dry)
	assert_gt(damp_molds, 0)
	assert_eq(dry_molds, 0)


func test_the_sensor_is_bought_once() -> void:
	var state := SimState.new(_config(), 1)
	assert_false(state.climate.sensor_installed)
	var money := state.economy.money
	assert_true(state.apply(BuySensorCommand.new()).ok)
	assert_true(state.climate.sensor_installed)
	assert_eq(state.economy.money, money - state.config.climate.sensor_price)
	assert_eq(state.apply(BuySensorCommand.new()).error, CommandResult.ALREADY_DONE)
	assert_eq(state.event_log.of_type(EventLog.SENSOR_INSTALLED).size(), 1)


func test_the_sensor_needs_the_money() -> void:
	var state := SimState.new(_config(10), 1)
	assert_eq(state.apply(BuySensorCommand.new()).error, CommandResult.NOT_ENOUGH_MONEY)
	assert_false(state.climate.sensor_installed)


func test_ventilation_rules() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(SetVentilationCommand.new(-1)).error, CommandResult.UNKNOWN_CHOICE)
	assert_eq(state.apply(SetVentilationCommand.new(state.config.climate.ventilation.size())).error, CommandResult.UNKNOWN_CHOICE)
	assert_true(state.apply(SetVentilationCommand.new(1)).ok)
	assert_eq(state.climate.ventilation, 1)
	assert_eq(state.event_log.of_type(EventLog.VENTILATION_SET).size(), 1)


func test_stronger_air_costs_electricity_billed_once_a_day() -> void:
	var state := SimState.new(_config(), 1)
	var level := _strongest(state)
	assert_true(state.apply(SetVentilationCommand.new(level)).ok)
	var money := state.economy.money
	var bill_hours := state.config.climate.bill_every_hours
	_advance_in_steps(state, float(bill_hours) - STEP_HOURS)
	assert_eq(state.economy.money, money, "nothing charged before the bill")
	_advance_in_steps(state, STEP_HOURS)
	var cost := state.config.climate.ventilation[level].power_per_hour * bill_hours
	assert_eq(state.economy.money, money - cost)
	var bills := state.event_log.of_type(EventLog.POWER_BILLED)
	assert_eq(bills.size(), 1)
	assert_eq(int(bills[0].data["amount"]), cost)


func test_the_built_in_vent_costs_nothing() -> void:
	var state := SimState.new(_config(), 1)
	var money := state.economy.money
	_advance(state, 72.0)
	assert_eq(state.economy.money, money)
	assert_eq(state.event_log.of_type(EventLog.POWER_BILLED).size(), 0)


func test_quiet_hours_cost_no_electricity() -> void:
	var state := SimState.new(_config(), 1)
	assert_true(state.apply(SetVentilationCommand.new(_strongest(state))).ok)
	assert_true(state.apply(LieLowCommand.new(true)).ok)
	var money := state.economy.money
	_advance(state, float(state.config.climate.bill_every_hours) * 2.0)
	assert_eq(state.economy.money, money)


func test_an_unpaid_bill_cuts_the_power() -> void:
	var state := SimState.new(_config(0), 1)
	assert_true(state.apply(SetVentilationCommand.new(_strongest(state))).ok)
	_advance(state, float(state.config.climate.bill_every_hours) + STEP_HOURS)
	assert_eq(state.event_log.of_type(EventLog.POWER_CUT).size(), 1)
	assert_eq(state.climate.ventilation, 0, "back to the free vent")


func test_one_big_step_equals_many_small_steps() -> void:
	var big := _troubled(9)
	var small := _troubled(9)
	for state: SimState in [big, small]:
		_fill_beds(state)
		state.apply(SetVentilationCommand.new(1))
	_advance(big, 60.0)
	_advance_in_steps(small, 60.0)
	assert_eq(big.climate.to_dict(), small.climate.to_dict())
	assert_eq(big.economy.money, small.economy.money)
	assert_eq(_molds(big), _molds(small))


func test_save_and_load_keep_the_climate() -> void:
	var state := SimState.new(_config(), 2)
	state.apply(BuySensorCommand.new())
	state.apply(SetVentilationCommand.new(2))
	_advance(state, 5.0)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.climate.to_dict(), state.climate.to_dict())
	_advance(state, 30.0)
	_advance(loaded, 30.0)
	assert_eq(loaded.to_json(), state.to_json())


func test_the_report_needs_the_sensor() -> void:
	var state := SimState.new(_config(), 1)
	_fill_beds(state)
	assert_string_contains(UiText.climate_report(state), "датчик")
	state.apply(BuySensorCommand.new())
	var report := UiText.climate_report(state)
	for room: RoomDef in state.config.climate.rooms:
		assert_string_contains(report, room.display_name)
	assert_string_contains(report, "°C")
	assert_string_contains(report, "%")
	assert_string_contains(report, "плесен")
