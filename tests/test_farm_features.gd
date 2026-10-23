extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _rich(money: int = 10000) -> BalanceConfig:
	var copy := _balance.duplicate() as BalanceConfig
	copy.starting_money = money
	return copy


func _hours_to_real(hours: float) -> float:
	return hours * SimClock.GAME_SECONDS_PER_HOUR * _balance.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func _advance(state: SimState, hours: float) -> void:
	state.apply(AdvanceTimeCommand.new(_hours_to_real(hours)))


func _premium() -> StrainDef:
	return _balance.extra_strains[0]


func _grow_to_ready(state: SimState, plot_id: int) -> void:
	var guard := 0
	while state.grow.plot(plot_id).stage != Plot.Stage.READY and guard < 200:
		state.apply(WaterCommand.new(plot_id))
		_advance(state, 0.25)
		guard += 1


func _harvest_quality(state: SimState, plot_id: int) -> int:
	var result := state.apply(HarvestCommand.new(plot_id))
	assert_true(result.ok, result.error)
	return state.inventory.find(result.value).quality


# --- content

func test_content_has_several_strains_with_a_free_house_strain() -> void:
	assert_false(_balance.strain.needs_seeds(), "the house strain must be free so the game can always start")
	assert_gt(_balance.extra_strains.size(), 0)
	for strain: StrainDef in _balance.extra_strains:
		assert_true(strain.needs_seeds(), "%s should cost seeds" % strain.id)
		assert_eq(_balance.find_strain(strain.id), strain)
	assert_null(_balance.find_strain("nope"))


func test_house_strain_grows_in_about_three_real_minutes() -> void:
	var real_minutes := _hours_to_real(_balance.strain.growth_hours()) / 60.0
	assert_between(real_minutes, 2.0, 4.0)


# --- shop and deliveries

func test_buying_seeds_charges_now_and_delivers_later() -> void:
	var state := SimState.new(_rich(), 1)
	var item := Supplies.seed_item(_premium().id)
	var result := state.apply(BuyCommand.new(item, 3))
	assert_true(result.ok, result.error)
	assert_eq(state.economy.money, 10000 - 3 * _premium().seed_price)
	assert_eq(state.supplies.seeds(_premium().id), 0)
	assert_eq(state.supplies.pending_deliveries().size(), 1)
	_advance(state, _balance.delivery_hours + 0.01)
	assert_eq(state.supplies.seeds(_premium().id), 3)
	assert_eq(state.supplies.pending_deliveries().size(), 0)
	assert_eq(state.event_log.of_type(EventLog.SUPPLY_DELIVERED).size(), 1)


func test_shop_rejects_free_or_unknown_items_and_bad_quantities() -> void:
	var state := SimState.new(_rich(), 1)
	var before := state.to_json()
	assert_eq(state.apply(BuyCommand.new(Supplies.seed_item(_balance.strain.id))).error, CommandResult.UNKNOWN_ITEM)
	assert_eq(state.apply(BuyCommand.new("caviar")).error, CommandResult.UNKNOWN_ITEM)
	assert_eq(state.apply(BuyCommand.new(Supplies.FERTILIZER, 0)).error, CommandResult.INVALID_QUANTITY)
	assert_eq(state.to_json(), before)


func test_shop_refuses_when_money_is_short() -> void:
	var state := SimState.new(_rich(_balance.fertilizer_price - 1), 1)
	assert_eq(state.apply(BuyCommand.new(Supplies.FERTILIZER)).error, CommandResult.NOT_ENOUGH_MONEY)
	assert_eq(state.supplies.pending_deliveries().size(), 0)


# --- strains

func test_premium_strain_needs_seeds_and_uses_them_up() -> void:
	var state := SimState.new(_rich(), 1)
	assert_eq(state.apply(PlantCommand.new(0, _premium().id)).error, CommandResult.NO_SEEDS)
	state.apply(BuyCommand.new(Supplies.seed_item(_premium().id), 1))
	_advance(state, _balance.delivery_hours + 0.01)
	assert_true(state.apply(PlantCommand.new(0, _premium().id)).ok)
	assert_eq(state.supplies.seeds(_premium().id), 0)
	assert_eq(state.grow.plot(0).strain_id, _premium().id)
	assert_eq(state.apply(PlantCommand.new(1, _premium().id)).error, CommandResult.NO_SEEDS)
	assert_eq(state.apply(PlantCommand.new(1, "nope")).error, CommandResult.UNKNOWN_STRAIN)


func test_premium_strain_takes_its_own_time_and_sells_higher() -> void:
	var state := SimState.new(_rich(), 1)
	state.apply(BuyCommand.new(Supplies.seed_item(_premium().id), 1))
	_advance(state, _balance.delivery_hours + 0.01)
	state.apply(PlantCommand.new(0, _premium().id))
	state.apply(PlantCommand.new(1))
	state.apply(WaterCommand.new(0))
	state.apply(WaterCommand.new(1))
	_advance(state, _balance.strain.seed_hours + 0.01)
	assert_eq(state.grow.plot(1).stage, Plot.Stage.SPROUT)
	assert_eq(state.grow.plot(0).stage, Plot.Stage.SEED, "premium takes longer in every stage")
	assert_gt(state.economy.price_of(Product.new(1, _premium().id, 60)), state.economy.price_of(Product.new(2, _balance.strain.id, 60)))


# --- care

func test_fertilizer_and_pruning_raise_quality() -> void:
	var plain := SimState.new(_rich(), 21)
	var cared := SimState.new(_rich(), 21)
	cared.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	plain.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	_advance(cared, _balance.delivery_hours + 0.01)
	_advance(plain, _balance.delivery_hours + 0.01)
	for state: SimState in [plain, cared]:
		state.apply(PlantCommand.new(0))
	assert_true(cared.apply(FertilizeCommand.new(0)).ok)
	assert_eq(cared.supplies.fertilizer, 0)
	var guard := 0
	while cared.grow.plot(0).stage != Plot.Stage.BUSH and guard < 100:
		cared.apply(WaterCommand.new(0))
		plain.apply(WaterCommand.new(0))
		_advance(cared, 0.25)
		_advance(plain, 0.25)
		guard += 1
	assert_true(cared.apply(PruneCommand.new(0)).ok)
	_grow_to_ready(cared, 0)
	_grow_to_ready(plain, 0)
	var difference := _harvest_quality(cared, 0) - _harvest_quality(plain, 0)
	assert_eq(difference, _balance.fertilizer_bonus + _balance.prune_bonus)


func test_care_rules() -> void:
	var state := SimState.new(_rich(), 1)
	assert_eq(state.apply(FertilizeCommand.new(0)).error, CommandResult.PLOT_NOT_GROWING)
	state.apply(PlantCommand.new(0))
	assert_eq(state.apply(FertilizeCommand.new(0)).error, CommandResult.NO_FERTILIZER)
	assert_eq(state.apply(PruneCommand.new(0)).error, CommandResult.PLOT_NOT_BUSH)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 2))
	_advance(state, _balance.delivery_hours + 0.01)
	assert_true(state.apply(FertilizeCommand.new(0)).ok)
	assert_eq(state.apply(FertilizeCommand.new(0)).error, CommandResult.ALREADY_DONE)
	assert_eq(state.supplies.fertilizer, 1)


func test_care_bonuses_reset_with_a_new_planting() -> void:
	var state := SimState.new(_rich(), 1)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	_advance(state, _balance.delivery_hours + 0.01)
	state.apply(PlantCommand.new(0))
	state.apply(FertilizeCommand.new(0))
	_grow_to_ready(state, 0)
	state.apply(HarvestCommand.new(0))
	state.apply(PlantCommand.new(0))
	assert_false(state.grow.plot(0).fertilized)


# --- expansion

func test_buying_beds_until_the_cap() -> void:
	var state := SimState.new(_rich(100000), 1)
	var start := state.grow.plots().size()
	var result := state.apply(BuyPlotCommand.new())
	assert_true(result.ok)
	assert_eq(result.value, start)
	assert_eq(state.grow.plots().size(), start + 1)
	assert_eq(state.economy.money, 100000 - _balance.plot_price)
	while state.grow.plots().size() < _balance.max_plots:
		state.apply(BuyPlotCommand.new())
	assert_eq(state.apply(BuyPlotCommand.new()).error, CommandResult.MAX_PLOTS)
	assert_true(state.apply(PlantCommand.new(_balance.max_plots - 1)).ok)


func test_buying_a_bed_needs_money() -> void:
	var state := SimState.new(_rich(_balance.plot_price - 1), 1)
	assert_eq(state.apply(BuyPlotCommand.new()).error, CommandResult.NOT_ENOUGH_MONEY)


# --- orders

func test_orders_arrive_over_time_and_respect_the_cap() -> void:
	var state := SimState.new(_balance, 1)
	assert_eq(state.orders.all().size(), 0)
	_advance(state, _balance.orders.first_order_hours + 0.01)
	assert_eq(state.orders.all().size(), 1)
	var order := state.orders.all()[0]
	assert_between(order.quantity, _balance.orders.quantity_min, _balance.orders.quantity_max)
	assert_between(order.min_quality, _balance.orders.quality_min, _balance.orders.quality_max)
	assert_gt(order.reward, 0)
	_advance(state, _balance.orders.interval_hours * 10.0)
	assert_true(state.orders.all().size() <= _balance.orders.max_open)


func test_unfilled_orders_expire() -> void:
	var state := SimState.new(_balance, 1)
	_advance(state, _balance.orders.first_order_hours + 0.01)
	var order_id := state.orders.all()[0].id
	_advance(state, _balance.orders.deadline_hours + 0.01)
	assert_null(state.orders.find(order_id))
	assert_gt(state.event_log.of_type(EventLog.ORDER_EXPIRED).size(), 0)


func test_dropping_an_order_takes_goods_and_pays_after_pickup() -> void:
	var state := SimState.new(_balance, 1)
	_advance(state, _balance.orders.first_order_hours + 0.01)
	var order := state.orders.all()[0]
	assert_eq(state.apply(DropOrderCommand.new(order.id)).error, CommandResult.NOT_ENOUGH_PRODUCT)
	for index: int in order.quantity:
		state.inventory.create(_balance.strain.id, order.min_quality)
	state.inventory.create(_balance.strain.id, order.min_quality - 1)
	var money := state.economy.money
	assert_true(state.apply(DropOrderCommand.new(order.id)).ok)
	assert_eq(state.inventory.count(), 1, "only qualifying goods leave the stock")
	assert_eq(state.economy.money, money, "the courier pays on pickup")
	assert_eq(state.apply(DropOrderCommand.new(order.id)).error, CommandResult.ORDER_NOT_OPEN)
	_advance(state, _balance.orders.pickup_hours + 0.01)
	assert_eq(state.economy.money, money + order.reward)
	assert_null(state.orders.find(order.id))
	assert_eq(state.apply(DropOrderCommand.new(order.id)).error, CommandResult.UNKNOWN_ORDER)


func test_drop_uses_the_weakest_goods_that_still_qualify() -> void:
	var state := SimState.new(_balance, 1)
	_advance(state, _balance.orders.first_order_hours + 0.01)
	var order := state.orders.all()[0]
	var best := state.inventory.create(_balance.strain.id, 100)
	for index: int in order.quantity:
		state.inventory.create(_balance.strain.id, order.min_quality)
	state.apply(DropOrderCommand.new(order.id))
	assert_not_null(state.inventory.find(best.id))


func test_dropped_order_does_not_expire_before_pickup() -> void:
	var state := SimState.new(_balance, 1)
	_advance(state, _balance.orders.first_order_hours + 0.01)
	var order := state.orders.all()[0]
	for index: int in order.quantity:
		state.inventory.create(_balance.strain.id, 100)
	state.apply(DropOrderCommand.new(order.id))
	_advance(state, _balance.orders.pickup_hours + 0.01)
	assert_eq(state.event_log.of_type(EventLog.ORDER_PAID).size(), 1)
	for event: SimEvent in state.event_log.of_type(EventLog.ORDER_EXPIRED):
		assert_ne(int(event.data["order_id"]), order.id)


# --- worker

func test_firing_the_worker_stops_wages() -> void:
	var state := SimState.new(_rich(), 1)
	assert_eq(state.apply(FireWorkerCommand.new()).error, CommandResult.WORKER_NOT_HIRED)
	state.apply(HireWorkerCommand.new())
	assert_true(state.apply(FireWorkerCommand.new()).ok)
	var money := state.economy.money
	_advance(state, 30.0)
	assert_false(state.workers.hired)
	assert_eq(state.event_log.of_type(EventLog.WORKER_PAID).size(), 0)
	assert_eq(state.economy.money, money)


func test_worker_replants_the_same_strain_while_seeds_last() -> void:
	var state := SimState.new(_rich(), 4)
	state.apply(BuyCommand.new(Supplies.seed_item(_premium().id), 2))
	_advance(state, _balance.delivery_hours + 0.01)
	state.apply(PlantCommand.new(0, _premium().id))
	_grow_to_ready(state, 0)
	state.apply(HarvestCommand.new(0))
	state.apply(HireWorkerCommand.new())
	_advance(state, 2.0)
	assert_eq(state.grow.plot(0).strain_id, _premium().id)
	assert_eq(state.supplies.seeds(_premium().id), 0)


# --- saves

func test_new_systems_survive_save_and_load() -> void:
	var state := SimState.new(_rich(), 9)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 2))
	state.apply(BuyCommand.new(Supplies.seed_item(_premium().id), 2))
	state.apply(BuyPlotCommand.new())
	_advance(state, _balance.orders.first_order_hours + 0.37)
	state.apply(PlantCommand.new(6))
	var saved := state.to_json()
	var loaded := SimState.from_json(saved, _rich())
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), saved)
	_advance(state, 5.0)
	_advance(loaded, 5.0)
	assert_eq(loaded.to_json(), state.to_json())
