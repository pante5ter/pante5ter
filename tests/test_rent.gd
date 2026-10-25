extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _calm(money: int) -> BalanceConfig:
	var calm := _balance.duplicate() as BalanceConfig
	calm.starting_money = money
	calm.problems = _balance.problems.duplicate() as ProblemsDef
	calm.problems.chance_per_hour = 0.0
	calm.raids = _balance.raids.duplicate() as RaidsDef
	calm.raids.chance_per_night = 0.0
	calm.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	calm.suspicion.inspection_threshold = SuspicionDef.new().inspection_threshold + 1.0
	# Rent arithmetic is checked to the pound; the helper's wage would blur it.
	calm.helper = null
	# Jack never goes home here; his nights out are tested in test_day_cycle.
	calm.day = null
	return calm


func _real_seconds_for_game_hours(hours: float) -> float:
	return hours * HOUR * _balance.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func _advance_hours(state: SimState, hours: float, step_hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours:
		var step := minf(step_hours, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(_real_seconds_for_game_hours(step)))
		elapsed += step


func _rent() -> RentDef:
	return _balance.rent


func _period() -> float:
	return _rent().period_hours


func _first_due() -> float:
	return _rent().first_due_hours


func _hours_until_eviction() -> float:
	return _first_due() + _period() * float(_rent().evict_after_missed - 1)


func test_rent_content_is_sane() -> void:
	var rent := _rent()
	assert_not_null(rent)
	assert_gt(rent.amount, 0)
	assert_gt(rent.period_hours, 0.0, "a zero period would stall the simulation")
	assert_gt(rent.first_due_hours, 0.0)
	assert_gt(rent.evict_after_missed, 0)
	assert_true(rent.missed_suspicion >= 0.0)


func test_new_game_exposes_rent_for_the_ui() -> void:
	var state := SimState.new(_balance, 1)
	assert_eq(state.rent.amount(), _rent().amount)
	assert_eq(state.rent.max_missed(), _rent().evict_after_missed)
	assert_almost_eq(state.rent.due_in(0.0), _first_due() * HOUR, 0.001)
	assert_eq(state.rent.missed, 0)
	assert_false(state.rent.evicted)


func test_rent_is_paid_on_time() -> void:
	var money := _rent().amount * 3
	var state := SimState.new(_calm(money), 1)
	_advance_hours(state, _first_due() - 0.25, 0.25)
	assert_eq(state.event_log.of_type(EventLog.RENT_PAID).size(), 0)
	assert_eq(state.economy.money, money)
	_advance_hours(state, 0.25, 0.25)
	var paid := state.event_log.of_type(EventLog.RENT_PAID)
	assert_eq(paid.size(), 1)
	assert_almost_eq(paid[0].game_time, _first_due() * HOUR, 0.001)
	assert_eq(int(paid[0].data["amount"]), _rent().amount)
	assert_eq(state.economy.money, money - _rent().amount)
	assert_eq(state.rent.missed, 0)
	assert_almost_eq(state.rent.due_in(state.clock.elapsed_game_seconds), _period() * HOUR, 0.001)


func test_broke_player_misses_rent_and_the_lord_grumbles() -> void:
	var money := _rent().amount - 1
	var state := SimState.new(_calm(money), 1)
	_advance_hours(state, _first_due(), 0.25)
	var missed := state.event_log.of_type(EventLog.RENT_MISSED)
	assert_eq(missed.size(), 1)
	assert_eq(int(missed[0].data["missed"]), 1)
	assert_eq(state.rent.missed, 1)
	assert_eq(state.economy.money, money, "a missed payment takes nothing")
	assert_almost_eq(state.suspicion.level, _rent().missed_suspicion, 0.001)
	assert_false(state.rent.evicted)


func test_payment_after_a_miss_resets_the_counter() -> void:
	var state := SimState.new(_calm(0), 1)
	_advance_hours(state, _first_due(), 0.25)
	assert_eq(state.rent.missed, 1)
	state.economy.earn(_rent().amount)
	_advance_hours(state, _period(), 0.25)
	assert_eq(state.event_log.of_type(EventLog.RENT_PAID).size(), 1)
	assert_eq(state.rent.missed, 0)
	assert_eq(state.economy.money, 0)


func test_misses_must_be_consecutive_to_evict() -> void:
	var state := SimState.new(_calm(0), 1)
	_advance_hours(state, _first_due() + _period() * float(_rent().evict_after_missed - 2), 0.25)
	assert_eq(state.rent.missed, _rent().evict_after_missed - 1)
	state.economy.earn(_rent().amount)
	_advance_hours(state, _period() * float(_rent().evict_after_missed), 0.25)
	assert_false(state.rent.evicted)
	assert_eq(state.rent.missed, _rent().evict_after_missed - 1)


func test_eviction_after_consecutive_misses_blocks_commands() -> void:
	var state := SimState.new(_calm(0), 1)
	_advance_hours(state, _hours_until_eviction() + 24.0, 24.0)
	assert_true(state.rent.evicted)
	var evicted := state.event_log.of_type(EventLog.RENT_EVICTED)
	assert_eq(evicted.size(), 1)
	assert_almost_eq(evicted[0].game_time, _hours_until_eviction() * HOUR, 0.001)
	assert_eq(state.event_log.of_type(EventLog.RENT_MISSED).size(), _rent().evict_after_missed)
	assert_almost_eq(state.clock.elapsed_game_seconds, _hours_until_eviction() * HOUR, 0.001, "the world stops at eviction")
	var before := state.to_json()
	assert_eq(state.apply(PlantCommand.new(0)).error, CommandResult.EVICTED)
	assert_eq(state.apply(BuyPlotCommand.new()).error, CommandResult.EVICTED)
	assert_eq(state.apply(AdvanceTimeCommand.new(_real_seconds_for_game_hours(5.0))).error, CommandResult.EVICTED)
	assert_eq(state.to_json(), before)


## Rent every three days with three misses allowed: an idle player is out on day 9 (day 6 with the old two-day rent).
func test_idle_player_on_real_balance_is_evicted_within_ten_days() -> void:
	var state := SimState.new(_balance, 3)
	_advance_hours(state, 10.0 * 24.0, 1.0)
	assert_true(state.rent.evicted, "doing nothing must not be a way to survive")
	var evicted := state.event_log.of_type(EventLog.RENT_EVICTED)
	assert_eq(evicted.size(), 1)
	gut.p("idle player evicted on game day %.1f" % (evicted[0].game_time / SimClock.GAME_SECONDS_PER_DAY))


func test_one_big_step_matches_many_small_steps_until_eviction() -> void:
	var big := SimState.new(_calm(_rent().amount), 9)
	var small := SimState.new(_calm(_rent().amount), 9)
	_advance_hours(big, _hours_until_eviction() + _period() * 2.0, _hours_until_eviction() + _period() * 2.0)
	_advance_hours(small, _hours_until_eviction() + _period() * 2.0, 0.25)
	assert_true(big.rent.evicted)
	assert_eq(big.to_json(), small.to_json())


func test_one_big_step_matches_many_small_steps_with_a_worker() -> void:
	var funded := _calm(_balance.worker.daily_wage * 10 + _rent().amount * 3)
	var big := SimState.new(funded, 77)
	var small := SimState.new(funded, 77)
	big.apply(HireWorkerCommand.new())
	small.apply(HireWorkerCommand.new())
	_advance_hours(big, _period() * 2.5, _period() * 2.5)
	_advance_hours(small, _period() * 2.5, 0.25)
	assert_eq(big.event_log.of_type(EventLog.RENT_PAID).size(), 2)
	assert_eq(big.economy.money, small.economy.money)
	assert_eq(big.rent.missed, small.rent.missed)
	assert_eq(JSON.stringify(big.rent.to_dict()), JSON.stringify(small.rent.to_dict()))
	assert_eq(big.event_log.size(), small.event_log.size())


func test_save_and_load_mid_period_continues_identically() -> void:
	var original := SimState.new(_calm(0), 5)
	_advance_hours(original, _first_due() + _period() * 0.4, 0.5)
	assert_eq(original.rent.missed, 1)
	var saved := original.to_json()
	var loaded := SimState.from_json(saved, _calm(0))
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), saved)
	assert_eq(loaded.rent.missed, original.rent.missed)
	assert_eq(loaded.rent.next_due_at, original.rent.next_due_at)
	original.economy.earn(_rent().amount)
	loaded.economy.earn(_rent().amount)
	_advance_hours(original, _period() * 3.0, 0.5)
	_advance_hours(loaded, _period() * 3.0, 0.5)
	assert_eq(loaded.to_json(), original.to_json())


func test_eviction_survives_save_and_load() -> void:
	var state := SimState.new(_calm(0), 5)
	_advance_hours(state, _hours_until_eviction(), 1.0)
	var loaded := SimState.from_json(state.to_json(), _calm(0))
	assert_not_null(loaded)
	assert_true(loaded.rent.evicted)
	assert_eq(loaded.apply(WaterCommand.new(0)).error, CommandResult.EVICTED)


func test_save_without_rent_is_rejected() -> void:
	var data := SimState.new(_balance, 1).to_dict()
	data.erase("rent")
	assert_null(SimState.from_json(JSON.stringify(data), _balance))
