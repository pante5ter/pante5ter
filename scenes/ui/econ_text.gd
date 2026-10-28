class_name EconText
extends RefCounted

## News for the shop's deliveries, the bunker kit and Vivienne's gossip turned into business.


static func announcement(event: SimEvent, sim: SimState) -> String:
	match event.type:
		EventLog.SUPPLY_BOUGHT_IN_VILLAGE:
			return "Куплено в деревенской лавке: %s × %d за %s. Уже у Джека." % [UiText.item_name(String(event.data["item"]), sim), int(event.data["quantity"]), UiText.money(int(event.data["cost"]))]
		EventLog.UPGRADE_ORDERED:
			return "Заказано: «%s» за %s%s. Привезут с поставкой — %s." % [upgrade_name(String(event.data["upgrade_id"]), sim), UiText.money(int(event.data["cost"])), " (б/у)" if event.data.get("used", false) == true else "", delivery_when(float(event.data["arrives_at"]), sim)]
		EventLog.UPGRADE_INSTALLED:
			var upgrade := sim.upgrades.find(String(event.data["upgrade_id"]))
			if upgrade == null:
				return ""
			return "В бункере установлено: «%s». Каждый день — %s по счёту." % [upgrade.display_name, UiText.money(upgrade.daily_cost)]
		EventLog.UPGRADES_CUT:
			return "Счёт за оборудование (%s) оплатить нечем — всё отключили до следующего счёта." % UiText.money(int(event.data["amount"]))
		EventLog.RAID_SPOTTED:
			return "Камера заметила гостей у ворот заранее: на ответ есть ещё %d ч." % roundi(float(event.data["hours"]))
		EventLog.OPPORTUNITY_OPENED:
			return opportunity(event, sim)
	return ""


static func opportunity(event: SimEvent, sim: SimState) -> String:
	var note := sim.config.opportunities.note_for(int(event.data["gossip"])) if sim.config.opportunities != null else ""
	var heard := ""
	if not note.is_empty():
		heard = "Вивьен не зря рассказывала: %s. " % (note.left(1).to_lower() + note.substr(1))
	match String(event.data["kind"]):
		Opportunities.SALE:
			return "%sБ/у «%s» сегодня за %s вместо %s — в магазине до %s." % [heard, upgrade_name(String(event.data["upgrade_id"]), sim), UiText.money(int(event.data["price"])), UiText.money(int(event.data["full_price"])), PhoneNews.time_of_day(float(event.data["until"]))]
		Opportunities.LEAD:
			return "%sНаводка на будущее поле записана." % heard
		Opportunities.PARTY:
			return "%sЗвонят насчёт большого заказа к празднику: %d шт. за %s." % [heard, int(event.data["quantity"]), UiText.money(int(event.data["reward"]))]
	return ""


static func upgrade_name(upgrade_id: String, sim: SimState) -> String:
	var upgrade := sim.upgrades.find(upgrade_id)
	return upgrade.display_name if upgrade != null else upgrade_id


## «сегодня в 09:00» / «завтра в 09:00» / «через 2 дня в 09:00».
static func delivery_when(at: float, sim: SimState) -> String:
	var days := floori(at / SimClock.GAME_SECONDS_PER_DAY) - sim.clock.day()
	var hour := PhoneNews.time_of_day(at)
	match days:
		0:
			return "сегодня в %s" % hour
		1:
			return "завтра в %s" % hour
	return "через %d %s в %s" % [days, UiText.plural(days, "день", "дня", "дней"), hour]
