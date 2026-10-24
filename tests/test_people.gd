extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 5000, skills: Array[String] = []) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.orders = _balance.orders.duplicate() as OrdersDef
	config.orders.base_trip_risk = 0.0
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	var helper := _balance.helper.duplicate() as WorkerDef
	helper.starting_skills = skills
	config.helper = helper
	# The first-day script holds regular calls and the director adds its own; these tests check the bare systems.
	config.first_day = null
	config.director = null
	# Jack never goes home here; his nights out are tested in test_day_cycle.
	config.day = null
	return config


func _advance(state: SimState, hours: float) -> void:
	state.apply(AdvanceTimeCommand.new(hours * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


func _advance_in_steps(state: SimState, hours: float, step: float) -> void:
	var done := 0.0
	while done < hours - 0.0001:
		_advance(state, minf(step, hours - done))
		done += step


func _accepted_order(state: SimState) -> Order:
	_advance(state, state.config.orders.first_order_hours + 0.01)
	var order := state.orders.all()[0]
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	return order


## Goods on the stash shelf and bench.
func _stock(state: SimState, count: int, quality: int, packed: bool) -> void:
	for index: int in count:
		var product := state.inventory.create(state.config.strain.id, quality)
		product.packed = packed
		product.at_stash = true


## Fresh crates still at the farm.
func _crates(state: SimState, count: int, quality: int) -> void:
	for index: int in count:
		state.inventory.create(state.config.strain.id, quality)


func _helper_tasks(state: SimState) -> int:
	return state.event_log.of_type(EventLog.WORKER_TASK_STARTED).filter(func(event: SimEvent) -> bool: return event.actors.has(Helper.ACTOR)).size()


func _event_counts(state: SimState) -> Dictionary:
	var counts: Dictionary[String, int] = {}
	for event: SimEvent in state.event_log.entries():
		counts[event.type] = counts.get(event.type, 0) + 1
	return counts


# --- content

func test_people_content_is_sane() -> void:
	var helper := _balance.helper
	assert_not_null(helper)
	assert_eq(helper.role, WorkerDef.HELPER)
	assert_gt(helper.daily_wage, 0)
	assert_gt(helper.idle_check_minutes, 0.0, "zero idle checks would stall the simulation")
	for skill_id: String in helper.starting_skills:
		assert_not_null(_balance.find_skill(skill_id), skill_id)
	for person: WorkerDef in _balance.candidates():
		assert_eq(person.role, WorkerDef.FARMHAND, person.id)
	assert_false(_balance.packer_candidates.is_empty())
	for person: WorkerDef in _balance.packer_candidates:
		assert_eq(person.role, WorkerDef.PACKER, person.id)
		assert_gt(person.idle_check_minutes, 0.0)
	var kinds := {}
	for skill: SkillDef in _balance.skills:
		assert_gt(skill.price, 0, skill.id)
		assert_gt(skill.train_hours, 0.0, skill.id)
		kinds[skill.kind] = true
	for kind: String in [SkillDef.PACK, SkillDef.DRIVING, SkillDef.ELECTRICS]:
		assert_true(kinds.has(kind), "a course teaches %s" % kind)
	for skill_id: String in _balance.retired_skills:
		assert_null(_balance.find_skill(skill_id), "bed work is the gardeners' job, not a course for him: %s" % skill_id)
		assert_gt(_balance.retired_skills[skill_id], 0, "old saves get the course fee back")
	var state := SimState.new(_balance, 1)
	for item: String in _balance.restock_basket:
		assert_gt(state.supplies.unit_price(item), 0, "basket item %s is sold" % item)


# --- the bug: a driver left without the right boxes

func test_no_dispatch_without_packed_stock_of_the_required_quality() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	_stock(state, order.quantity, order.min_quality - 1, true)
	_stock(state, order.quantity, 100, false)
	var before := state.inventory.count()
	assert_false(state.orders.can_fill(order))
	assert_true(state.couriers.available_for(order, state.clock.elapsed_game_seconds).is_empty(), "nobody may be offered for it")
	assert_eq(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).error, CommandResult.NOT_ENOUGH_PRODUCT)
	assert_eq(state.inventory.count(), before)
	assert_eq(order.status, Order.Status.ACCEPTED)
	assert_true(state.helper.present(), "he stays on the farm")
	assert_eq(state.event_log.of_type(EventLog.ORDER_DISPATCHED).size(), 0)


func test_a_short_stock_is_not_enough_either() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	_stock(state, order.quantity - 1, 100, true)
	assert_eq(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).error, CommandResult.NOT_ENOUGH_PRODUCT)
	_stock(state, 1, order.min_quality, true)
	assert_eq(state.couriers.available_for(order, state.clock.elapsed_game_seconds), [Helper.ACTOR] as Array[String])
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)


# --- the helper drives

func test_while_he_drives_sick_beds_wait() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	state.apply(PlantCommand.new(0))
	state.apply(PlantCommand.new(1))
	state.grow.plot(0).problem = Problems.MOLD
	state.grow.plot(1).problem = Problems.MOLD
	_advance(state, 0.1)
	assert_gt(_helper_tasks(state), 0, "he sees to the mold")
	_stock(state, order.quantity, 100, true)
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)
	assert_eq(state.helper.task, Workers.Task.NONE, "he drops what he was doing")
	var tasks := _helper_tasks(state)
	var away := state.helper.away_until - state.clock.elapsed_game_seconds
	_advance(state, away / SimClock.GAME_SECONDS_PER_HOUR - 0.05)
	assert_false(state.helper.present())
	assert_eq(_helper_tasks(state), tasks, "no farm work while he is on the road")
	_advance(state, 0.25)
	assert_true(state.helper.present())
	assert_gt(_helper_tasks(state), tasks, "back home, he deals with the second bed")


func test_he_cannot_take_two_orders_at_once() -> void:
	var state := SimState.new(_config(), 1)
	var first := _accepted_order(state)
	_advance(state, state.config.orders.interval_hours)
	var second := state.orders.with_status(Order.Status.OFFERED)[0]
	state.apply(AnswerOrderCommand.new(second.id, Orders.ACCEPT))
	_stock(state, first.quantity + second.quantity, 100, true)
	assert_true(state.apply(DispatchCommand.new(first.id, Helper.ACTOR)).ok)
	assert_eq(state.apply(DispatchCommand.new(second.id, Helper.ACTOR)).error, CommandResult.HELPER_AWAY)


func test_careful_driving_lowers_his_risk() -> void:
	var config := _config()
	config.orders.base_trip_risk = 0.3
	var plain := SimState.new(config, 1)
	var careful := SimState.new(_config_with_risk(0.3, ["driving"] as Array[String]), 1)
	assert_lt(careful.couriers.trip_risk(Helper.ACTOR), plain.couriers.trip_risk(Helper.ACTOR))
	assert_gt(careful.couriers.trip_risk(Helper.ACTOR), 0.0)


func _config_with_risk(risk: float, skills: Array[String]) -> BalanceConfig:
	var config := _config(5000, skills)
	config.orders.base_trip_risk = risk
	return config


# --- skills

func test_learning_costs_money_and_time_away() -> void:
	var state := SimState.new(_config(), 1)
	var skill := state.config.find_skill("electrics")
	var money := state.economy.money
	assert_true(state.apply(LearnSkillCommand.new(skill.id)).ok)
	assert_eq(state.economy.money, money - skill.price)
	assert_false(state.helper.present())
	assert_eq(state.apply(LearnSkillCommand.new("pack")).error, CommandResult.HELPER_AWAY)
	assert_eq(state.apply(LearnSkillCommand.new(skill.id)).error, CommandResult.ALREADY_DONE)
	_advance(state, skill.train_hours - 0.25)
	assert_false(state.helper.knows(SkillDef.ELECTRICS))
	_advance(state, 0.5)
	assert_true(state.helper.present())
	assert_true(state.helper.knows(SkillDef.ELECTRICS))
	assert_eq(state.event_log.of_type(EventLog.HELPER_SKILL_LEARNED).size(), 1)
	assert_eq(state.apply(LearnSkillCommand.new(skill.id)).error, CommandResult.ALREADY_DONE)


func test_learning_rules() -> void:
	var state := SimState.new(_config(10), 1)
	assert_eq(state.apply(LearnSkillCommand.new("juggling")).error, CommandResult.UNKNOWN_SKILL)
	assert_eq(state.apply(LearnSkillCommand.new("driving")).error, CommandResult.NOT_ENOUGH_MONEY)
	assert_eq(state.apply(LearnSkillCommand.new("care")).error, CommandResult.UNKNOWN_SKILL, "no bed courses any more")
	assert_true(state.helper.present())
	var alone := _config()
	alone.helper = null
	assert_eq(SimState.new(alone, 1).apply(LearnSkillCommand.new("driving")).error, CommandResult.WORKER_NOT_HIRED)


func test_without_skills_he_leaves_the_beds_to_others() -> void:
	var state := SimState.new(_config(), 1)
	_advance_in_steps(state, 6.0, 0.25)
	assert_eq(_helper_tasks(state), 0)
	for plot: Plot in state.grow.plots():
		assert_eq(plot.stage, Plot.Stage.EMPTY)


func test_he_leaves_bed_work_to_the_gardeners_whatever_he_learned_before() -> void:
	var state := SimState.new(_config(5000, ["care", "prune", "fertilize", "pack"] as Array[String]), 3)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 3))
	_advance(state, state.config.delivery_hours + 0.01)
	state.apply(PickUpParcelCommand.new())
	state.apply(PlantCommand.new(0))
	_advance_in_steps(state, 48.0, 0.5)
	for type: String in [EventLog.PLOT_PLANTED, EventLog.PLOT_WATERED, EventLog.PLOT_HARVESTED, EventLog.PLOT_FERTILIZED, EventLog.PLOT_PRUNED]:
		var his := state.event_log.of_type(type).filter(func(event: SimEvent) -> bool: return event.actors.has(Helper.ACTOR))
		assert_eq(his.size(), 0, type)
	assert_eq(state.supplies.fertilizer, 3, "the fertilizer waits for hands")


func test_pack_skill_packs_the_crates_he_brings_to_the_stash() -> void:
	var state := SimState.new(_safe_roads(_config(5000, ["pack"] as Array[String])), 1)
	_crates(state, 3, 60)
	assert_true(state.apply(HaulCommand.new(Helper.ACTOR)).ok)
	_advance(state, state.config.stash.haul_hours + 0.05)
	assert_true(state.packing.busy(), "he packs before he drives back")
	assert_false(state.helper.present())
	assert_true(state.event_log.of_type(EventLog.PACKING_STARTED)[0].actors.has(Helper.ACTOR))
	_advance_in_steps(state, 2.0, 0.25)
	assert_eq(state.packing.unpacked_count(), 0)
	assert_true(state.helper.present())


func test_without_the_pack_skill_he_drops_the_crates_and_comes_back() -> void:
	var state := SimState.new(_safe_roads(_config()), 1)
	_crates(state, 3, 60)
	assert_true(state.apply(HaulCommand.new(Helper.ACTOR)).ok)
	_advance(state, state.config.stash.haul_hours * 2.0 + 0.05)
	assert_false(state.packing.busy())
	assert_eq(state.packing.unpacked_count(), 3, "loose crates wait on the stash bench")
	assert_true(state.helper.present())


func _safe_roads(config: BalanceConfig) -> BalanceConfig:
	config.stash = _balance.stash.duplicate() as StashDef
	config.stash.base_risk = 0.0
	return config


# --- he saves the day

func test_he_treats_beds_with_what_is_in_stock() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(PlantCommand.new(0))
	state.apply(PlantCommand.new(1))
	state.grow.plot(0).problem = Problems.PESTS
	state.grow.plot(1).problem = Problems.MOLD
	_advance_in_steps(state, 1.0, 0.25)
	assert_eq(state.grow.plot(1).problem, "", "mold needs nothing but hands")
	assert_eq(state.grow.plot(0).problem, Problems.PESTS, "no pesticide in stock")
	state.apply(BuyCommand.new(Supplies.PESTICIDE, 1))
	_advance(state, state.config.delivery_hours + 0.01)
	state.apply(PickUpParcelCommand.new())
	_advance_in_steps(state, 1.0, 0.25)
	assert_eq(state.grow.plot(0).problem, "")
	assert_eq(state.supplies.count(Supplies.PESTICIDE), 0)


func test_he_dims_the_lights_before_an_inspection_and_turns_them_back_on() -> void:
	var config := _config(1000)
	config.suspicion.inspection_threshold = _balance.suspicion.inspection_threshold
	var state := SimState.new(config, 1)
	state.suspicion.add(config.suspicion.inspection_threshold + 10.0)
	_advance(state, 1.0)
	assert_true(state.suspicion.inspection_pending())
	var money := state.economy.money
	_advance_in_steps(state, config.suspicion.warning_hours - config.helper_lights_out_hours - 0.25, 0.25)
	assert_false(state.suspicion.quiet, "not yet")
	_advance_in_steps(state, 0.5, 0.25)
	assert_true(state.suspicion.quiet, "he dimmed the farm himself")
	assert_eq(state.event_log.of_type(EventLog.HELPER_SAVED).size(), 1)
	_advance_in_steps(state, 1.0, 0.25)
	assert_eq(state.event_log.of_type(EventLog.INSPECTION_PASSED).size(), 1)
	assert_eq(state.economy.money, money)
	assert_false(state.suspicion.quiet, "and switched the lamps back on")


func test_he_does_not_touch_lights_the_player_already_dimmed() -> void:
	var config := _config(1000)
	config.suspicion.inspection_threshold = _balance.suspicion.inspection_threshold
	var state := SimState.new(config, 1)
	state.suspicion.add(config.suspicion.inspection_threshold + 10.0)
	_advance(state, 1.0)
	state.apply(LieLowCommand.new(true))
	_advance_in_steps(state, config.suspicion.warning_hours + 1.0, 0.25)
	assert_eq(state.event_log.of_type(EventLog.HELPER_SAVED).size(), 0)
	assert_true(state.suspicion.quiet, "the player decides when to come back")


func test_he_sees_off_raiders_nobody_answered() -> void:
	var outcomes := {}
	for seed_value: int in range(1, 16):
		var config := _config(1000)
		config.raids.chance_per_night = 1.0
		var state := SimState.new(config, seed_value)
		_crates(state, 2, 60)
		_advance_in_steps(state, config.raids.start_hours + config.raids.night_hour + config.raids.deadline_hours + 0.1, 2.0)
		for event: SimEvent in state.event_log.of_type(EventLog.RAID_RESOLVED):
			outcomes[String(event.data["outcome"])] = true
	assert_true(outcomes.has("helper_chased"), "he wins some")
	assert_false(outcomes.has("ignored"), "raiders never walk in unopposed while he is there")


func test_loyal_helper_stays_unpaid_and_settles_later() -> void:
	var state := SimState.new(_config(0), 1)
	_advance_in_steps(state, 24.25, 0.25)
	assert_true(state.helper.exists())
	assert_eq(state.helper.wage_debt, state.config.helper.daily_wage)
	assert_eq(state.event_log.of_type(EventLog.HELPER_UNPAID).size(), 1)
	state.economy.earn(10000)
	_advance_in_steps(state, 24.0, 0.25)
	assert_eq(state.helper.wage_debt, 0)
	var paid := state.event_log.of_type(EventLog.WORKER_PAID)
	assert_eq(int(paid[paid.size() - 1].data["wage"]), 2 * state.config.helper.daily_wage)


# --- packer

func test_packer_is_hired_into_his_own_slot_and_packs_by_himself() -> void:
	var state := SimState.new(_config(), 1)
	assert_true(state.apply(HireWorkerCommand.new("tom")).ok)
	var gladys := state.config.find_packer("gladys")
	var money := state.economy.money
	assert_true(state.apply(HireWorkerCommand.new(gladys.id)).ok)
	assert_eq(state.economy.money, money - gladys.daily_wage)
	assert_true(state.workers.hired, "the farmhand keeps his place")
	assert_eq(state.apply(HireWorkerCommand.new(gladys.id)).error, CommandResult.WORKER_ALREADY_HIRED)
	_stock(state, 4, 60, false)
	_advance(state, 0.1)
	assert_true(state.packer.working)
	_advance_in_steps(state, 2.0, 0.25)
	assert_eq(state.packing.unpacked_count(), 0)
	assert_false(state.packer.working)
	assert_true(state.event_log.of_type(EventLog.PACKING_STARTED)[0].actors.has(Packer.ACTOR))
	assert_true(state.apply(FireWorkerCommand.new(gladys.id)).ok)
	assert_false(state.packer.hired)
	assert_true(state.workers.hired)


func test_unpaid_packer_quits() -> void:
	var gladys := _balance.find_packer("gladys")
	var state := SimState.new(_config(gladys.daily_wage), 1)
	state.apply(HireWorkerCommand.new(gladys.id))
	_advance_in_steps(state, 25.0, 1.0)
	assert_false(state.packer.hired)
	assert_eq(state.event_log.of_type(EventLog.WORKER_QUIT).size(), 1)


# --- shop

func test_one_tap_restock_tops_the_basket_up() -> void:
	var state := SimState.new(_config(), 1)
	var expected := state.supplies.basket_cost()
	assert_gt(expected, 0)
	var money := state.economy.money
	var result := state.apply(RestockCommand.new())
	assert_true(result.ok)
	assert_eq(result.value, expected)
	assert_eq(state.economy.money, money - expected)
	for item: String in state.config.restock_basket:
		assert_eq(state.supplies.stock_and_coming(item), state.config.restock_basket[item], item)
	assert_eq(state.apply(RestockCommand.new()).error, CommandResult.NOTHING_TO_RESTOCK)
	assert_eq(state.supplies.basket_cost(), 0)


func test_restock_skips_locked_seeds_and_stops_at_the_money() -> void:
	var config := _config(30)
	var basket: Dictionary[String, int] = {"seed:elite": 2, Supplies.FERTILIZER: 4}
	config.restock_basket = basket
	var state := SimState.new(config, 1)
	var result := state.apply(RestockCommand.new())
	assert_true(result.ok)
	assert_eq(state.supplies.stock_and_coming("seed:elite"), 0, "elite is still locked")
	assert_eq(state.supplies.stock_and_coming(Supplies.FERTILIZER), floori(30.0 / float(config.fertilizer_price)))
	var broke := SimState.new(_config(0), 1)
	assert_eq(broke.apply(RestockCommand.new()).error, CommandResult.NOT_ENOUGH_MONEY)


func test_auto_reorder_keeps_the_stock_up() -> void:
	var state := SimState.new(_config(), 1)
	assert_true(state.apply(SetAutoReorderCommand.new(Supplies.FERTILIZER, 3)).ok)
	assert_eq(state.supplies.stock_and_coming(Supplies.FERTILIZER), 3, "the first parcel goes out at once")
	_advance(state, state.config.delivery_hours + 0.01)
	state.apply(PickUpParcelCommand.new())
	state.apply(PlantCommand.new(0))
	state.apply(FertilizeCommand.new(0))
	assert_eq(state.supplies.stock_and_coming(Supplies.FERTILIZER), 2)
	_advance_in_steps(state, state.config.auto_reorder_check_hours + 0.25, 0.25)
	assert_eq(state.supplies.stock_and_coming(Supplies.FERTILIZER), 3)
	var auto := state.event_log.of_type(EventLog.SUPPLY_ORDERED).filter(func(event: SimEvent) -> bool: return event.actors.has(Supplies.AUTO_ACTOR))
	assert_eq(auto.size(), 2)
	assert_true(state.apply(SetAutoReorderCommand.new(Supplies.FERTILIZER, 0)).ok)
	assert_true(state.supplies.auto_keep.is_empty())
	assert_eq(state.supplies.next_reorder_at, INF)


func test_auto_reorder_rules() -> void:
	var state := SimState.new(_config(500), 1)
	assert_eq(state.apply(SetAutoReorderCommand.new("caviar", 2)).error, CommandResult.UNKNOWN_ITEM)
	assert_eq(state.apply(SetAutoReorderCommand.new(Supplies.FERTILIZER, -1)).error, CommandResult.INVALID_QUANTITY)
	assert_eq(state.apply(SetAutoReorderCommand.new("seed:elite", 2)).error, CommandResult.STRAIN_LOCKED)


# --- time and saves

func _busy_state(seed_value: int) -> SimState:
	var state := SimState.new(_config(20000, ["pack"] as Array[String]), seed_value)
	state.apply(HireWorkerCommand.new("dave"))
	state.apply(HireWorkerCommand.new("gladys"))
	state.apply(SetAutoReorderCommand.new(Supplies.FERTILIZER, 2))
	return state


func test_one_big_step_matches_many_small_steps_with_the_whole_crew() -> void:
	var big := _busy_state(77)
	var small := _busy_state(77)
	_advance(big, 40.0)
	_advance_in_steps(small, 40.0, 0.25)
	assert_eq_deep(_event_counts(big), _event_counts(small))
	assert_eq(big.economy.money, small.economy.money)
	assert_eq(big.inventory.count(), small.inventory.count())
	assert_eq(big.helper.to_dict(), small.helper.to_dict())


func test_save_and_load_mid_delivery_and_training_continue_identically() -> void:
	var original := _busy_state(5)
	var order := _accepted_order(original)
	_stock(original, order.quantity, 100, true)
	original.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	_advance(original, 0.3)
	var loaded := SimState.from_json(original.to_json(), original.config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), original.to_json())
	_advance_in_steps(original, 3.0, 0.25)
	_advance_in_steps(loaded, 3.0, 0.25)
	original.apply(LearnSkillCommand.new("driving"))
	loaded.apply(LearnSkillCommand.new("driving"))
	_advance(original, 1.0)
	_advance(loaded, 1.0)
	var reloaded := SimState.from_json(loaded.to_json(), original.config)
	_advance_in_steps(original, 12.0, 0.5)
	_advance_in_steps(reloaded, 12.0, 0.5)
	assert_eq(reloaded.to_json(), original.to_json())
	assert_true(reloaded.helper.knows(SkillDef.DRIVING))


func test_version_7_saves_load_with_a_fresh_helper() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(HireWorkerCommand.new("barry"))
	_advance_in_steps(state, 5.0, 0.25)
	var data := JSON.parse_string(state.to_json()) as Dictionary
	data.erase("helper")
	data.erase("packer")
	(data["supplies"] as Dictionary).erase("auto_keep")
	(data["supplies"] as Dictionary).erase("next_reorder_at")
	data["save_version"] = SimState.MIGRATABLE_VERSION
	var loaded := SimState.from_json(JSON.stringify(data), state.config)
	assert_not_null(loaded, "a v7 save still loads")
	assert_true(loaded.helper.present())
	assert_false(loaded.packer.hired)
	assert_eq(loaded.workers.definition().id, "barry")
	assert_almost_eq(loaded.helper.next_wage_at, loaded.clock.elapsed_game_seconds + SimClock.GAME_SECONDS_PER_DAY, 0.001)
	data["save_version"] = SimState.SAVE_VERSION
	assert_null(SimState.from_json(JSON.stringify(data), state.config), "a v8 save must carry the helper")


# --- words

func test_texts_agree_with_gender() -> void:
	assert_eq(PeopleText.hired_word(_balance.find_worker("dave")), "нанят")
	assert_eq(PeopleText.hired_word(_balance.find_packer("gladys")), "нанята")
	assert_eq(PeopleText.fired_word(_balance.find_packer("gladys")), "уволена")
	var state := SimState.new(_config(), 1)
	var quit := state.event_log.record(EventLog.WORKER_QUIT, 0.0, PackedStringArray([Packer.ACTOR]), {"worker_id": "gladys", "reason": "unpaid", "money": 0})
	assert_string_contains(UiText.announcement(quit, state), "Глэдис ушла")
