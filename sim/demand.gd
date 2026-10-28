class_name Demand
extends RefCounted

## How big a supplier the clients take Jack for: what they paid him lately and the stock he keeps.
## 0 is a newcomer, 1 a big supplier; regular calls grow bigger, pickier and richer with it.
## Pickier only up to what he actually grows: his stock's average quality caps their asking.

var _def: OrdersDef
var _inventory: Inventory
var _event_log: EventLog


func _init(def: OrdersDef, inventory: Inventory, event_log: EventLog) -> void:
	_def = def
	_inventory = inventory
	_event_log = event_log


func level(now: float) -> float:
	var score := 0.0
	if _def.demand_full_takings > 0:
		score += _def.demand_takings_weight * minf(float(takings(now)) / float(_def.demand_full_takings), 1.0)
	if _def.demand_full_stock > 0:
		score += (1.0 - _def.demand_takings_weight) * minf(float(_inventory.count()) / float(_def.demand_full_stock), 1.0)
	return clampf(score, 0.0, 1.0)


## Paid for orders within the window before `now`.
func takings(now: float) -> int:
	var total := 0
	for event: SimEvent in _event_log.recent_of_type(EventLog.ORDER_PAID, now - _def.demand_window_hours * SimClock.GAME_SECONDS_PER_HOUR):
		total += int(event.data.get("reward", 0))
	return total


## Average quality of what Jack keeps; -1 with nothing in stock.
func stock_quality() -> int:
	var products := _inventory.products()
	if products.is_empty():
		return -1
	var total := 0
	for product: Product in products:
		total += product.quality
	return roundi(float(total) / float(products.size()))
