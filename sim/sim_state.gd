class_name SimState
extends RefCounted

const SAVE_VERSION: int = 5
const REQUIRED_SAVE_KEYS: Array[String] = ["save_version", "clock", "rng", "economy", "inventory", "plots", "workers", "supplies", "orders", "progress", "problems", "suspicion", "raids", "event_log"]

var config: BalanceConfig
var clock: SimClock
var rng: SimRng
var event_log: EventLog
var inventory: Inventory
var grow: Grow
var economy: Economy
var workers: Workers
var supplies: Supplies
var orders: Orders
var progress: Progress
var problems: Problems
var suspicion: Suspicion
var raids: Raids


func _init(balance: BalanceConfig, seed_value: int) -> void:
	config = balance
	clock = SimClock.new(balance.real_seconds_per_game_day)
	rng = SimRng.new(seed_value)
	event_log = EventLog.new()
	inventory = Inventory.new()
	grow = Grow.new(balance.strain, balance.plot_count, rng, event_log, inventory)
	economy = Economy.new(balance.strain, balance.starting_money, event_log, inventory)
	economy.attach(balance)
	progress = Progress.new(balance, event_log)
	supplies = Supplies.new(balance, economy, event_log)
	supplies.attach(progress)
	grow.attach(balance, supplies, progress)
	suspicion = Suspicion.new(balance.suspicion, grow, economy, event_log)
	workers = Workers.new(balance.worker, grow, economy, event_log)
	workers.attach(balance, rng, inventory, suspicion)
	orders = Orders.new(balance.orders, balance.strain, rng, inventory, economy, event_log)
	problems = Problems.new(balance.problems, grow, supplies, rng, event_log)
	raids = Raids.new(balance.raids, rng, inventory, economy, orders, workers, suspicion, event_log, empire_value)
	progress.update(empire_value(), clock.elapsed_game_seconds)


func apply(command: SimCommand) -> CommandResult:
	var result := _apply(command)
	progress.update(empire_value(), clock.elapsed_game_seconds)
	return result


func empire_value() -> int:
	var value := economy.money + grow.plots().size() * config.plot_price
	for product: Product in inventory.products():
		value += economy.price_of(product)
	for order: Order in orders.all():
		if order.status == Order.Status.DROPPED:
			value += order.reward
	return value


func _apply(command: SimCommand) -> CommandResult:
	var now := clock.elapsed_game_seconds
	if command is AdvanceTimeCommand:
		return _advance_time((command as AdvanceTimeCommand).real_seconds)
	if command is PlantCommand:
		var plant := command as PlantCommand
		return grow.plant(plant.plot_id, now, command.actor, plant.strain_id)
	if command is FertilizeCommand:
		return grow.fertilize((command as FertilizeCommand).plot_id, now, command.actor)
	if command is PruneCommand:
		return grow.prune((command as PruneCommand).plot_id, now, command.actor)
	if command is WaterCommand:
		return grow.water((command as WaterCommand).plot_id, now, command.actor)
	if command is HarvestCommand:
		return grow.harvest((command as HarvestCommand).plot_id, now, command.actor)
	if command is SellCommand:
		return economy.sell((command as SellCommand).product_id, now, command.actor)
	if command is HireWorkerCommand:
		return workers.hire(now, command.actor, (command as HireWorkerCommand).worker_id)
	if command is TreatCommand:
		return problems.treat((command as TreatCommand).plot_id, now, command.actor)
	if command is MaskEntranceCommand:
		return suspicion.mask((command as MaskEntranceCommand).masked, now, command.actor)
	if command is RaidCommand:
		return raids.respond((command as RaidCommand).choice, now, command.actor)
	if command is FireWorkerCommand:
		return workers.fire(now, command.actor)
	if command is BuyCommand:
		var buy := command as BuyCommand
		return supplies.buy(buy.item, buy.quantity, now, command.actor)
	if command is BuyPlotCommand:
		return _buy_plot(now, command.actor)
	if command is DropOrderCommand:
		var dropped := orders.drop((command as DropOrderCommand).order_id, now, command.actor)
		if dropped.ok:
			suspicion.add(config.suspicion.per_drop)
		return dropped
	return CommandResult.failure(CommandResult.UNKNOWN_COMMAND)


func _buy_plot(now: float, actor: String) -> CommandResult:
	if grow.plots().size() >= progress.plot_cap():
		return CommandResult.failure(CommandResult.MAX_PLOTS)
	if not economy.spend(config.plot_price):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	var added := grow.add_plot()
	event_log.record(EventLog.PLOT_BOUGHT, now, PackedStringArray([actor, "plot:%d" % added.id]), {
		"plot_id": added.id,
		"cost": config.plot_price,
		"money": economy.money,
	})
	return CommandResult.success(added.id)


func _next_event_time() -> float:
	var next := minf(workers.next_event_time(), minf(supplies.next_event_time(), orders.next_event_time()))
	next = minf(next, minf(problems.next_event_time(), suspicion.next_event_time()))
	return minf(next, raids.next_event_time())


func _process_events(now: float) -> void:
	supplies.process(now)
	problems.process(now)
	orders.process(now)
	raids.process(now)
	suspicion.process(now)
	workers.process(now)


func _advance_time(real_seconds: float) -> CommandResult:
	var remaining := clock.real_to_game(real_seconds)
	while true:
		var now := clock.elapsed_game_seconds
		var event_time := _next_event_time()
		var until_event := event_time - now
		if until_event < remaining:
			if until_event > 0.0:
				grow.advance(now, until_event)
				clock.advance_to(event_time)
				remaining -= until_event
		else:
			grow.advance(now, remaining)
			clock.advance(remaining)
			remaining = 0.0
		_process_events(clock.elapsed_game_seconds)
		if remaining <= 0.0:
			break
	return CommandResult.success()


func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"clock": clock.to_dict(),
		"rng": rng.to_dict(),
		"economy": economy.to_dict(),
		"inventory": inventory.to_dict(),
		"plots": grow.to_array(),
		"workers": workers.to_dict(),
		"supplies": supplies.to_dict(),
		"orders": orders.to_dict(),
		"progress": progress.to_dict(),
		"problems": problems.to_dict(),
		"suspicion": suspicion.to_dict(),
		"raids": raids.to_dict(),
		"event_log": event_log.to_array(),
	}


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", true, true)


static func from_json(text: String, balance: BalanceConfig) -> SimState:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var data := json.data as Dictionary
	if not data.has_all(REQUIRED_SAVE_KEYS) or int(data["save_version"]) != SAVE_VERSION:
		return null
	var state := SimState.new(balance, 0)
	state._load_dict(data)
	if is_nan(state.clock.elapsed_game_seconds):
		return null
	return state


func _load_dict(data: Dictionary) -> void:
	clock.load_dict(data["clock"] as Dictionary)
	rng.load_dict(data["rng"] as Dictionary)
	economy.load_dict(data["economy"] as Dictionary)
	inventory.load_dict(data["inventory"] as Dictionary)
	grow.load_array(data["plots"] as Array)
	workers.load_dict(data["workers"] as Dictionary)
	supplies.load_dict(data["supplies"] as Dictionary)
	orders.load_dict(data["orders"] as Dictionary)
	progress.load_dict(data["progress"] as Dictionary)
	problems.load_dict(data["problems"] as Dictionary)
	suspicion.load_dict(data["suspicion"] as Dictionary)
	raids.load_dict(data["raids"] as Dictionary)
	event_log.load_array(data["event_log"] as Array)
