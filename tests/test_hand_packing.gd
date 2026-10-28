extends GutTest

## «Весы»: Jack weighs the bags himself; the sim grades the round and lifts the batch a little.

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.first_day = null
	config.director = null
	return config


func _at_stash(qualities: Array[int]) -> SimState:
	var state := SimState.new(_config(), 1)
	assert_true(state.apply(TravelCommand.new(DayCycle.STASH)).ok)
	for quality: int in qualities:
		state.inventory.create(state.config.strain.id, quality).at_stash = true
	return state


func _def(state: SimState) -> HandPackingDef:
	return state.hand_packing.definition()


func _misses(count: int, miss: float) -> Array[float]:
	var result: Array[float] = []
	for index: int in count:
		result.append(miss)
	return result


func _qualities(state: SimState) -> Array[int]:
	var result: Array[int] = []
	for product: Product in state.inventory.at_stash():
		result.append(product.quality)
	return result


func test_content_keeps_the_bonus_small() -> void:
	var def := _balance.hand_packing
	assert_not_null(def, "the scale is in the game")
	assert_between(def.max_quality_bonus, 1, 5, "a steady hand helps, it does not replace care")
	assert_between(def.max_quality_penalty, 0, 2)
	assert_between(def.min_bags, 3, 5)
	assert_between(def.max_bags, def.min_bags, 5)
	assert_lt(def.perfect_grams, def.good_grams)
	assert_lt(def.good_grams, def.fair_grams)
	assert_gt(def.scale_max_grams, def.target_grams + def.fair_grams)
	assert_lt(def.fill_seconds_min, def.fill_seconds_max)
	assert_eq(def.quality_ceiling, 100)


func test_grades_follow_the_bands_both_ways() -> void:
	var def := _balance.hand_packing
	assert_eq(HandPacking.grade(def, 0.0), HandPacking.Grade.PERFECT)
	assert_eq(HandPacking.grade(def, -def.perfect_grams), HandPacking.Grade.PERFECT)
	assert_eq(HandPacking.grade(def, def.good_grams), HandPacking.Grade.GOOD)
	assert_eq(HandPacking.grade(def, -def.fair_grams), HandPacking.Grade.FAIR)
	assert_eq(HandPacking.grade(def, def.fair_grams + 0.1), HandPacking.Grade.SLOPPY)
	assert_eq(HandPacking.grade(def, NAN), HandPacking.Grade.SLOPPY)


func test_bonus_is_capped_both_ways() -> void:
	var def := _balance.hand_packing
	assert_eq(HandPacking.quality_bonus(def, _misses(4, 0.0)), def.max_quality_bonus)
	assert_eq(HandPacking.quality_bonus(def, _misses(4, 99.0)), -def.max_quality_penalty)
	assert_eq(HandPacking.quality_bonus(def, _misses(4, def.fair_grams)), 0, "fair bags earn nothing")
	assert_eq(HandPacking.bonus_quality(def, 99, 3), 100, "never past the ceiling")
	assert_eq(HandPacking.bonus_quality(def, 100, 3), 100)
	assert_eq(HandPacking.bonus_quality(def, 0, -1), 0)


func test_bags_follow_the_batch_within_bounds() -> void:
	var state := _at_stash([60])
	var def := _def(state)
	assert_eq(state.hand_packing.bags_now(), def.min_bags, "one crate still makes a round")
	assert_eq(state.hand_packing.bags_for(50), def.max_bags)


func test_pour_speed_is_fixed_per_bag_and_varies_between_bags() -> void:
	var def := _balance.hand_packing
	var speeds: Array[float] = []
	for bag: int in def.max_bags:
		var seconds := HandPacking.fill_seconds(def, 7, bag)
		assert_between(seconds, def.fill_seconds_min, def.fill_seconds_max)
		assert_eq(seconds, HandPacking.fill_seconds(def, 7, bag), "the same bag pours the same")
		if not speeds.has(seconds):
			speeds.append(seconds)
	assert_gt(speeds.size(), 1, "bags pour at different paces")


func test_round_seed_does_not_touch_the_rng() -> void:
	var state := _at_stash([60, 70])
	var before := JSON.stringify(state.rng.to_dict())
	var seed_value := state.hand_packing.round_seed()
	assert_eq(seed_value, state.hand_packing.round_seed())
	assert_eq(JSON.stringify(state.rng.to_dict()), before)


func test_precise_round_lifts_the_batch_within_the_cap_and_logs_it() -> void:
	var state := _at_stash([60, 99, 100])
	var def := _def(state)
	var bags := state.hand_packing.bags_now()
	var result := state.apply(PackByHandCommand.new(_misses(bags, 0.1)))
	assert_true(result.ok)
	assert_eq(result.value, 3)
	assert_true(state.packing.busy(), "the usual packing job runs")
	var expected_end := state.clock.elapsed_game_seconds + state.config.orders.pack_minutes_per_unit * 60.0 * 3.0
	assert_almost_eq(state.packing.ends_at, expected_end, 0.01, "as long as packing automatically")
	var qualities := _qualities(state)
	qualities.sort()
	assert_eq(qualities, [60 + def.max_quality_bonus, 100, 100] as Array[int])
	var events := state.event_log.of_type(EventLog.PACKING_HAND_SCORED)
	assert_eq(events.size(), 1)
	var data := events[0].data
	assert_eq(int(data["quality_bonus"]), def.max_quality_bonus)
	assert_almost_eq(float(data["accuracy"]), 1.0, 0.001)
	assert_eq(int(data["perfect"]), bags)
	assert_eq(int(data["bags"]), bags)
	assert_eq(int(data["units"]), 3)
	assert_eq(int(data["units_changed"]), 2, "only the units below the ceiling changed")
	assert_true(events[0].actors.has(SimCommand.PLAYER_ACTOR))


func test_sloppy_round_costs_at_most_the_penalty() -> void:
	var state := _at_stash([50, 0])
	var def := _def(state)
	assert_true(state.apply(PackByHandCommand.new(_misses(state.hand_packing.bags_now(), -20.0))).ok)
	var qualities := _qualities(state)
	qualities.sort()
	assert_eq(qualities, [0, 50 - def.max_quality_penalty] as Array[int])


func test_packed_units_finish_as_usual() -> void:
	var state := _at_stash([60, 60])
	assert_true(state.apply(PackByHandCommand.new(_misses(state.hand_packing.bags_now(), 0.0))).ok)
	var game_seconds := state.packing.ends_at - state.clock.elapsed_game_seconds + 1.0
	state.apply(AdvanceTimeCommand.new(game_seconds * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
	assert_false(state.packing.busy())
	assert_eq(state.packing.unpacked_count(), 0)


func test_refused_rounds_change_nothing() -> void:
	var state := _at_stash([60, 70])
	var before := state.to_json()
	var bags := state.hand_packing.bags_now()
	assert_eq(state.apply(PackByHandCommand.new(_misses(bags - 1, 0.0))).error, CommandResult.INVALID_QUANTITY)
	assert_eq(state.apply(PackByHandCommand.new(_misses(bags + 1, 0.0))).error, CommandResult.INVALID_QUANTITY)
	var broken := _misses(bags, 0.0)
	broken[0] = NAN
	assert_eq(state.apply(PackByHandCommand.new(broken)).error, CommandResult.INVALID_QUANTITY)
	broken[0] = INF
	assert_eq(state.apply(PackByHandCommand.new(broken)).error, CommandResult.INVALID_QUANTITY)
	assert_eq(state.to_json(), before)


func test_only_at_the_stash_and_not_while_packing() -> void:
	var away := SimState.new(_config(), 1)
	away.inventory.create(away.config.strain.id, 60).at_stash = true
	assert_eq(away.apply(PackByHandCommand.new(_misses(3, 0.0))).error, CommandResult.NOT_AT_STASH)
	var state := _at_stash([60])
	assert_true(state.apply(PackCommand.new()).ok)
	assert_eq(state.apply(PackByHandCommand.new(_misses(3, 0.0))).error, CommandResult.ALREADY_DONE)


func test_nothing_to_pack_reports_the_usual_reason() -> void:
	var state := _at_stash([])
	assert_eq(state.apply(PackByHandCommand.new(_misses(3, 0.0))).error, CommandResult.NOTHING_TO_PACK)


func test_without_content_the_scale_is_off() -> void:
	var config := _config()
	config.hand_packing = null
	var state := SimState.new(config, 1)
	assert_false(state.hand_packing.available())
	assert_eq(state.apply(PackByHandCommand.new(_misses(3, 0.0))).error, CommandResult.UNKNOWN_COMMAND)


func test_save_keeps_the_lifted_batch_and_old_saves_still_load() -> void:
	var state := _at_stash([60])
	var plain := SimState.from_json(state.to_json(), state.config)
	assert_not_null(plain, "a save from before the scale loads as it is")
	assert_true(state.apply(PackByHandCommand.new(_misses(state.hand_packing.bags_now(), 0.0))).ok)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(_qualities(loaded), _qualities(state))
	assert_eq(loaded.event_log.of_type(EventLog.PACKING_HAND_SCORED).size(), 1)
	assert_true(loaded.packing.busy())
