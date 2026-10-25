extends GutTest

## Gardeners: Tom, Dave and Barry can work the beds together, each on a bed of his own.

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 5000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.first_day = null
	config.director = null
	config.day = null
	return config


func _advance(state: SimState, hours: float, step: float = 0.25) -> void:
	var done := 0.0
	while done < hours - 0.0001:
		var chunk := minf(step, hours - done)
		state.apply(AdvanceTimeCommand.new(chunk * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		done += chunk


func test_content_offers_three_gardeners() -> void:
	assert_eq(_balance.max_gardeners, 3)
	var ids := _balance.candidates().map(func(person: WorkerDef) -> String: return person.id)
	assert_eq(ids, ["tom", "dave", "barry"])


func test_the_whole_crew_can_be_hired_and_each_draws_a_wage() -> void:
	var state := SimState.new(_config(), 1)
	var money := state.economy.money
	for id: String in ["tom", "dave", "barry"]:
		assert_true(state.apply(HireWorkerCommand.new(id)).ok, id)
	assert_eq(state.workers.gardeners().size(), 3)
	assert_eq(state.economy.money, money - state.workers.daily_wages())
	assert_eq(state.apply(HireWorkerCommand.new("dave")).error, CommandResult.WORKER_ALREADY_HIRED)
	_advance(state, 24.25, 1.0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_PAID).filter(func(event: SimEvent) -> bool: return event.actors.has(Workers.ACTOR)).size(), 3)


func test_the_crew_is_capped() -> void:
	var config := _config()
	config.max_gardeners = 2
	var state := SimState.new(config, 1)
	state.apply(HireWorkerCommand.new("tom"))
	state.apply(HireWorkerCommand.new("dave"))
	var money := state.economy.money
	assert_eq(state.apply(HireWorkerCommand.new("barry")).error, CommandResult.CREW_FULL)
	assert_eq(state.economy.money, money)


func test_firing_one_keeps_the_others() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(HireWorkerCommand.new("tom"))
	state.apply(HireWorkerCommand.new("dave"))
	assert_true(state.apply(FireWorkerCommand.new("tom")).ok)
	assert_false(state.workers.is_hired("tom"))
	assert_true(state.workers.is_hired("dave"))
	assert_eq(state.workers.definition().id, "dave", "the crew's face is whoever is left")
	assert_eq(state.apply(FireWorkerCommand.new("tom")).error, CommandResult.WORKER_NOT_HIRED)


func test_two_gardeners_never_work_the_same_bed() -> void:
	var state := SimState.new(_config(), 4)
	state.apply(HireWorkerCommand.new("tom"))
	state.apply(HireWorkerCommand.new("dave"))
	for hour: int in 48 * 4:
		_advance(state, 0.25)
		var beds: Array[int] = []
		for gardener: Gardener in state.workers.gardeners():
			if gardener.task_plot_id >= 0:
				assert_false(beds.has(gardener.task_plot_id), "two gardeners on bed %d" % gardener.task_plot_id)
				beds.append(gardener.task_plot_id)
	assert_gt(state.event_log.of_type(EventLog.PLOT_HARVESTED).size(), 0, "the crew brings in the harvest")


func test_two_gardeners_plant_a_bare_farm_faster_than_one() -> void:
	var one := SimState.new(_config(), 2)
	one.apply(HireWorkerCommand.new("tom"))
	var two := SimState.new(_config(), 2)
	two.apply(HireWorkerCommand.new("tom"))
	two.apply(HireWorkerCommand.new("dave"))
	_advance(one, 0.25, 0.05)
	_advance(two, 0.25, 0.05)
	assert_gt(two.event_log.of_type(EventLog.PLOT_PLANTED).size(), one.event_log.of_type(EventLog.PLOT_PLANTED).size())


func test_an_unpaid_gardener_quits_and_the_rest_stay() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(HireWorkerCommand.new("tom"))
	state.apply(HireWorkerCommand.new("dave"))
	state.economy.money = _balance.find_worker("tom").daily_wage
	_advance(state, 24.0 * float(state.config.unpaid_days_before_quit) + 0.25, 1.0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_QUIT).size(), 1)
	assert_eq(state.workers.gardeners().size(), 1)


func test_the_crew_survives_save_and_load() -> void:
	var state := SimState.new(_config(), 6)
	state.apply(HireWorkerCommand.new("dave"))
	state.apply(HireWorkerCommand.new("barry"))
	_advance(state, 5.0)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.to_json(), state.to_json())
	_advance(state, 12.0)
	_advance(loaded, 12.0)
	assert_eq(loaded.to_json(), state.to_json())


func test_one_big_step_equals_many_small_steps_with_three_gardeners() -> void:
	var big := SimState.new(_config(), 9)
	var small := SimState.new(_config(), 9)
	for state: SimState in [big, small]:
		for id: String in ["tom", "dave", "barry"]:
			state.apply(HireWorkerCommand.new(id))
	_advance(big, 30.0, 30.0)
	_advance(small, 30.0, 0.25)
	assert_eq(big.event_log.size(), small.event_log.size())
	assert_eq(big.economy.money, small.economy.money)
	assert_eq(big.workers.to_dict(), small.workers.to_dict())
