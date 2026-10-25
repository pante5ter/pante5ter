class_name MoneyLedger
extends RefCounted

## Every pound in and out with its reason, rebuilt from the event log, so the player can see where the money went.


class Entry:
	var game_time: float = 0.0
	## Positive came in, negative went out.
	var amount: int = 0
	var reason: String = ""

	static func make(at: float, value: int, why: String) -> Entry:
		var entry := Entry.new()
		entry.game_time = at
		entry.amount = value
		entry.reason = why
		return entry


static func entries(sim: SimState) -> Array[Entry]:
	var result: Array[Entry] = []
	for event: SimEvent in sim.event_log.entries():
		result.append_array(of_event(event, sim))
	return result


## Income and spending over [from, to) in game seconds: x came in, y went out (as a positive figure).
static func totals(sim: SimState, from: float, to: float) -> Vector2i:
	var income := 0
	var spent := 0
	for entry: Entry in entries(sim):
		if entry.game_time < from or entry.game_time >= to:
			continue
		if entry.amount >= 0:
			income += entry.amount
		else:
			spent -= entry.amount
	return Vector2i(income, spent)


static func of_event(event: SimEvent, sim: SimState) -> Array[Entry]:
	var at := event.game_time
	var data := event.data
	var found: Array[Entry] = []
	match event.type:
		EventLog.PRODUCT_SOLD:
			found.append(Entry.make(at, int(data.get("price", 0)), "Продажа, качество %d" % int(data.get("quality", 0))))
		EventLog.ORDER_PAID:
			var order_id := int(data.get("order_id", 0))
			found.append(Entry.make(at, int(data.get("reward", 0)), "Оплата заказа #%d" % order_id))
			var fee := int(data.get("fee", 0))
			if fee > 0:
				found.append(Entry.make(at, -fee, "Доля курьера (%s), заказ #%d" % [UiText.courier_name(String(data.get("courier_id", "")), sim), order_id]))
		EventLog.PLOT_BOUGHT:
			found.append(Entry.make(at, -int(data.get("cost", 0)), "Новая грядка"))
		EventLog.SUPPLY_ORDERED:
			found.append(Entry.make(at, -int(data.get("cost", 0)), "Покупка: %s × %d" % [UiText.item_name(String(data.get("item", "")), sim), int(data.get("quantity", 0))]))
		EventLog.WORKER_HIRED:
			found.append(Entry.make(at, -int(data.get("wage", 0)), "Найм: %s, первый день" % _person_name(String(data.get("worker_id", "")), sim)))
		EventLog.WORKER_PAID:
			found.append(Entry.make(at, -int(data.get("wage", 0)), "Зарплата: %s" % _person_name(String(data.get("worker_id", "")), sim)))
		EventLog.COURIER_HIRED:
			found.append(Entry.make(at, -int(data.get("fee", 0)), "Найм курьера: %s" % UiText.courier_name(String(data.get("courier_id", "")), sim)))
		EventLog.HELPER_TRAINING_STARTED:
			var skill := sim.config.find_skill(String(data.get("skill_id", "")))
			found.append(Entry.make(at, -int(data.get("cost", 0)), "Курсы «%s»" % (skill.display_name if skill != null else "?")))
		EventLog.HELPER_SKILLS_REFUNDED:
			found.append(Entry.make(at, int(data.get("refund", 0)), "Возврат за курсы Реджи"))
		EventLog.RENT_PAID:
			found.append(Entry.make(at, -int(data.get("amount", 0)), "Аренда лорду Эшкомбу"))
		EventLog.HOME_NIGHT:
			found.append(Entry.make(at, int(data.get("bonus", 0)), "Вивьен: выигрыш в бридж"))
		EventLog.RAID_RESOLVED:
			if data.has("paid"):
				found.append(Entry.make(at, -int(data.get("paid", 0)), "Откуп от налётчиков"))
		EventLog.INSPECTION_FAILED:
			found.append(Entry.make(at, -int(data.get("fine", 0)), "Штраф после проверки"))
		EventLog.STORY_RESOLVED:
			var story_money := _story_money(event, sim)
			if story_money != 0:
				found.append(Entry.make(at, story_money, _story_reason(event, sim)))
	return found.filter(func(entry: Entry) -> bool: return entry.amount != 0)


## A story logs the balance after the deal, not the amount, so the amount comes from the choice made.
## Spending is capped by what Jack had, as in Stories._move_money.
static func _story_money(event: SimEvent, sim: SimState) -> int:
	var choice := _story_choice(event, sim)
	if choice == null:
		return 0
	var amount := choice.money if bool(event.data.get("worked", true)) else choice.fail_money
	if amount < 0 and int(event.data.get("money", 0)) <= 0:
		return -mini(-amount, _money_before(event, sim))
	return amount


static func _story_reason(event: SimEvent, sim: SimState) -> String:
	var choice := _story_choice(event, sim)
	return "Разговор: «%s»" % choice.label if choice != null else "Разговор"


static func _story_choice(event: SimEvent, sim: SimState) -> StoryChoiceDef:
	var story := sim.stories.find(String(event.data.get("story_id", "")))
	var index := int(event.data.get("choice", -1))
	if story == null or index < 0 or index >= story.choices.size():
		return null
	return story.choices[index]


## The last balance any earlier event wrote down: enough to cap a deal Jack could not fully pay.
static func _money_before(event: SimEvent, sim: SimState) -> int:
	var log := sim.event_log.entries()
	for index: int in range(event.seq - 1, -1, -1):
		if log[index].data.has("money"):
			return int(log[index].data["money"])
	return sim.config.starting_money


static func _person_name(worker_id: String, sim: SimState) -> String:
	var person := sim.config.find_worker(worker_id)
	if person == null:
		person = sim.config.find_packer(worker_id)
	if person == null and sim.config.helper != null and sim.config.helper.id == worker_id:
		person = sim.config.helper
	return person.display_name if person != null else worker_id
