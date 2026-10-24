extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 500, problems: float = 0.0, raids: float = 0.0) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = problems
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = raids
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	# The script and the director roll their own dice and add their own trouble; these tests check the bare threats.
	config.first_day = null
	config.director = null
	return config


func _advance(state: SimState, hours: float) -> void:
	state.apply(AdvanceTimeCommand.new(hours * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


func _advance_in_steps(state: SimState, hours: float, step: float) -> void:
	var done := 0.0
	while done < hours:
		_advance(state, minf(step, hours - done))
		done += step


# --- empire value and milestones

func test_empire_value_counts_money_beds_and_stock() -> void:
	var state := SimState.new(_config(), 1)
	var base := state.config.starting_money + state.grow.plots().size() * state.config.plot_price
	assert_eq(state.empire_value(), base)
	var product := state.inventory.create(state.config.strain.id, 50)
	assert_eq(state.empire_value(), base + state.economy.price_of(product))


func test_milestones_raise_the_bed_cap_and_unlock_the_elite_strain() -> void:
	var state := SimState.new(_config(500), 1)
	var elite := state.config.find_strain("elite")
	assert_eq(state.progress.plot_cap(), state.config.starting_plot_cap)
	assert_false(state.progress.is_strain_unlocked(elite.id))
	assert_eq(state.apply(BuyCommand.new(Supplies.seed_item(elite.id))).error, CommandResult.STRAIN_LOCKED)
	state.economy.earn(state.config.milestones[1].value)
	state.apply(AdvanceTimeCommand.new(0.0))
	assert_eq(state.progress.reached, 2)
	assert_eq(state.progress.plot_cap(), state.config.milestones[1].plot_cap)
	assert_true(state.progress.is_strain_unlocked(elite.id))
	assert_eq(state.event_log.of_type(EventLog.MILESTONE_REACHED).size(), 2)
	assert_true(state.apply(BuyCommand.new(Supplies.seed_item(elite.id))).ok)


func test_bed_purchases_stop_at_the_current_cap() -> void:
	var config := _config(2000)
	var no_milestones: Array[MilestoneDef] = []
	config.milestones = no_milestones
	var state := SimState.new(config, 1)
	while state.grow.plots().size() < state.config.starting_plot_cap:
		assert_true(state.apply(BuyPlotCommand.new()).ok)
	assert_eq(state.apply(BuyPlotCommand.new()).error, CommandResult.MAX_PLOTS)


func test_milestones_are_never_lost_when_money_is_spent() -> void:
	var state := SimState.new(_config(50000), 1)
	assert_eq(state.progress.reached, state.config.milestones.size())
	state.economy.spend(49000)
	state.apply(AdvanceTimeCommand.new(0.0))
	assert_eq(state.progress.reached, state.config.milestones.size())


# --- problems

func test_problems_start_on_day_two_and_stop_growth_until_treated() -> void:
	var state := SimState.new(_config(5000, 1.0), 3)
	state.apply(PlantCommand.new(0))
	state.apply(WaterCommand.new(0))
	_advance(state, 0.5)
	assert_eq(state.grow.plot(0).problem, "", "nothing goes wrong on the first day")
	state.apply(HarvestCommand.new(0))
	_advance_in_steps(state, state.config.problems.start_hours, 1.0)
	state.apply(PlantCommand.new(1))
	state.apply(WaterCommand.new(1))
	_advance(state, 1.01)
	var plot := state.grow.plot(1)
	assert_true(Problems.KINDS.has(plot.problem))
	var progress := plot.progress_seconds
	state.apply(WaterCommand.new(1))
	_advance(state, 0.5)
	assert_eq(plot.progress_seconds, progress, "a sick bed does not grow")
	assert_gt(plot.dry_seconds, 0.0, "and loses quality")


func test_treating_needs_the_right_supply() -> void:
	var state := SimState.new(_config(5000), 1)
	state.apply(PlantCommand.new(0))
	var plot := state.grow.plot(0)
	assert_eq(state.apply(TreatCommand.new(0)).error, CommandResult.NO_PROBLEM)
	plot.problem = Problems.PESTS
	assert_eq(state.apply(TreatCommand.new(0)).error, CommandResult.NO_SUPPLY)
	state.apply(BuyCommand.new(Supplies.PESTICIDE))
	_advance(state, state.config.delivery_hours + 0.01)
	state.apply(PickUpParcelCommand.new())
	assert_true(state.apply(TreatCommand.new(0)).ok)
	assert_eq(plot.problem, "")
	assert_eq(state.supplies.count(Supplies.PESTICIDE), 0)
	plot.problem = Problems.MOLD
	assert_true(state.apply(TreatCommand.new(0)).ok, "mold only needs hands")
	assert_eq(state.event_log.of_type(EventLog.PLOT_TREATED).size(), 2)


func test_worker_does_not_water_a_sick_bed() -> void:
	var state := SimState.new(_config(5000), 1)
	state.apply(PlantCommand.new(0))
	state.grow.plot(0).problem = Problems.LAMP
	for plot: Plot in state.grow.plots():
		if plot.id != 0:
			plot.stage = Plot.Stage.READY
	state.apply(HireWorkerCommand.new())
	_advance(state, 0.0)
	assert_ne(state.workers.task_plot_id, 0)


# --- workers with traits

func test_candidates_differ_and_can_be_hired_by_id() -> void:
	var candidates := _balance.candidates()
	assert_gt(candidates.size(), 1)
	var state := SimState.new(_config(5000), 1)
	var dave := _balance.find_worker("dave")
	assert_true(state.apply(HireWorkerCommand.new("dave")).ok)
	assert_eq(state.workers.definition().id, "dave")
	assert_eq(state.economy.money, 5000 - dave.daily_wage)
	var fresh := SimState.new(_config(5000), 1)
	assert_eq(fresh.apply(HireWorkerCommand.new("nobody")).error, CommandResult.UNKNOWN_WORKER)


func test_competent_workers_finish_tasks_faster() -> void:
	var fast := _balance.find_worker("dave")
	var steady := _balance.find_worker("tom")
	assert_lt(fast.task_seconds(), steady.task_seconds())


func test_a_greedy_worker_steals_some_of_the_harvest() -> void:
	var config := _config(50000)
	var thief := _balance.find_worker("dave").duplicate() as WorkerDef
	thief.greed = 1.0
	thief.loyalty = 0.0
	config.worker_candidates = [thief]
	var state := SimState.new(config, 5)
	state.apply(HireWorkerCommand.new(thief.id))
	_advance_in_steps(state, 20.0, 0.5)
	var harvested := state.event_log.of_type(EventLog.PLOT_HARVESTED).size()
	assert_gt(harvested, 0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_STOLE).size(), harvested)
	assert_eq(state.inventory.count(), 0)


func test_an_honest_worker_never_steals() -> void:
	var state := SimState.new(_config(50000), 5)
	state.apply(HireWorkerCommand.new("barry"))
	_advance_in_steps(state, 20.0, 0.5)
	assert_eq(state.event_log.of_type(EventLog.WORKER_STOLE).size(), 0)


func test_a_talkative_worker_raises_suspicion_each_paid_day() -> void:
	var state := SimState.new(_config(50000), 5)
	state.apply(HireWorkerCommand.new("barry"))
	var before := state.suspicion.level
	_advance(state, 24.01)
	assert_gt(state.suspicion.level, before)


func test_hired_worker_survives_save_and_load() -> void:
	var state := SimState.new(_config(5000), 5)
	state.apply(HireWorkerCommand.new("barry"))
	var loaded := SimState.from_json(state.to_json(), _config(5000))
	assert_eq(loaded.workers.definition().id, "barry")
	assert_eq(loaded.to_json(), state.to_json())


# --- suspicion and inspections

func test_suspicion_fades_over_time() -> void:
	var state := SimState.new(_config(), 1)
	state.suspicion.add(10.0)
	_advance(state, 3.0)
	assert_lt(state.suspicion.level, 10.0)


func test_high_suspicion_warns_then_a_busy_farm_gets_fined() -> void:
	var config := _config(1000)
	# Without the helper nobody dims the lights in time.
	config.helper = null
	var state := SimState.new(config, 1)
	state.suspicion.add(state.config.suspicion.inspection_threshold + 10.0)
	_advance(state, 1.0)
	assert_true(state.suspicion.inspection_pending())
	assert_eq(state.event_log.of_type(EventLog.INSPECTION_WARNED).size(), 1)
	var money := state.economy.money
	_advance(state, state.config.suspicion.warning_hours + 0.01)
	assert_false(state.suspicion.inspection_pending())
	assert_eq(state.event_log.of_type(EventLog.INSPECTION_FAILED).size(), 1)
	assert_eq(state.economy.money, money - mini(state.config.suspicion.fine, money))


func test_a_farm_lying_low_passes_the_inspection() -> void:
	var state := SimState.new(_config(1000), 1)
	state.suspicion.add(state.config.suspicion.inspection_threshold + 10.0)
	_advance(state, 1.0)
	assert_true(state.apply(LieLowCommand.new(true)).ok)
	var money := state.economy.money
	var level := state.suspicion.level
	_advance(state, state.config.suspicion.warning_hours + 0.01)
	assert_eq(state.event_log.of_type(EventLog.INSPECTION_PASSED).size(), 1)
	assert_eq(state.economy.money, money)
	assert_lt(state.suspicion.level, level)


func test_extra_beds_draw_attention_over_time() -> void:
	var quiet := SimState.new(_config(100000), 1)
	var busy := SimState.new(_config(100000), 1)
	while busy.grow.plots().size() < busy.config.max_plots:
		busy.apply(BuyPlotCommand.new())
	quiet.suspicion.add(20.0)
	busy.suspicion.add(20.0)
	_advance(quiet, 5.0)
	_advance(busy, 5.0)
	assert_gt(busy.suspicion.level, quiet.suspicion.level)


# --- raids

func _raid_ready(money: int = 1000, alone: bool = false) -> SimState:
	var config := _config(money, 0.0, 1.0)
	if alone:
		# Nobody on the farm to see the raiders off.
		config.helper = null
	var state := SimState.new(config, 2)
	state.inventory.create(state.config.strain.id, 60)
	state.inventory.create(state.config.strain.id, 70)
	_advance_in_steps(state, state.config.raids.start_hours + state.config.raids.night_hour + 0.01, 2.0)
	return state


func test_small_players_get_raided_at_night_from_day_two() -> void:
	var state := _raid_ready()
	assert_true(state.raids.pending)
	assert_eq(state.event_log.of_type(EventLog.RAID_STARTED).size(), 1)


func test_big_players_are_left_alone() -> void:
	var state := _raid_ready(state_value_above_raid_limit())
	assert_false(state.raids.pending)


func state_value_above_raid_limit() -> int:
	return _balance.raids.max_empire_value + 1000


func test_paying_off_raiders_costs_the_bribe_only() -> void:
	var state := _raid_ready()
	var money := state.economy.money
	assert_true(state.apply(RaidCommand.new(Raids.PAY)).ok)
	assert_eq(state.economy.money, money - state.config.raids.bribe)
	assert_eq(state.inventory.count(), 2)
	assert_false(state.raids.pending)


func test_giving_goods_hands_over_half() -> void:
	var state := _raid_ready()
	assert_true(state.apply(RaidCommand.new(Raids.GIVE)).ok)
	assert_eq(state.inventory.count(), 1)


func test_ignoring_raiders_loses_all_the_stock() -> void:
	var state := _raid_ready(1000, true)
	_advance(state, state.config.raids.deadline_hours + 0.01)
	assert_false(state.raids.pending)
	assert_eq(state.inventory.count(), 0)
	var resolved := state.event_log.of_type(EventLog.RAID_RESOLVED)
	assert_eq(String(resolved[resolved.size() - 1].data["outcome"]), "ignored")


func test_chasing_either_works_or_loses_the_goods_and_makes_noise() -> void:
	var outcomes := {}
	for seed_value: int in range(1, 12):
		var state := SimState.new(_config(1000, 0.0, 1.0), seed_value)
		state.inventory.create(state.config.strain.id, 60)
		_advance_in_steps(state, state.config.raids.start_hours + state.config.raids.night_hour + 0.01, 2.0)
		if not state.raids.pending:
			continue
		var noise_before := state.suspicion.level
		assert_true(state.apply(RaidCommand.new(Raids.CHASE)).ok)
		assert_gt(state.suspicion.level, noise_before - 0.001)
		var resolved := state.event_log.of_type(EventLog.RAID_RESOLVED)
		outcomes[String(resolved[resolved.size() - 1].data["outcome"])] = true
	assert_true(outcomes.has("chased") or outcomes.has("chase_failed"))


func test_raid_choices_need_a_raid() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(RaidCommand.new(Raids.PAY)).error, CommandResult.NO_RAID)
	var raided := _raid_ready()
	assert_eq(raided.apply(RaidCommand.new("dance")).error, CommandResult.UNKNOWN_CHOICE)
	assert_eq(_raid_ready(10).apply(RaidCommand.new(Raids.PAY)).error, CommandResult.NOT_ENOUGH_MONEY)


# --- saves

func test_threats_survive_save_and_load() -> void:
	var state := _raid_ready()
	state.suspicion.add(30.0)
	state.apply(LieLowCommand.new(true))
	state.grow.plot(0).problem = Problems.MOLD
	var saved := state.to_json()
	var loaded := SimState.from_json(saved, state.config)
	assert_eq(loaded.to_json(), saved)
	_advance(state, 3.0)
	_advance(loaded, 3.0)
	assert_eq(loaded.to_json(), state.to_json())
