class_name Advice
extends RefCounted

## Reggie's answer to «Что делать?» once the guide is over: the single most useful thing right now,
## picked from the state alone. Trouble at the door first, then money owed, goods waiting, beds, people, growth.

const EVICTED: String = "evicted"
const RAID: String = "raid"
const INSPECTION: String = "inspection"
const RENT: String = "rent"
const CALL: String = "call"
const SEND: String = "send"
const PACK: String = "pack"
const HAUL: String = "haul"
const HARVEST: String = "harvest"
const WATER: String = "water"
const PROBLEM: String = "problem"
const HIRE: String = "hire"
const EXPAND: String = "expand"
const LIE_LOW: String = "lie_low"
const PLANT: String = "plant"
const WAIT_STOCK: String = "wait_stock"
const NONE: String = "none"

var kind: String = NONE
var plot_ids: Array[int] = []
var amount: int = 0
var order_id: int = -1


static func make(advice_kind: String, figure: int = 0) -> Advice:
	var advice := Advice.new()
	advice.kind = advice_kind
	advice.amount = figure
	return advice


static func next(sim: SimState) -> Advice:
	var def := sim.config.guide if sim.config.guide != null else GuideDef.new()
	var now := sim.clock.elapsed_game_seconds
	if sim.rent.evicted:
		return make(EVICTED)
	if sim.raids.pending:
		return make(RAID)
	if sim.suspicion.inspection_pending() and not sim.suspicion.quiet:
		return make(INSPECTION)
	if _rent_is_short(sim, def, now):
		return make(RENT, sim.rent.owed())
	var calls := sim.orders.with_status(Order.Status.OFFERED)
	if not calls.is_empty():
		return make(CALL, calls.size())
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		if sim.orders.can_fill(order):
			var send := make(SEND, order.quantity)
			send.order_id = order.id
			return send
	if sim.packing.unpacked_count() > 0 and not sim.packing.busy() and not sim.packer.hired:
		return make(PACK, sim.packing.unpacked_count())
	var crates := sim.inventory.farm_crates().size()
	if crates > 0 and not sim.stash.on_the_road():
		return make(HAUL, crates)
	var ripe := _plots(sim, func(plot: Plot) -> bool: return plot.stage == Plot.Stage.READY)
	if not ripe.is_empty():
		return _with_plots(HARVEST, ripe)
	var dry := _plots(sim, func(plot: Plot) -> bool: return plot.is_growing() and plot.water_seconds <= 0.0 and plot.problem.is_empty())
	if not dry.is_empty():
		return _with_plots(WATER, dry)
	var sick := _plots(sim, func(plot: Plot) -> bool: return not plot.problem.is_empty())
	if not sick.is_empty():
		return _with_plots(PROBLEM, sick)
	var crew := sim.workers
	if crew.gardeners().is_empty() and crew.capacity() > 0 and sim.economy.money >= _cheapest_wage(sim):
		return make(HIRE, _cheapest_wage(sim))
	var calm := sim.suspicion.level < def.high_suspicion
	if calm and sim.grow.plots().size() < sim.progress.plot_cap() and sim.economy.money >= sim.config.plot_price + def.spare_money:
		return make(EXPAND, sim.config.plot_price)
	if not calm and not sim.suspicion.quiet:
		return make(LIE_LOW, roundi(sim.suspicion.level))
	var empty := _plots(sim, func(plot: Plot) -> bool: return plot.stage == Plot.Stage.EMPTY)
	if not empty.is_empty() and crew.gardeners().is_empty():
		return _with_plots(PLANT, empty)
	var waiting := sim.orders.with_status(Order.Status.ACCEPTED)
	if not waiting.is_empty():
		var wait := make(WAIT_STOCK, waiting[0].quantity)
		wait.order_id = waiting[0].id
		return wait
	return make(NONE)


static func _rent_is_short(sim: SimState, def: GuideDef, now: float) -> bool:
	var rent := sim.rent
	if rent.owed() <= 0 or sim.economy.money >= rent.owed():
		return false
	return rent.visit_promised() or rent.due_in(now) <= def.rent_warning_hours * SimClock.GAME_SECONDS_PER_HOUR


static func _plots(sim: SimState, wanted: Callable) -> Array[int]:
	var found: Array[int] = []
	for plot: Plot in sim.grow.plots():
		if bool(wanted.call(plot)):
			found.append(plot.id)
	return found


static func _with_plots(advice_kind: String, ids: Array[int]) -> Advice:
	var advice := make(advice_kind, ids.size())
	advice.plot_ids = ids
	return advice


static func _cheapest_wage(sim: SimState) -> int:
	var cheapest := -1
	for person: WorkerDef in sim.config.candidates():
		if cheapest < 0 or person.daily_wage < cheapest:
			cheapest = person.daily_wage
	return maxi(cheapest, 0)
