extends GutTest

## The stash: harvest leaves the farm in crates, is packed and shipped from the village.

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(risk: float = 0.0) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = 5000
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.first_day = null
	config.director = null
	config.day = _balance.day.duplicate() as DayDef
	config.day.late_suspicion_per_hour = 0.0
	config.stash = _balance.stash.duplicate() as StashDef
	config.stash.base_risk = risk
	return config


func _advance(state: SimState, hours: float, step: float = 0.25) -> void:
	var done := 0.0
	while done < hours - 0.0001:
		var chunk := minf(step, hours - done)
		state.apply(AdvanceTimeCommand.new(chunk * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		done += chunk


func _crates(state: SimState, count: int) -> void:
	for index: int in count:
		state.inventory.create(state.config.strain.id, 60)


func test_content_is_sane() -> void:
	var def := _balance.stash
	assert_not_null(def)
	assert_gt(def.haul_hours, 0.0)
	assert_between(def.base_risk, 0.001, 0.2, "a haul is a risk, not a coin toss")
	assert_gt(def.stopped_suspicion, 0.0)
	assert_gt(def.suspicion_risk_factor, 0.0, "a watched farm makes the drive riskier")


func test_harvest_waits_at_the_farm_in_crates() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(PlantCommand.new(0))
	state.grow.plot(0).stage = Plot.Stage.READY
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_gt(state.inventory.farm_crates().size(), 0)
	assert_true(state.inventory.at_stash().is_empty())
	assert_eq(state.apply(PackCommand.new()).error, CommandResult.CRATES_ON_FARM)


func test_reggie_drives_the_crates_and_comes_back() -> void:
	var state := SimState.new(_config(), 1)
	_crates(state, 3)
	var result := state.apply(HaulCommand.new(Helper.ACTOR))
	assert_true(result.ok)
	assert_eq(result.value, 3)
	assert_eq(state.inventory.count(), 0, "the crates are on the road")
	assert_false(state.helper.present())
	assert_eq(state.helper.away_reason, Helper.AWAY_HAUL)
	assert_eq(state.apply(HaulCommand.new(Helper.ACTOR)).error, CommandResult.HELPER_AWAY)
	_advance(state, state.config.stash.haul_hours + 0.05)
	assert_eq(state.inventory.at_stash().size(), 3)
	assert_eq(state.event_log.of_type(EventLog.HAUL_ARRIVED).size(), 1)
	_advance(state, state.config.stash.haul_hours)
	assert_true(state.helper.present(), "back after the round trip")
	assert_eq(state.packing.unpacked_count(), 3)


func test_hauling_rules() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(HaulCommand.new(Helper.ACTOR)).error, CommandResult.NOTHING_TO_HAUL)
	assert_eq(state.apply(HaulCommand.new("frank")).error, CommandResult.UNKNOWN_WORKER)
	_crates(state, 1)
	assert_true(state.apply(HaulCommand.new(Helper.ACTOR)).ok)
	_crates(state, 1)
	assert_eq(state.apply(HaulCommand.new(DayCycle.JACK)).error, CommandResult.HAUL_UNDER_WAY, "one car of crates at a time")
	var alone := _config()
	alone.helper = null
	var solo := SimState.new(alone, 1)
	_crates(solo, 1)
	assert_eq(solo.apply(HaulCommand.new(Helper.ACTOR)).error, CommandResult.WORKER_NOT_HIRED)


func test_jack_drives_the_crates_himself_and_lands_at_the_stash() -> void:
	var state := SimState.new(_config(), 1)
	_crates(state, 2)
	var start := state.clock.elapsed_game_seconds
	assert_true(state.apply(HaulCommand.new(DayCycle.JACK)).ok)
	assert_eq(state.day.place, DayCycle.STASH)
	assert_almost_eq(state.clock.elapsed_game_seconds - start, state.day.travel_seconds(), 0.001, "the drive takes game time")
	assert_eq(state.inventory.at_stash().size(), 2)
	assert_true(state.helper.present(), "Reggie stays free")
	assert_eq(state.apply(HaulCommand.new(DayCycle.JACK)).error, CommandResult.NOT_AT_FARM)


func test_a_stopped_haul_loses_the_crates_and_raises_suspicion() -> void:
	var state := SimState.new(_config(1.0), 1)
	_crates(state, 4)
	state.apply(HaulCommand.new(Helper.ACTOR))
	var before := state.suspicion.level
	_advance(state, state.config.stash.haul_hours + 0.05)
	assert_eq(state.inventory.count(), 0)
	assert_eq(state.event_log.of_type(EventLog.HAUL_STOPPED).size(), 1)
	assert_eq(int(state.event_log.of_type(EventLog.HAUL_STOPPED)[0].data["units"]), 4)
	assert_almost_eq(state.suspicion.level - before, state.config.stash.stopped_suspicion - state.config.suspicion.decay_per_hour, 1.01)


func test_heat_and_careful_driving_move_the_risk() -> void:
	var state := SimState.new(_config(0.1), 1)
	var calm := state.stash.risk(Helper.ACTOR)
	state.suspicion.add(50.0)
	assert_gt(state.stash.risk(Helper.ACTOR), calm, "a watched farm is a risky drive")
	var config := _config(0.1)
	var careful_helper := config.helper.duplicate() as WorkerDef
	careful_helper.starting_skills = ["driving"] as Array[String]
	config.helper = careful_helper
	var careful := SimState.new(config, 1)
	assert_lt(careful.stash.risk(Helper.ACTOR), calm)
	assert_almost_eq(state.stash.risk(DayCycle.JACK) / state.stash.risk(Helper.ACTOR), state.config.stash.jack_risk_factor, 0.001)


func test_raiders_only_find_the_crates_left_at_the_farm() -> void:
	var config := _config()
	config.raids.chance_per_night = 1.0
	config.helper = null
	config.starting_money = 1000
	var state := SimState.new(config, 3)
	for index: int in 3:
		var shelf := state.inventory.create(config.strain.id, 60)
		shelf.at_stash = true
		shelf.packed = true
	_advance(state, config.raids.start_hours + config.raids.night_hour + 0.5, 1.0)
	assert_eq(state.event_log.of_type(EventLog.RAID_STARTED).size(), 0, "nothing at the container to rob")
	_crates(state, 2)
	_advance(state, 24.0 + config.raids.deadline_hours, 1.0)
	assert_eq(state.event_log.of_type(EventLog.RAID_STARTED).size(), 1)
	assert_eq(state.inventory.farm_crates().size(), 0, "the crates at the container are gone")
	assert_eq(state.inventory.at_stash().size(), 3, "the stash is safe")


func test_orders_ship_only_from_the_stash() -> void:
	var state := SimState.new(_config(), 1)
	var order := state.orders.inject(2, 0, 500, 6.0, 0.0, false, 0.0)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	_crates(state, 2)
	assert_false(state.orders.can_fill(order))
	state.apply(HaulCommand.new(DayCycle.JACK))
	assert_true(state.apply(PackCommand.new()).ok)
	_advance(state, 1.0)
	assert_true(state.orders.can_fill(order))
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)


func test_a_haul_on_the_road_survives_save_and_load() -> void:
	var state := SimState.new(_config(0.3), 5)
	_crates(state, 3)
	state.apply(HaulCommand.new(Helper.ACTOR))
	_advance(state, 0.1)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.to_json(), state.to_json())
	assert_true(loaded.stash.on_the_road())
	_advance(state, 2.0)
	_advance(loaded, 2.0)
	assert_eq(loaded.to_json(), state.to_json())


func test_goods_on_the_road_still_count_towards_empire_value() -> void:
	var state := SimState.new(_config(), 1)
	_crates(state, 3)
	var before := state.empire_value()
	state.apply(HaulCommand.new(Helper.ACTOR))
	assert_eq(state.empire_value(), before)
