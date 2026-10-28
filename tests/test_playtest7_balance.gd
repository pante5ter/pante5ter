extends GutTest

## Playtest round 7: «day 5, £5000+, nothing to do». A steady bot plays the real balance — trouble,
## raids and rent included — reinvests in beds, gardeners and kit, and prints its money curve.
## On day 10 there must still be something to buy or reach for.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY
const KIT_ORDER: Array[String] = ["dehumidifier", "auto_water", "coco", "grow_lamps", "hydro", "camera"]
const GARDENERS: Array[String] = ["dave", "tom", "barry"]

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _played(config: BalanceConfig, seed_value: int, days: int) -> Dictionary:
	var state := SimState.new(config, seed_value)
	assert_true(state.apply(HireWorkerCommand.new(GARDENERS[0])).ok)
	var curve: Array[int] = []
	var bought: Array[String] = []
	for hour: int in days * 24:
		state.apply(AdvanceTimeCommand.new(HOUR / DAY * config.real_seconds_per_game_day))
		if state.raids.pending:
			state.apply(RaidCommand.new(Raids.PAY))
		for order: Order in state.orders.with_status(Order.Status.OFFERED):
			state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT if _can_supply(state, order) else Orders.DECLINE))
		state.apply(PickUpParcelCommand.new())
		for target: Plot in state.grow.plots():
			if not target.problem.is_empty():
				state.apply(TreatCommand.new(target.id))
		state.apply(HaulCommand.new(Helper.ACTOR))
		state.apply(PackCommand.new())
		for order: Order in state.orders.with_status(Order.Status.ACCEPTED):
			if state.orders.can_fill(order):
				state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
		if hour % 24 == 7:
			_invest(state, bought)
		if hour % 24 == 23:
			curve.append(state.economy.money)
	return {"state": state, "curve": curve, "bought": bought}


## Takes a call only with the goods in hand, not yet promised to an accepted one.
func _can_supply(state: SimState, order: Order) -> bool:
	var promised := 0
	for accepted: Order in state.orders.with_status(Order.Status.ACCEPTED):
		promised += accepted.quantity
	var fitting := 0
	for product: Product in state.inventory.products():
		if order.accepts(product):
			fitting += 1
	return fitting - promised >= order.quantity


## Keeps a rent's worth and a margin in the bank, then: beds, a gardener per six beds, kit in order.
func _invest(state: SimState, bought: Array[String]) -> void:
	var reserve := state.rent.amount() + 600
	while state.grow.plots().size() < state.progress.plot_cap() and state.economy.money - state.config.plot_price > reserve:
		state.apply(BuyPlotCommand.new())
	var wanted := ceili(float(state.grow.plots().size()) / 6.0)
	for worker_id: String in GARDENERS:
		if state.workers.gardeners().size() >= wanted:
			break
		if not state.workers.is_hired(worker_id) and state.economy.money > reserve + 600:
			state.apply(HireWorkerCommand.new(worker_id))
	for upgrade_id: String in KIT_ORDER:
		if state.upgrades.refusal(upgrade_id).is_empty() and state.economy.money - state.upgrades.price_of(upgrade_id) > reserve:
			if state.apply(BuyUpgradeCommand.new(upgrade_id)).ok:
				bought.append("%s@%d" % [upgrade_id, state.clock.day() + 1])
	# One delivery a day: a day's worth of seeds and fertilizer stays in stock.
	var beds := state.grow.plots().size()
	var share := floori(beds / 3.0)
	if state.progress.is_strain_unlocked("elite"):
		state.apply(SetPlantingPlanCommand.new("elite", share))
		state.apply(SetAutoReorderCommand.new(Supplies.seed_item("elite"), share * 2))
	state.apply(SetPlantingPlanCommand.new("classic", share))
	state.apply(SetAutoReorderCommand.new(Supplies.seed_item("classic"), share * 3))
	state.apply(SetAutoReorderCommand.new(Supplies.FERTILIZER, beds * 3))
	state.apply(SetAutoReorderCommand.new(Supplies.PESTICIDE, maxi(2, share)))
	state.apply(SetAutoReorderCommand.new(Supplies.LAMP, maxi(2, share)))


func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	# The bot does not drive, sleep or follow the script; it plays the trade.
	config.first_day = null
	config.director = null
	config.day = null
	return config


func _report(label: String, state: SimState, curve: Array[int]) -> void:
	var line := PackedStringArray()
	for day: int in curve.size():
		line.append("d%d £%d" % [day + 1, curve[day]])
	var log := state.event_log
	var harvested := 0
	for event: SimEvent in log.of_type(EventLog.PLOT_HARVESTED):
		harvested += int(event.data["quantity"])
	var quality := 0
	for product: Product in state.inventory.products():
		quality += product.quality
	gut.p("%s: %s" % [label, ", ".join(line)])
	gut.p("  harvested %d, stock %d (avg q %d), orders paid %d / expired %d / missed %d, demand %.2f, empire £%d, level %d" % [
		harvested, state.inventory.count(), quality / maxi(state.inventory.count(), 1), log.of_type(EventLog.ORDER_PAID).size(),
		log.of_type(EventLog.ORDER_EXPIRED).size(), log.of_type(EventLog.ORDER_MISSED).size(),
		state.orders.demand_level(state.clock.elapsed_game_seconds), state.empire_value(), state.progress.reached])


func test_legacy_comparison() -> void:
	var legacy := _config()
	legacy.shop = null
	legacy.opportunities = null
	legacy.orders = _balance.orders.duplicate() as OrdersDef
	legacy.orders.demand_full_stock = 0
	legacy.orders.demand_full_takings = 0
	var probe := _played(_config(), 22, 10)["state"] as SimState
	var counts := {}
	for event: SimEvent in probe.event_log.entries():
		counts[event.type] = int(counts.get(event.type, 0)) + 1
	gut.p(str(counts))
	var stages := PackedStringArray()
	for target: Plot in probe.grow.plots():
		stages.append("%d:%s/%s/%s" % [target.id, Plot.stage_name(target.stage), target.strain_id, target.problem])
	gut.p(" ".join(stages))
	gut.p("seeds classic %d, fert %d, gardeners %d, money %d" % [probe.supplies.seeds("classic"), probe.supplies.fertilizer, probe.workers.gardeners().size(), probe.economy.money])
	for seed_value: int in [21, 22, 23, 24]:
		var old := _played(legacy, seed_value, 10)
		_report("legacy %d" % seed_value, old["state"] as SimState, old["curve"] as Array[int])
		var fresh := _played(_config(), seed_value, 10)
		_report("new %d" % seed_value, fresh["state"] as SimState, fresh["curve"] as Array[int])
		gut.p("  kit %s" % str(fresh["bought"]))
	assert_true(true)


func test_ten_days_of_steady_play_leave_something_to_reach_for() -> void:
	var played := _played(_config(), 21, 10)
	var state := played["state"] as SimState
	var curve := played["curve"] as Array[int]
	var line := PackedStringArray()
	for day: int in curve.size():
		line.append("d%d £%d" % [day + 1, curve[day]])
	gut.p("money curve: %s" % ", ".join(line))
	gut.p("day 10: empire £%d, level %d, %d beds, %d gardeners, kit %s, demand %.2f, kit bill £%d/day" % [
		state.empire_value(), state.progress.reached, state.grow.plots().size(), state.workers.gardeners().size(),
		str(played["bought"]), state.orders.demand_level(state.clock.elapsed_game_seconds), state.upgrades.daily_cost()])
	assert_false(state.rent.evicted)
	assert_eq(state.event_log.of_type(EventLog.RENT_MISSED).size(), 0, "a steady farm pays the lord every time")
	assert_gt(curve[curve.size() - 1], curve[1], "the farm grows")
	var left_to_buy := 0
	for upgrade: UpgradeDef in state.upgrades.catalogue():
		if not state.upgrades.has(upgrade.id) and not state.upgrades.on_order.has(upgrade.id) and upgrade.id != "coco":
			left_to_buy += 1
	assert_gt(left_to_buy, 0, "day 10 still has kit to buy")


func test_thirty_days_stay_solvent_and_the_kit_keeps_costing() -> void:
	var played := _played(_config(), 22, 30)
	var state := played["state"] as SimState
	var curve := played["curve"] as Array[int]
	gut.p("30 days: day 10 £%d, day 20 £%d, day 30 £%d; kit %s; bills paid %d, cut %d" % [
		curve[9], curve[19], curve[29], str(played["bought"]),
		state.event_log.of_type(EventLog.UPGRADES_BILLED).size(), state.event_log.of_type(EventLog.UPGRADES_CUT).size()])
	assert_false(state.rent.evicted)
	assert_gt(state.upgrades.daily_cost(), 0, "the kit has a running bill")
	assert_lt(state.event_log.size(), 30 * 900, "event log must not explode")
