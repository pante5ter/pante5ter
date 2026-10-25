class_name Workers
extends RefCounted

## The gardeners' crew: up to config.max_gardeners people, each on a bed of his own.

const ACTOR: String = "worker"

enum Task { NONE, PLANT, WATER, HARVEST, PRUNE, FERTILIZE, TREAT, PACK }

const CARE_ORDER: Array[Task] = [Task.HARVEST, Task.WATER, Task.PLANT]

## Hire order; the first one is the crew's face in single-line texts.
var _crew: Array[Gardener] = []
var _def: WorkerDef
var _grow: Grow
var _economy: Economy
var _event_log: EventLog
var _config: BalanceConfig = null
var _rng: SimRng = null
var _inventory: Inventory = null
var _suspicion: Suspicion = null
## Set by SimState: the helper's plot is left to him.
var helper: Helper = null
## Set by SimState: nobody pockets a crop under the boss's nose or on his first day.
var day: DayCycle = null
var first_day: FirstDay = null

## Anyone on the crew.
var hired: bool:
	get:
		return not _crew.is_empty()

## The first gardener's current job, for one-line status texts.
var task: Task:
	get:
		return _crew[0].task if hired else Task.NONE

var task_plot_id: int:
	get:
		return _crew[0].task_plot_id if hired else -1


func _init(def: WorkerDef, grow: Grow, economy: Economy, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_economy = economy
	_event_log = event_log


func attach(config: BalanceConfig, rng: SimRng, inventory: Inventory, suspicion: Suspicion) -> void:
	_config = config
	_rng = rng
	_inventory = inventory
	_suspicion = suspicion


## The first gardener on the crew, or the default candidate when nobody is hired.
func definition() -> WorkerDef:
	return _crew[0].definition() if hired else _def


func gardeners() -> Array[Gardener]:
	return _crew.duplicate()


func find(worker_id: String) -> Gardener:
	for gardener: Gardener in _crew:
		if gardener.definition().id == worker_id:
			return gardener
	return null


func is_hired(worker_id: String) -> bool:
	return find(worker_id) != null


func capacity() -> int:
	return maxi(_config.max_gardeners if _config != null else 1, 1)


func unpaid_days_before_quit() -> int:
	return maxi(_config.unpaid_days_before_quit if _config != null else 1, 1)


func daily_wages() -> int:
	var total := 0
	for gardener: Gardener in _crew:
		total += gardener.definition().daily_wage
	return total


func hire(now: float, actor: String, worker_id: String = "") -> CommandResult:
	var chosen := _def
	if not worker_id.is_empty():
		chosen = _config.find_worker(worker_id) if _config != null else null
		if chosen == null:
			return CommandResult.failure(CommandResult.UNKNOWN_WORKER)
	if is_hired(chosen.id):
		return CommandResult.failure(CommandResult.WORKER_ALREADY_HIRED)
	if _crew.size() >= capacity():
		return CommandResult.failure(CommandResult.CREW_FULL)
	if not _economy.spend(chosen.daily_wage):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	var gardener := Gardener.new(chosen, self)
	gardener.start_at(now)
	_crew.append(gardener)
	_event_log.record(EventLog.WORKER_HIRED, now, PackedStringArray([actor, ACTOR]), {
		"worker_id": chosen.id,
		"role": WorkerDef.FARMHAND,
		"wage": chosen.daily_wage,
		"money": _economy.money,
	})
	return CommandResult.success()


## Empty fires the first gardener.
func fire(now: float, actor: String, worker_id: String = "") -> CommandResult:
	var gardener := _crew[0] if hired and worker_id.is_empty() else find(worker_id)
	if gardener == null:
		return CommandResult.failure(CommandResult.WORKER_NOT_HIRED)
	_crew.erase(gardener)
	_event_log.record(EventLog.WORKER_FIRED, now, PackedStringArray([actor, ACTOR]), {"worker_id": gardener.definition().id})
	return CommandResult.success()


func next_event_time() -> float:
	var next := INF
	for gardener: Gardener in _crew:
		next = minf(next, gardener.next_event_time())
	return next


func process(now: float) -> void:
	for gardener: Gardener in _crew.duplicate():
		if not gardener.process(now):
			_crew.erase(gardener)


## Beds someone else on the farm is working, so nobody doubles up.
func busy_plot_ids(except: Gardener = null) -> Array[int]:
	var taken: Array[int] = []
	for gardener: Gardener in _crew:
		if gardener != except and gardener.task_plot_id >= 0:
			taken.append(gardener.task_plot_id)
	if helper != null and helper.task_plot_id >= 0:
		taken.append(helper.task_plot_id)
	return taken


func farm_is_quiet() -> bool:
	return _suspicion != null and _suspicion.quiet


## Without a day cycle nobody knows where Jack is, so he counts as away.
func jack_on_farm() -> bool:
	return day != null and day.enabled() and day.place == DayCycle.FARM and not day.travelling()


func theft_possible(now: float) -> bool:
	if first_day != null and first_day.spares_thieves(now):
		return false
	return not jack_on_farm()


func talk(amount: float) -> void:
	if _suspicion != null:
		_suspicion.add(amount)


func grow() -> Grow:
	return _grow


func economy() -> Economy:
	return _economy


func event_log() -> EventLog:
	return _event_log


func rng() -> SimRng:
	return _rng


func inventory() -> Inventory:
	return _inventory


## The plot most in need of this care, skipping the ones someone else is on.
static func pick_plot(grow: Grow, kind: Task, water_below_hours: float, skip_plot_ids: Array[int] = [], can_do: Callable = Callable()) -> Plot:
	var best: Plot = null
	for candidate: Plot in grow.plots():
		if skip_plot_ids.has(candidate.id) or not needs(candidate, kind, water_below_hours):
			continue
		if can_do.is_valid() and not bool(can_do.call(kind, candidate)):
			continue
		if best == null or (kind == Task.WATER and candidate.water_seconds < best.water_seconds):
			best = candidate
	return best


static func needs(target: Plot, kind: Task, water_below_hours: float) -> bool:
	match kind:
		Task.HARVEST:
			return target.stage == Plot.Stage.READY
		Task.WATER:
			return target.is_growing() and target.problem.is_empty() and target.water_seconds < water_below_hours * SimClock.GAME_SECONDS_PER_HOUR
		Task.PLANT:
			return target.stage == Plot.Stage.EMPTY
		Task.PRUNE:
			return target.stage == Plot.Stage.BUSH and not target.pruned and target.problem.is_empty()
		Task.FERTILIZE:
			return target.is_growing() and not target.fertilized and target.problem.is_empty()
		Task.TREAT:
			return not target.problem.is_empty()
	return false


static func task_name(value: Task) -> String:
	return String(Task.keys()[value]).to_lower()


func to_dict() -> Dictionary:
	var crew: Array[Dictionary] = []
	for gardener: Gardener in _crew:
		crew.append(gardener.to_dict())
	return {"gardeners": crew}


func load_dict(data: Dictionary) -> void:
	_crew.clear()
	if not data.has("gardeners"):
		_load_single(data)
		return
	for item: Variant in data["gardeners"] as Array:
		_load_gardener(item as Dictionary)


## v11 and older: one farmhand.
func _load_single(data: Dictionary) -> void:
	if data["hired"] == true:
		_load_gardener(data)


func _load_gardener(data: Dictionary) -> void:
	var def := _config.find_worker(String(data["worker_id"])) if _config != null else null
	if def == null:
		def = _def
	var gardener := Gardener.new(def, self)
	gardener.load_dict(data)
	_crew.append(gardener)
