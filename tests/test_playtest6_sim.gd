extends GutTest

## Playtest round 6, the simulation: a crop gone while Jack stood right there, the lord asking for
## rent the day after he was paid, crates packed in a blink, clients ringing at midnight, and the
## same harvest again and again.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 50000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.day = _balance.day.duplicate() as DayDef
	config.day.late_suspicion_per_hour = 0.0
	config.stash = _balance.stash.duplicate() as StashDef
	config.stash.base_risk = 0.0
	return config


func _advance(state: SimState, hours: float, step: float = 0.25) -> void:
	var done := 0.0
	while done < hours - 0.000001:
		var chunk := minf(step, hours - done)
		state.apply(AdvanceTimeCommand.new(chunk * HOUR * state.config.real_seconds_per_game_day / DAY))
		done += chunk


## Runs the clock to an exact game time.
func _advance_to(state: SimState, at: float) -> void:
	_advance(state, (at - state.clock.elapsed_game_seconds) / HOUR)


func _with_thief(config: BalanceConfig) -> WorkerDef:
	var thief := _balance.find_worker("dave").duplicate() as WorkerDef
	thief.greed = 1.0
	thief.loyalty = 0.0
	config.worker_candidates = [thief]
	return thief


# --- 1. «Урожай пропал, хотя я стоял рядом»

func test_a_gardener_never_steals_with_jack_on_the_farm() -> void:
	var config := _config()
	var thief := _with_thief(config)
	var state := SimState.new(config, 5)
	assert_eq(state.day.place, DayCycle.FARM)
	state.apply(HireWorkerCommand.new(thief.id))
	_advance(state, 20.0, 0.5)
	assert_gt(state.event_log.of_type(EventLog.PLOT_HARVESTED).size(), 0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_STOLE).size(), 0, "the boss is in the bunker")


func test_the_same_gardener_steals_once_jack_has_gone_home() -> void:
	var config := _config()
	var thief := _with_thief(config)
	var state := SimState.new(config, 5)
	state.apply(HireWorkerCommand.new(thief.id))
	assert_true(state.apply(TravelCommand.new(DayCycle.HOME)).ok)
	_advance(state, 20.0, 0.5)
	assert_gt(state.event_log.of_type(EventLog.WORKER_STOLE).size(), 0)
	for stolen: SimEvent in state.event_log.of_type(EventLog.WORKER_STOLE):
		assert_true(stolen.game_time >= state.day.travel_seconds(), "not before Jack drove off")


func test_nobody_steals_on_the_first_day() -> void:
	var config := _config()
	config.first_day = _balance.first_day
	var thief := _with_thief(config)
	var state := SimState.new(config, 5)
	assert_true(state.first_day.active())
	state.apply(HireWorkerCommand.new(thief.id))
	assert_true(state.apply(TravelCommand.new(DayCycle.HOME)).ok)
	_advance(state, 20.0, 0.5)
	assert_gt(state.event_log.of_type(EventLog.PLOT_HARVESTED).size(), 0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_STOLE).size(), 0, "Jack's first day is not the day to lose a crop")


func test_no_courier_runs_off_on_the_first_day() -> void:
	var config := _config()
	config.first_day = _balance.first_day
	var pete := _balance.find_courier("pete").duplicate() as CourierDef
	pete.greed = 1.0
	var couriers: Array[CourierDef] = [pete]
	config.courier_candidates = couriers
	config.orders = _balance.orders.duplicate() as OrdersDef
	config.orders.base_trip_risk = 0.0
	var state := SimState.new(config, 3)
	assert_true(state.apply(HireCourierCommand.new(pete.id)).ok)
	var order := state.orders.inject(2, 0, 500, 6.0, 0.0, false, 0.0)
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	for unit: int in 2:
		var box := state.inventory.create(config.strain.id, 80)
		box.at_stash = true
		box.packed = true
	assert_true(state.apply(DispatchCommand.new(order.id, pete.id)).ok)
	_advance(state, state.couriers.trip_seconds(pete.id) / HOUR + 0.25)
	assert_eq(state.event_log.of_type(EventLog.COURIER_STOLE).size(), 0)
	assert_eq(state.event_log.of_type(EventLog.ORDER_PAID).size(), 1)


# --- 2. «Аренду просят сразу после оплаты»

func _rent_config(money: int) -> BalanceConfig:
	var config := _config(money)
	config.helper = null
	config.day = null
	return config


func test_rent_comes_every_three_days_at_the_old_daily_rate() -> void:
	var rent := _balance.rent
	assert_almost_eq(rent.period_hours, 72.0, 0.001)
	assert_almost_eq(rent.call_ahead_hours, 10.0, 0.001)
	assert_almost_eq(float(rent.amount) / rent.period_hours, 1500.0 / 48.0, 0.001, "same money per hour as £1500 every two days")
	assert_almost_eq(rent.first_due_hours, rent.period_hours, 0.001, "the first bill covers a full period too")


func test_after_paying_on_the_call_the_next_call_is_days_away() -> void:
	var state := SimState.new(_rent_config(20000), 3)
	_advance(state, _balance.rent.first_due_hours - _balance.rent.call_ahead_hours + 0.25)
	assert_true(state.rent.call_pending())
	var paid_at := state.clock.elapsed_game_seconds
	assert_true(state.apply(RentCommand.new(Rent.PAY)).ok)
	_advance(state, _balance.rent.period_hours + 1.0)
	var calls := state.event_log.of_type(EventLog.RENT_CALLED)
	assert_eq(calls.size(), 2)
	var next_call := calls[1].game_time
	assert_gte(floorf(next_call / DAY) - floorf(paid_at / DAY), 2.0, "not tomorrow: the day after at the earliest")


func test_credit_covering_the_rent_means_no_call_and_a_quiet_payment() -> void:
	var state := SimState.new(_rent_config(5000), 3)
	state.rent.add_credit(_balance.rent.amount)
	_advance(state, _balance.rent.first_due_hours + 0.25)
	assert_eq(state.event_log.of_type(EventLog.RENT_CALLED).size(), 0, "nothing to ask for")
	var paid := state.event_log.of_type(EventLog.RENT_PAID)
	assert_eq(paid.size(), 1)
	assert_almost_eq(paid[0].game_time, _balance.rent.first_due_hours * HOUR, 0.001)
	assert_eq(int(paid[0].data["amount"]), 0, "no cash changed hands")
	assert_eq(int(paid[0].data["from_credit"]), _balance.rent.amount)
	assert_eq(String(paid[0].data["where"]), Rent.FROM_CREDIT)
	assert_eq(state.economy.money, 5000)
	assert_eq(state.rent.credit, 0)
	assert_eq(state.rent.missed, 0)
	assert_string_contains(UiText.announcement(paid[0], state), "аванс")


func test_part_credit_still_brings_a_call_for_the_rest() -> void:
	var state := SimState.new(_rent_config(5000), 3)
	state.rent.add_credit(500)
	_advance(state, _balance.rent.first_due_hours + 0.25)
	var calls := state.event_log.of_type(EventLog.RENT_CALLED)
	assert_eq(calls.size(), 1)
	assert_eq(int(calls[0].data["amount"]), _balance.rent.amount - 500)
	assert_eq(state.economy.money, 5000 - _balance.rent.amount + 500)


# --- 3. «Фасовщица пакует за секунду»

func test_the_packer_waits_for_the_crates_to_be_carried_in() -> void:
	var state := SimState.new(_config(5000), 1)
	assert_true(state.apply(HireWorkerCommand.new("gladys")).ok)
	for unit: int in 2:
		state.inventory.create(state.config.strain.id, 60)
	assert_true(state.apply(HaulCommand.new(DayCycle.JACK)).ok)
	var arrived := state.clock.elapsed_game_seconds
	assert_eq(state.day.place, DayCycle.STASH)
	assert_false(state.packing.busy(), "Jack has only just pulled up")
	assert_eq(state.packing.unpacked_count(), 2)
	var unload := state.config.stash.unload_minutes * 60.0
	assert_gt(unload, 0.0)
	_advance(state, (unload - 60.0) / HOUR, 0.05)
	assert_false(state.packing.busy())
	assert_eq(state.packing.unpacked_count(), 2, "nothing packed while the crates are carried in")
	_advance(state, 2.0 / 60.0, 0.05)
	assert_true(state.packing.busy())
	var started := state.event_log.of_type(EventLog.PACKING_STARTED)
	assert_eq(started.size(), 1)
	assert_almost_eq(started[0].game_time, arrived + unload, 0.001)
	var gladys := state.config.find_packer("gladys")
	var duration := state.config.orders.pack_minutes_per_unit * 60.0 * 2.0 / gladys.competence
	assert_almost_eq(state.packing.ends_at - started[0].game_time, duration, 0.001, "the full packing time, not a blink")
	_advance(state, duration / HOUR + 0.1, 0.05)
	var done := state.event_log.of_type(EventLog.PACKING_DONE)
	assert_eq(done.size(), 1)
	assert_almost_eq(done[0].game_time, arrived + unload + duration, 0.001)


func test_the_unload_wait_survives_save_and_load() -> void:
	var state := SimState.new(_config(5000), 1)
	state.apply(HireWorkerCommand.new("gladys"))
	state.inventory.create(state.config.strain.id, 60)
	state.apply(HaulCommand.new(DayCycle.JACK))
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), state.to_json())
	_advance(state, 1.0, 0.05)
	_advance(loaded, 1.0, 0.05)
	assert_eq(loaded.to_json(), state.to_json())


func test_old_packer_saves_load_without_the_wait() -> void:
	var state := SimState.new(_config(5000), 1)
	state.apply(HireWorkerCommand.new("gladys"))
	var data := state.to_dict()
	(data["packer"] as Dictionary).erase("crates_ready_at")
	var loaded := SimState.from_json(JSON.stringify(data), state.config)
	assert_not_null(loaded)
	assert_true(loaded.packer.hired)
	assert_eq(loaded.packer.crates_ready_at, 0.0)


# --- 4. «Клиенты звонят в полночь»

func _hour_of(at: float) -> float:
	return fmod(at, DAY) / HOUR


## The opening night belongs to the prologue: the game starts at midnight and Reggie's first call rings in it.
func _first_quiet_at() -> float:
	return _balance.orders.quiet_from_hour * HOUR


func _is_quiet_hour(at: float) -> bool:
	var hour := _hour_of(at)
	return at >= _first_quiet_at() and (hour >= _balance.orders.quiet_from_hour or hour < _balance.day.wake_hour)


func _calls_after(state: SimState, at: float) -> Array[SimEvent]:
	return state.event_log.of_type(EventLog.ORDER_RECEIVED).filter(func(event: SimEvent) -> bool: return event.game_time >= at)


func test_quiet_hours_are_content() -> void:
	assert_almost_eq(_balance.orders.quiet_from_hour, 22.0, 0.001)
	assert_almost_eq(_balance.day.wake_hour, 6.0, 0.001)


func test_regular_callers_wait_for_the_morning() -> void:
	var state := SimState.new(_config(), 7)
	_advance(state, 3.0 * 24.0, 1.0)
	var calls := state.event_log.of_type(EventLog.ORDER_RECEIVED)
	assert_gt(calls.size(), 5)
	for call: SimEvent in calls:
		assert_false(_is_quiet_hour(call.game_time), "a call at %.2f h" % _hour_of(call.game_time))
	var night_over := (24.0 + _balance.day.wake_hour) * HOUR
	assert_almost_eq(_calls_after(state, _first_quiet_at())[0].game_time, night_over, 0.001, "the night's call comes at the wake hour, not never")


func test_a_call_due_at_night_is_postponed_not_dropped() -> void:
	var state := SimState.new(_config(), 7)
	_advance(state, 21.0)
	var before := state.event_log.of_type(EventLog.ORDER_RECEIVED).size()
	state.orders.next_spawn_at = 23.0 * HOUR
	_advance(state, 31.0 - 21.0)
	var calls := state.event_log.of_type(EventLog.ORDER_RECEIVED)
	assert_gt(calls.size(), before)
	assert_almost_eq(calls[before].game_time, (24.0 + _balance.day.wake_hour) * HOUR, 0.001)


func test_daytime_calls_keep_their_rhythm() -> void:
	var state := SimState.new(_config(), 7)
	state.orders.next_spawn_at = 10.0 * HOUR
	_advance(state, 13.0)
	var calls := state.event_log.of_type(EventLog.ORDER_RECEIVED)
	assert_eq(calls.size(), 2)
	assert_almost_eq(calls[0].game_time, 10.0 * HOUR, 0.001)
	assert_almost_eq(calls[1].game_time, (10.0 + _balance.orders.interval_hours) * HOUR, 0.001)


func _urgent_only(config: BalanceConfig) -> void:
	config.director = _balance.director.duplicate() as DirectorDef
	config.director.quiet_real_seconds = 20.0
	config.director.lord_visit_weight = 0.0
	config.director.rumour_weight = 0.0
	config.director.breakdown_weight = 0.0
	config.director.courier_trouble_weight = 0.0
	config.director.story_weight = 0.0


func test_urgent_calls_also_wait_for_the_morning() -> void:
	var config := _config()
	_urgent_only(config)
	var state := SimState.new(config, 7)
	var morning := (24.0 + _balance.day.wake_hour) * HOUR
	_advance_to(state, morning - 0.25 * HOUR)
	assert_eq(_urgent_calls(state, _first_quiet_at()).size(), 0, "nobody rings at night, however urgent")
	assert_lt(state.director.urgent_call_at, INF, "one was put off")
	_advance(state, 0.5)
	var urgent := _urgent_calls(state, _first_quiet_at())
	assert_eq(urgent.size(), 1, "the night's urgent call is not lost")
	assert_almost_eq(urgent[0].game_time, morning, 0.001)
	_advance(state, 2.0 * 24.0, 1.0)
	for call: SimEvent in _urgent_calls(state):
		assert_false(_is_quiet_hour(call.game_time), "an urgent call at %.2f h" % _hour_of(call.game_time))


func test_a_postponed_urgent_call_survives_save_and_load() -> void:
	var config := _config()
	_urgent_only(config)
	var state := SimState.new(config, 7)
	_advance(state, 25.0)
	assert_lt(state.director.urgent_call_at, INF)
	var loaded := SimState.from_json(state.to_json(), config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), state.to_json())
	_advance(state, 6.0)
	_advance(loaded, 6.0)
	assert_eq(loaded.to_json(), state.to_json())
	var old := state.to_dict()
	(old["director"] as Dictionary).erase("urgent_call_at")
	var migrated := SimState.from_json(JSON.stringify(old), config)
	assert_not_null(migrated)
	assert_eq(migrated.director.urgent_call_at, INF)


func _urgent_calls(state: SimState, since: float = 0.0) -> Array[SimEvent]:
	return _calls_after(state, since).filter(func(event: SimEvent) -> bool: return event.data.get("urgent", false) == true)


func test_the_opening_night_still_has_the_prologue_call() -> void:
	var state := SimState.new(_config(), 7)
	_advance(state, _balance.orders.first_order_hours + 0.25)
	var calls := state.event_log.of_type(EventLog.ORDER_RECEIVED)
	assert_eq(calls.size(), 1)
	assert_almost_eq(calls[0].game_time, _balance.orders.first_order_hours * HOUR, 0.001)


func test_at_night_the_director_brings_something_else_instead() -> void:
	var config := _config()
	_urgent_only(config)
	var state := SimState.new(config, 7)
	_advance(state, 23.0)
	config.director.story_weight = 1.0
	_advance(state, 2.0)
	var night := state.event_log.of_type(EventLog.DIRECTOR_EVENT).filter(func(event: SimEvent) -> bool: return _is_quiet_hour(event.game_time))
	assert_gt(night.size(), 0, "a quiet night still gets its village story")
	for event: SimEvent in night:
		assert_ne(String(event.data["kind"]), Director.URGENT_ORDER)


# --- 5. «Урожай всегда одинаковый»

## Before round 6: base_yield 1 plus 0..bonus_yield_max (2, 2 and 3).
const OLD_MEAN_YIELD: Dictionary[String, float] = {"basic": 2.0, "classic": 2.0, "elite": 2.5}


func _ripe(state: SimState, strain_id: String) -> void:
	var plot := state.grow.plot(0)
	plot.reset()
	plot.stage = Plot.Stage.READY
	plot.strain_id = strain_id


func _harvests(state: SimState, strain_id: String, times: int) -> Array[int]:
	var amounts: Array[int] = []
	for index: int in times:
		_ripe(state, strain_id)
		assert_true(state.apply(HarvestCommand.new(0)).ok)
		amounts.append(int((state.event_log.of_type(EventLog.PLOT_HARVESTED).back() as SimEvent).data["quantity"]))
	return amounts


func test_every_strain_has_a_yield_range_around_the_old_mean() -> void:
	for strain: StrainDef in _balance.strains():
		assert_gt(strain.yield_max, strain.yield_min, "%s varies" % strain.id)
		assert_gte(strain.yield_min, 1, "%s never yields nothing" % strain.id)
		assert_almost_eq(strain.mean_yield(), OLD_MEAN_YIELD[strain.id], 0.001, "%s keeps its average" % strain.id)


func test_no_two_harvests_of_a_strain_in_a_row_are_the_same() -> void:
	var state := SimState.new(_config(), 11)
	for strain: StrainDef in _balance.strains():
		var amounts := _harvests(state, strain.id, 40)
		for index: int in range(1, amounts.size()):
			assert_ne(amounts[index], amounts[index - 1], "%s harvest %d repeats the last one" % [strain.id, index])
		for amount: int in amounts:
			assert_between(amount, strain.yield_min, strain.yield_max)


func test_the_average_harvest_stays_where_it_was() -> void:
	var state := SimState.new(_config(), 13)
	for strain: StrainDef in _balance.strains():
		var amounts := _harvests(state, strain.id, 400)
		var total := 0
		for amount: int in amounts:
			total += amount
		assert_almost_eq(float(total) / float(amounts.size()), OLD_MEAN_YIELD[strain.id], 0.15, "%s on average" % strain.id)


func test_the_last_harvests_survive_save_and_load() -> void:
	var state := SimState.new(_config(), 11)
	_harvests(state, "classic", 3)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), state.to_json())
	assert_eq(_harvests(loaded, "classic", 5), _harvests(state, "classic", 5))
