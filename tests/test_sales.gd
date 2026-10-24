extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 5000, base_risk: float = 0.0, haggle: float = 0.5) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.orders = _balance.orders.duplicate() as OrdersDef
	config.orders.base_trip_risk = base_risk
	config.orders.haggle_success = haggle
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	return config


func _advance(state: SimState, hours: float) -> void:
	state.apply(AdvanceTimeCommand.new(hours * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


func _first_call(state: SimState) -> Order:
	_advance(state, state.config.orders.first_order_hours + 0.01)
	return state.orders.all()[0]


func _stock_packed(state: SimState, count: int, quality: int) -> void:
	for index: int in count:
		state.inventory.create(state.config.strain.id, quality).packed = true


func _accepted_order(state: SimState) -> Order:
	var order := _first_call(state)
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	return order


# --- calls

func test_calls_come_in_and_hang_up_if_unanswered() -> void:
	var state := SimState.new(_config(), 1)
	var order := _first_call(state)
	assert_eq(order.status, Order.Status.OFFERED)
	_advance(state, state.config.orders.answer_hours + 0.01)
	assert_null(state.orders.find(order.id))
	assert_eq(state.event_log.of_type(EventLog.ORDER_MISSED).size(), 1)


func test_accepting_starts_the_delivery_deadline() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	assert_eq(order.status, Order.Status.ACCEPTED)
	_advance(state, state.config.orders.answer_hours + 0.5)
	assert_not_null(state.orders.find(order.id), "accepted orders no longer hang up")
	_advance(state, state.config.orders.deadline_hours)
	assert_null(state.orders.find(order.id))
	assert_gt(state.event_log.of_type(EventLog.ORDER_EXPIRED).size(), 0)


func test_declining_removes_the_call() -> void:
	var state := SimState.new(_config(), 1)
	var order := _first_call(state)
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.DECLINE)).ok)
	assert_null(state.orders.find(order.id))
	assert_eq(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).error, CommandResult.UNKNOWN_ORDER)


func test_haggling_raises_the_price_when_it_works() -> void:
	var state := SimState.new(_config(5000, 0.0, 1.0), 1)
	var order := _first_call(state)
	var reward := order.reward
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.HAGGLE)).ok)
	assert_eq(order.reward, roundi(float(reward) * (1.0 + state.config.orders.haggle_bonus)))
	assert_eq(state.apply(AnswerOrderCommand.new(order.id, Orders.HAGGLE)).error, CommandResult.ALREADY_DONE)
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)


func test_haggling_can_lose_the_client() -> void:
	var state := SimState.new(_config(5000, 0.0, 0.0), 1)
	var order := _first_call(state)
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.HAGGLE)).ok)
	assert_null(state.orders.find(order.id))
	assert_eq(state.event_log.of_type(EventLog.ORDER_WALKED_AWAY).size(), 1)


func test_answers_need_a_live_call() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	assert_eq(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).error, CommandResult.ORDER_NOT_OPEN)
	var other := SimState.new(_config(), 1)
	var call := _first_call(other)
	assert_eq(other.apply(AnswerOrderCommand.new(call.id, "shout")).error, CommandResult.UNKNOWN_CHOICE)


# --- packing

func test_harvest_must_be_packed_before_it_can_ship() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	for index: int in order.quantity:
		state.inventory.create(state.config.strain.id, 100)
	assert_false(state.orders.can_fill(order), "loose harvest does not ship")
	assert_eq(state.apply(PackCommand.new()).value, order.quantity)
	assert_eq(state.apply(PackCommand.new()).error, CommandResult.ALREADY_DONE)
	_advance(state, state.config.orders.pack_minutes_per_unit * float(order.quantity) / 60.0 + 0.01)
	assert_false(state.packing.busy())
	assert_true(state.orders.can_fill(order))
	assert_eq(state.event_log.of_type(EventLog.PACKING_DONE).size(), 1)


func test_packing_needs_harvest() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(PackCommand.new()).error, CommandResult.NOTHING_TO_PACK)


# --- couriers

func test_the_helper_delivers_without_a_fee() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	var money := state.economy.money
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)
	assert_eq(order.status, Order.Status.IN_TRANSIT)
	assert_eq(state.inventory.count(), 0)
	assert_false(state.couriers.is_free(Helper.ACTOR, state.clock.elapsed_game_seconds))
	assert_false(state.helper.present(), "he leaves the farm for the trip")
	_advance(state, state.config.orders.trip_hours + 0.01)
	assert_eq(state.economy.money, money + order.reward)
	assert_null(state.orders.find(order.id))
	_advance(state, state.config.orders.trip_hours * 0.5)
	assert_true(state.helper.present(), "and comes back after the return leg")


func test_jack_no_longer_drives_orders() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	assert_eq(state.apply(DispatchCommand.new(order.id, Couriers.JACK)).error, CommandResult.WORKER_NOT_HIRED)
	assert_eq(order.status, Order.Status.ACCEPTED)
	assert_true(state.couriers.is_free(Couriers.JACK, state.clock.elapsed_game_seconds))


func test_hired_courier_keeps_his_cut_and_comes_back() -> void:
	var state := SimState.new(_config(), 1)
	var frank := state.config.find_courier("frank")
	assert_true(state.apply(HireCourierCommand.new(frank.id)).ok)
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	var money := state.economy.money
	assert_true(state.apply(DispatchCommand.new(order.id, frank.id)).ok)
	assert_eq(state.apply(DispatchCommand.new(order.id, frank.id)).error, CommandResult.ORDER_NOT_OPEN)
	_advance(state, state.couriers.trip_seconds(frank.id) / SimClock.GAME_SECONDS_PER_HOUR + 0.01)
	var fee := roundi(float(order.reward) * frank.cut)
	assert_eq(state.economy.money, money + order.reward - fee)
	_advance(state, state.couriers.trip_seconds(frank.id) / SimClock.GAME_SECONDS_PER_HOUR)
	assert_true(state.couriers.is_free(frank.id, state.clock.elapsed_game_seconds))


func test_faster_couriers_arrive_sooner() -> void:
	var state := SimState.new(_config(), 1)
	assert_lt(state.couriers.trip_seconds("harry"), state.couriers.trip_seconds("frank"))


func test_dispatch_rules() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	assert_eq(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).error, CommandResult.NOT_ENOUGH_PRODUCT)
	assert_eq(state.apply(DispatchCommand.new(order.id, "frank")).error, CommandResult.WORKER_NOT_HIRED)
	_stock_packed(state, order.quantity, 100)
	state.apply(LieLowCommand.new(true))
	assert_eq(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).error, CommandResult.LYING_LOW)


func test_courier_hiring_rules() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(HireCourierCommand.new("nobody")).error, CommandResult.UNKNOWN_WORKER)
	assert_true(state.apply(HireCourierCommand.new("harry")).ok)
	assert_eq(state.apply(HireCourierCommand.new("harry")).error, CommandResult.WORKER_ALREADY_HIRED)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	assert_eq(state.apply(HireCourierCommand.new("frank")).error, CommandResult.TOO_MANY_COURIERS)
	assert_true(state.apply(FireCourierCommand.new("pete")).ok)
	assert_true(state.apply(HireCourierCommand.new("frank")).ok)
	var poor := SimState.new(_config(10), 1)
	assert_eq(poor.apply(HireCourierCommand.new("frank")).error, CommandResult.NOT_ENOUGH_MONEY)


func test_a_stopped_delivery_loses_the_goods_and_raises_suspicion() -> void:
	var config := _config(5000, 1.0)
	var reckless := config.helper.duplicate() as WorkerDef
	reckless.reliability = 0.0
	config.helper = reckless
	var state := SimState.new(config, 1)
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	var money := state.economy.money
	state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	var before := state.suspicion.level
	_advance(state, state.config.orders.trip_hours + 0.01)
	assert_eq(state.event_log.of_type(EventLog.DELIVERY_STOPPED).size(), 1)
	assert_eq(state.economy.money, money)
	assert_gt(state.suspicion.level, before)


func test_risk_grows_with_suspicion_and_falls_with_reliability() -> void:
	var state := SimState.new(_config(5000, 0.2), 1)
	var calm := state.couriers.trip_risk("frank")
	assert_lt(calm, state.couriers.trip_risk("harry"))
	state.suspicion.add(50.0)
	assert_gt(state.couriers.trip_risk("frank"), calm)


func test_a_greedy_courier_can_run_off_with_the_goods() -> void:
	var config := _config()
	var thief := config.find_courier("pete").duplicate() as CourierDef
	thief.greed = 1.0
	var thieves: Array[CourierDef] = [thief]
	config.courier_candidates = thieves
	var state := SimState.new(config, 1)
	state.apply(HireCourierCommand.new(thief.id))
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	state.apply(DispatchCommand.new(order.id, thief.id))
	_advance(state, state.couriers.trip_seconds(thief.id) / SimClock.GAME_SECONDS_PER_HOUR + 0.01)
	assert_eq(state.event_log.of_type(EventLog.COURIER_STOLE).size(), 1)
	assert_false(state.couriers.hired.has(thief.id))


func test_dispatching_raises_suspicion() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	assert_almost_eq(state.suspicion.level, state.config.suspicion.per_delivery, 0.01)


func test_goods_on_the_road_count_towards_empire_value() -> void:
	var state := SimState.new(_config(), 1)
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	var base := state.config.starting_money + state.grow.plots().size() * state.config.plot_price
	state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	assert_eq(state.empire_value(), base + order.reward)


# --- parcels

func test_shop_deliveries_wait_at_the_container_until_picked_up() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 2))
	_advance(state, state.config.delivery_hours + 0.01)
	assert_eq(state.supplies.parcel().size(), 1)
	assert_eq(state.supplies.fertilizer, 0, "not usable until picked up")
	assert_eq(state.apply(PickUpParcelCommand.new()).value, 2)
	assert_eq(state.supplies.fertilizer, 2)
	assert_eq(state.apply(PickUpParcelCommand.new()).error, CommandResult.NO_PARCEL)


# --- lying low

func test_lying_low_pauses_growth_and_workers() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(HireWorkerCommand.new())
	state.apply(PlantCommand.new(0))
	state.apply(WaterCommand.new(0))
	state.apply(LieLowCommand.new(true))
	var tasks := state.event_log.of_type(EventLog.WORKER_TASK_STARTED).size()
	var progress := state.grow.plot(0).progress_seconds
	_advance(state, 2.0)
	assert_eq(state.grow.plot(0).progress_seconds, progress)
	assert_eq(state.event_log.of_type(EventLog.WORKER_TASK_STARTED).size(), tasks)
	assert_eq(state.apply(LieLowCommand.new(true)).error, CommandResult.ALREADY_DONE)
	state.apply(LieLowCommand.new(false))
	_advance(state, 0.5)
	assert_gt(state.grow.plot(0).progress_seconds, progress)


# --- saves

func test_sales_survive_save_and_load() -> void:
	var state := SimState.new(_config(5000, 0.3), 7)
	state.apply(HireCourierCommand.new("harry"))
	var order := _accepted_order(state)
	_stock_packed(state, order.quantity, 100)
	state.inventory.create(state.config.strain.id, 55)
	state.apply(PackCommand.new())
	state.apply(DispatchCommand.new(order.id, "harry"))
	state.apply(BuyCommand.new(Supplies.LAMP, 1))
	_advance(state, 0.37)
	var saved := state.to_json()
	var loaded := SimState.from_json(saved, state.config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), saved)
	_advance(state, 4.0)
	_advance(loaded, 4.0)
	assert_eq(loaded.to_json(), state.to_json())
