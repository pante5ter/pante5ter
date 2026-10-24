class_name SimState
extends RefCounted

const SAVE_VERSION: int = 9
## v7 saves load too: they get a fresh helper and no packer.
const MIGRATABLE_VERSION: int = 7
## v8 saves load too: they skip the first-day script and the director starts counting at load.
const V8_VERSION: int = 8
const V7_SAVE_KEYS: Array[String] = ["save_version", "clock", "rng", "economy", "inventory", "plots", "workers", "supplies", "orders", "progress", "problems", "suspicion", "raids", "couriers", "packing", "rent", "event_log"]
const V8_SAVE_KEYS: Array[String] = ["helper", "packer"]
const V9_SAVE_KEYS: Array[String] = ["first_day", "director", "stories"]

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
var couriers: Couriers
var packing: Packing
var rent: Rent
var helper: Helper
var packer: Packer
var stories: Stories
var first_day: FirstDay
var director: Director


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
	orders = Orders.new(balance.orders, balance.strain, rng, inventory, event_log)
	couriers = Couriers.new(balance, orders, economy, suspicion, rng, event_log)
	packing = Packing.new(balance.orders, inventory, event_log)
	problems = Problems.new(balance.problems, grow, supplies, rng, event_log)
	raids = Raids.new(balance.raids, rng, inventory, economy, orders, workers, suspicion, event_log, empire_value)
	rent = Rent.new(balance.rent, economy, suspicion, event_log)
	packer = Packer.new(balance, packing, economy, suspicion, event_log)
	helper = Helper.new(balance, grow, supplies, packing, economy, suspicion, event_log)
	helper.farmhand = workers
	helper.packer = packer
	workers.helper = helper
	couriers.attach_helper(helper)
	raids.attach_helper(helper)
	stories = Stories.new(balance, economy, suspicion, rent, rng, event_log)
	first_day = FirstDay.new(balance, grow, inventory, orders, problems, stories, event_log)
	director = Director.new(balance, rng, orders, problems, suspicion, raids, couriers, stories, first_day, event_log)
	progress.update(empire_value(), clock.elapsed_game_seconds)


func apply(command: SimCommand) -> CommandResult:
	if rent.evicted:
		return CommandResult.failure(CommandResult.EVICTED)
	var result := _apply(command)
	first_day.update(clock.elapsed_game_seconds)
	progress.update(empire_value(), clock.elapsed_game_seconds)
	return result


func empire_value() -> int:
	var value := economy.money + grow.plots().size() * config.plot_price
	for product: Product in inventory.products():
		value += economy.price_of(product)
	for order: Order in orders.with_status(Order.Status.IN_TRANSIT):
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
		var hire := command as HireWorkerCommand
		if config.find_packer(hire.worker_id) != null:
			return packer.hire(hire.worker_id, now, command.actor)
		return workers.hire(now, command.actor, hire.worker_id)
	if command is TreatCommand:
		return problems.treat((command as TreatCommand).plot_id, now, command.actor)
	if command is LieLowCommand:
		return suspicion.lie_low((command as LieLowCommand).on, now, command.actor)
	if command is AnswerOrderCommand:
		var answer := command as AnswerOrderCommand
		return orders.answer(answer.order_id, answer.choice, now, command.actor)
	if command is DispatchCommand:
		var dispatch := command as DispatchCommand
		return couriers.dispatch(dispatch.order_id, dispatch.courier_id, now, command.actor)
	if command is HireCourierCommand:
		return couriers.hire((command as HireCourierCommand).courier_id, now, command.actor)
	if command is FireCourierCommand:
		return couriers.fire((command as FireCourierCommand).courier_id, now, command.actor)
	if command is PackCommand:
		return packing.start(now, command.actor)
	if command is PickUpParcelCommand:
		return supplies.pick_up(now, command.actor)
	if command is RaidCommand:
		return raids.respond((command as RaidCommand).choice, now, command.actor)
	if command is FireWorkerCommand:
		var fire := command as FireWorkerCommand
		if config.find_packer(fire.worker_id) != null:
			return packer.fire(now, command.actor)
		return workers.fire(now, command.actor)
	if command is LearnSkillCommand:
		return helper.learn((command as LearnSkillCommand).skill_id, now, command.actor)
	if command is RestockCommand:
		return supplies.restock(now, command.actor)
	if command is SetAutoReorderCommand:
		var rule := command as SetAutoReorderCommand
		return supplies.set_auto_reorder(rule.item, rule.keep, now, command.actor)
	if command is BuyCommand:
		var buy := command as BuyCommand
		return supplies.buy(buy.item, buy.quantity, now, command.actor)
	if command is BuyPlotCommand:
		return _buy_plot(now, command.actor)
	if command is ChooseCommand:
		var choose := command as ChooseCommand
		return stories.choose(choose.story_id, choose.choice, now, command.actor)
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
	next = minf(next, minf(couriers.next_event_time(), packing.next_event_time()))
	next = minf(next, rent.next_event_time())
	next = minf(next, minf(helper.next_event_time(), packer.next_event_time()))
	next = minf(next, minf(first_day.next_event_time(), director.next_event_time()))
	return minf(next, raids.next_event_time())


func _process_events(now: float) -> void:
	supplies.process(now)
	problems.process(now)
	orders.process(now)
	couriers.process(now)
	packing.process(now)
	raids.process(now)
	suspicion.process(now)
	workers.process(now)
	helper.process(now)
	packer.process(now)
	rent.process(now)
	# Last, so both see everything the others did at this instant.
	first_day.update(now)
	director.process(now)


func _grow_unless_quiet(now: float, game_seconds: float) -> void:
	if not suspicion.quiet:
		grow.advance(now, game_seconds)


func _advance_time(real_seconds: float) -> CommandResult:
	var remaining := clock.real_to_game(real_seconds)
	while true:
		var now := clock.elapsed_game_seconds
		var event_time := _next_event_time()
		var until_event := event_time - now
		if until_event < remaining:
			if until_event > 0.0:
				_grow_unless_quiet(now, until_event)
				clock.advance_to(event_time)
				remaining -= until_event
		else:
			_grow_unless_quiet(now, remaining)
			clock.advance(remaining)
			remaining = 0.0
		_process_events(clock.elapsed_game_seconds)
		if remaining <= 0.0 or rent.evicted:
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
		"couriers": couriers.to_dict(),
		"packing": packing.to_dict(),
		"rent": rent.to_dict(),
		"helper": helper.to_dict(),
		"packer": packer.to_dict(),
		"stories": stories.to_dict(),
		"first_day": first_day.to_dict(),
		"director": director.to_dict(),
		"event_log": event_log.to_array(),
	}


func to_json() -> String:
	return JSON.stringify(to_dict(), "\t", true, true)


static func from_json(text: String, balance: BalanceConfig) -> SimState:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return null
	var data := json.data as Dictionary
	if not data.has_all(V7_SAVE_KEYS):
		return null
	var version := int(data["save_version"])
	if version != SAVE_VERSION and version != V8_VERSION and version != MIGRATABLE_VERSION:
		return null
	if version >= V8_VERSION and not data.has_all(V8_SAVE_KEYS):
		return null
	if version == SAVE_VERSION and not data.has_all(V9_SAVE_KEYS):
		return null
	var state := SimState.new(balance, 0)
	state._load_dict(data)
	if version == MIGRATABLE_VERSION:
		state.helper.start_at(state.clock.elapsed_game_seconds)
	if version < SAVE_VERSION:
		state.first_day.skip()
		state.director.restart(state.clock.elapsed_game_seconds)
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
	couriers.load_dict(data["couriers"] as Dictionary)
	packing.load_dict(data["packing"] as Dictionary)
	rent.load_dict(data["rent"] as Dictionary)
	if data.has("helper"):
		helper.load_dict(data["helper"] as Dictionary)
	if data.has("packer"):
		packer.load_dict(data["packer"] as Dictionary)
	event_log.load_array(data["event_log"] as Array)
	if data.has("stories"):
		stories.load_dict(data["stories"] as Dictionary)
	if data.has("first_day"):
		first_day.load_dict(data["first_day"] as Dictionary)
	if data.has("director"):
		director.load_dict(data["director"] as Dictionary)
