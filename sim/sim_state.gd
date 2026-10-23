class_name SimState
extends RefCounted

const SAVE_VERSION: int = 1
const REQUIRED_SAVE_KEYS: Array[String] = ["save_version", "clock", "rng", "economy", "inventory", "plots", "event_log"]

var config: BalanceConfig
var clock: SimClock
var rng: SimRng
var event_log: EventLog
var inventory: Inventory
var grow: Grow
var economy: Economy


func _init(balance: BalanceConfig, seed_value: int) -> void:
	config = balance
	clock = SimClock.new(balance.real_seconds_per_game_day)
	rng = SimRng.new(seed_value)
	event_log = EventLog.new()
	inventory = Inventory.new()
	grow = Grow.new(balance.strain, balance.plot_count, rng, event_log, inventory)
	economy = Economy.new(balance.strain, balance.starting_money, event_log, inventory)


func apply(command: SimCommand) -> CommandResult:
	var now := clock.elapsed_game_seconds
	if command is AdvanceTimeCommand:
		return _advance_time((command as AdvanceTimeCommand).real_seconds)
	if command is PlantCommand:
		return grow.plant((command as PlantCommand).plot_id, now, command.actor)
	if command is WaterCommand:
		return grow.water((command as WaterCommand).plot_id, now, command.actor)
	if command is HarvestCommand:
		return grow.harvest((command as HarvestCommand).plot_id, now, command.actor)
	if command is SellCommand:
		return economy.sell((command as SellCommand).product_id, now, command.actor)
	return CommandResult.failure(CommandResult.UNKNOWN_COMMAND)


func _advance_time(real_seconds: float) -> CommandResult:
	var game_seconds := clock.real_to_game(real_seconds)
	grow.advance(clock.elapsed_game_seconds, game_seconds)
	clock.advance(game_seconds)
	return CommandResult.success()


func to_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"clock": clock.to_dict(),
		"rng": rng.to_dict(),
		"economy": economy.to_dict(),
		"inventory": inventory.to_dict(),
		"plots": grow.to_array(),
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
	return state


func _load_dict(data: Dictionary) -> void:
	clock.load_dict(data["clock"] as Dictionary)
	rng.load_dict(data["rng"] as Dictionary)
	economy.load_dict(data["economy"] as Dictionary)
	inventory.load_dict(data["inventory"] as Dictionary)
	grow.load_array(data["plots"] as Array)
	event_log.load_array(data["event_log"] as Array)
