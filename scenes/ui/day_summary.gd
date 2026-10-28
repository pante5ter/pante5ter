class_name DaySummary
extends RefCounted

## The numbers of a day for the summary panel, rebuilt from the event log for [from, to):
## money in and out, boxes sold and what was lost.

var from: float = 0.0
var to: float = 0.0
var earned: int = 0
var spent: int = 0
var sold: int = 0
var cash: int = 0
var losses: PackedStringArray = PackedStringArray()


static func build(sim: SimState, day_from: float, day_to: float) -> DaySummary:
	var summary := DaySummary.new()
	summary.from = day_from
	summary.to = day_to
	var totals := MoneyLedger.totals(sim, day_from, day_to)
	summary.earned = totals.x
	summary.spent = totals.y
	summary.sold = sold_units(sim, day_from, day_to)
	summary.cash = sim.economy.money
	summary.losses = DayReport.losses(sim, day_from, day_to).parts()
	return summary


func net() -> int:
	return earned - spent


func title() -> String:
	return "День %d окончен" % DayEndWatch.day_number(from)


## Boxes that brought money: sold to the buyer one by one, or delivered in an order.
static func sold_units(sim: SimState, day_from: float, day_to: float) -> int:
	var dispatched: Dictionary[int, int] = {}
	var count := 0
	for event: SimEvent in sim.event_log.entries():
		if event.type == EventLog.ORDER_DISPATCHED:
			dispatched[int(event.data.get("order_id", -1))] = (event.data.get("product_ids", []) as Array).size()
		if event.game_time < day_from or event.game_time >= day_to:
			continue
		if event.type == EventLog.PRODUCT_SOLD:
			count += 1
		elif event.type == EventLog.ORDER_PAID:
			count += int(dispatched.get(int(event.data.get("order_id", -1)), 0))
	return count


## Caption and value per figure, in the order the panel shows them.
func figures() -> Array[PackedStringArray]:
	return [
		PackedStringArray(["Заработано", UiText.money(earned)]),
		PackedStringArray(["Потрачено", UiText.money(spent)]),
		PackedStringArray(["Итог", PhoneFinance.signed(net())]),
		PackedStringArray(["Продано", "%d шт." % sold]),
		PackedStringArray(["Потери", "нет" if losses.is_empty() else str(losses.size())]),
	]


func lines() -> PackedStringArray:
	var found := PackedStringArray()
	if earned == 0 and spent == 0:
		found.append("Деньги: не пришло и не ушло ни пенни.")
	else:
		found.append("Деньги: пришло %s, ушло %s, итог %s." % [UiText.money(earned), UiText.money(spent), PhoneFinance.signed(net())])
	if not losses.is_empty():
		found.append("Потери: %s." % "; ".join(losses))
	found.append("В кассе %s." % UiText.money(cash))
	return found
