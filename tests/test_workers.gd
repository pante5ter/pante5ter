extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _balance_with_money(money: int) -> BalanceConfig:
	var copy := _balance.duplicate() as BalanceConfig
	copy.starting_money = money
	return copy


func _real_seconds_for_game_hours(hours: float) -> float:
	return hours * SimClock.GAME_SECONDS_PER_HOUR * _balance.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func _advance_hours(state: SimState, hours: float, step_hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours:
		var step := minf(step_hours, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(_real_seconds_for_game_hours(step)))
		elapsed += step


func _events_by(state: SimState, type: String, actor: String) -> Array[SimEvent]:
	var matching: Array[SimEvent] = []
	for event: SimEvent in state.event_log.of_type(type):
		if event.actors.has(actor):
			matching.append(event)
	return matching


func _stages(state: SimState) -> Array[Plot.Stage]:
	var result: Array[Plot.Stage] = []
	for plot: Plot in state.grow.plots():
		result.append(plot.stage)
	return result


func _event_counts(state: SimState) -> Dictionary:
	var counts: Dictionary[String, int] = {}
	for event: SimEvent in state.event_log.entries():
		counts[event.type] = counts.get(event.type, 0) + 1
	return counts


func _qualities(state: SimState) -> Array[int]:
	var result: Array[int] = []
	for event: SimEvent in state.event_log.of_type(EventLog.PLOT_HARVESTED):
		result.append(int(event.data["quality"]))
	return result


func test_hire_pays_first_day_and_logs() -> void:
	var state := SimState.new(_balance, 1)
	var result := state.apply(HireWorkerCommand.new())
	assert_true(result.ok, result.error)
	assert_true(state.workers.hired)
	assert_eq(state.economy.money, _balance.starting_money - _balance.worker.daily_wage)
	var event := state.event_log.last()
	assert_eq(event.type, EventLog.WORKER_HIRED)
	assert_eq(event.actors, PackedStringArray([SimCommand.PLAYER_ACTOR, Workers.ACTOR]))


func test_cannot_hire_twice() -> void:
	var state := SimState.new(_balance, 1)
	state.apply(HireWorkerCommand.new())
	var money := state.economy.money
	var events := state.event_log.size()
	assert_eq(state.apply(HireWorkerCommand.new()).error, CommandResult.WORKER_ALREADY_HIRED)
	assert_eq(state.economy.money, money)
	assert_eq(state.event_log.size(), events)


func test_cannot_hire_without_money() -> void:
	var state := SimState.new(_balance_with_money(_balance.worker.daily_wage - 1), 1)
	var before := state.to_json()
	assert_eq(state.apply(HireWorkerCommand.new()).error, CommandResult.NOT_ENOUGH_MONEY)
	assert_false(state.workers.hired)
	assert_eq(state.to_json(), before)


func test_worker_starts_a_task_right_after_hire() -> void:
	var state := SimState.new(_balance, 1)
	state.apply(HireWorkerCommand.new())
	state.apply(AdvanceTimeCommand.new(0.0))
	assert_eq(state.workers.task, Workers.Task.PLANT)
	assert_between(state.workers.task_plot_id, 0, _balance.plot_count - 1)
	assert_eq(state.event_log.last().type, EventLog.WORKER_TASK_STARTED)


func test_worker_runs_the_plantation_alone() -> void:
	var state := SimState.new(_balance, 3)
	state.apply(HireWorkerCommand.new())
	_advance_hours(state, 72.0, 0.5)
	assert_true(_events_by(state, EventLog.PLOT_PLANTED, Workers.ACTOR).size() >= _balance.plot_count)
	assert_gt(_events_by(state, EventLog.PLOT_WATERED, Workers.ACTOR).size(), 0)
	assert_gt(_events_by(state, EventLog.PLOT_HARVESTED, Workers.ACTOR).size(), 0)
	assert_gt(state.inventory.count(), 0)
	assert_eq(_events_by(state, EventLog.PLOT_PLANTED, SimCommand.PLAYER_ACTOR).size(), 0)


func test_tended_plots_never_dry_out_for_long() -> void:
	var state := SimState.new(_balance, 3)
	state.apply(HireWorkerCommand.new())
	_advance_hours(state, 72.0, 0.5)
	for plot: Plot in state.grow.plots():
		assert_lt(plot.dry_seconds, 2.0 * SimClock.GAME_SECONDS_PER_HOUR, "plot %d dried too long" % plot.id)


func test_worker_is_paid_every_game_day() -> void:
	var state := SimState.new(_balance, 1)
	state.apply(HireWorkerCommand.new())
	_advance_hours(state, 49.0, 1.0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_PAID).size(), 2)
	assert_eq(state.economy.money, _balance.starting_money - 3 * _balance.worker.daily_wage)


func test_worker_quits_when_wage_cannot_be_paid() -> void:
	var state := SimState.new(_balance_with_money(_balance.worker.daily_wage), 1)
	state.apply(HireWorkerCommand.new())
	_advance_hours(state, 25.0, 1.0)
	assert_false(state.workers.hired)
	assert_eq(state.workers.task, Workers.Task.NONE)
	assert_eq(state.event_log.of_type(EventLog.WORKER_QUIT).size(), 1)
	assert_eq(state.economy.money, 0)
	var tasks_before := state.event_log.of_type(EventLog.WORKER_TASK_STARTED).size()
	_advance_hours(state, 24.0, 1.0)
	assert_eq(state.event_log.of_type(EventLog.WORKER_TASK_STARTED).size(), tasks_before)


func test_one_big_step_matches_many_small_steps() -> void:
	var big := SimState.new(_balance, 77)
	var small := SimState.new(_balance, 77)
	big.apply(HireWorkerCommand.new())
	small.apply(HireWorkerCommand.new())
	_advance_hours(big, 60.0, 60.0)
	_advance_hours(small, 60.0, 0.25)
	assert_eq_deep(_event_counts(big), _event_counts(small))
	assert_eq(_qualities(big), _qualities(small))
	assert_eq(_stages(big), _stages(small))
	assert_eq(big.economy.money, small.economy.money)
	assert_eq(big.inventory.count(), small.inventory.count())


func test_save_and_load_mid_task_continues_identically() -> void:
	var original := SimState.new(_balance, 5)
	original.apply(HireWorkerCommand.new())
	_advance_hours(original, 7.3, 0.5)
	var guard := 0
	while original.workers.task == Workers.Task.NONE and guard < 100:
		_advance_hours(original, 0.25, 0.25)
		guard += 1
	assert_ne(original.workers.task, Workers.Task.NONE)
	var loaded := SimState.from_json(original.to_json(), _balance)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), original.to_json())
	_advance_hours(original, 30.0, 0.5)
	_advance_hours(loaded, 30.0, 0.5)
	assert_eq(loaded.to_json(), original.to_json())


func test_player_taking_the_workers_plot_is_harmless() -> void:
	var state := SimState.new(_balance, 1)
	state.apply(HireWorkerCommand.new())
	state.apply(AdvanceTimeCommand.new(0.0))
	var contested := state.workers.task_plot_id
	assert_true(state.apply(PlantCommand.new(contested)).ok)
	_advance_hours(state, 1.0, 0.25)
	assert_eq(_events_by(state, EventLog.PLOT_PLANTED, Workers.ACTOR).filter(
		func(event: SimEvent) -> bool: return int(event.data["plot_id"]) == contested).size(), 0)
	assert_true(state.workers.hired)


func test_thirty_days_with_a_worker_stay_profitable_and_bounded() -> void:
	var state := SimState.new(_balance, 11)
	state.apply(HireWorkerCommand.new())
	var lowest_money := state.economy.money
	for day: int in 30:
		_advance_hours(state, 24.0, 1.0)
		lowest_money = mini(lowest_money, state.economy.money)
		for product: Product in state.inventory.products():
			state.apply(SellCommand.new(product.id))
	var profit_per_day := float(state.economy.money - _balance.starting_money) / 30.0
	gut.p("worker economy: %.0f per game day, %d events in 30 days" % [profit_per_day, state.event_log.size()])
	assert_true(state.workers.hired, "worker must not quit while the farm pays him")
	assert_true(lowest_money >= 0)
	assert_gt(profit_per_day, float(_balance.worker.daily_wage))
	assert_lt(state.event_log.size(), 30 * 200, "event log must not explode")
