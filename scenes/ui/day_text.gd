class_name DayText
extends RefCounted

## Texts for Jack's day: trips and crates, Reggie's evening call, nights out, the summary of the day
## at bedtime and the morning briefing.

## Night news worth a line in the morning briefing.
const NIGHT_NEWS: Array[String] = [
	EventLog.RAID_STARTED, EventLog.RAID_RESOLVED, EventLog.INSPECTION_WARNED, EventLog.INSPECTION_PASSED,
	EventLog.INSPECTION_FAILED, EventLog.COURIER_STOLE, EventLog.DELIVERY_STOPPED, EventLog.HAUL_STOPPED,
	EventLog.WORKER_QUIT, EventLog.WORKER_STOLE, EventLog.PLOT_PROBLEM, EventLog.PLOT_DRIED_OUT,
	EventLog.PLOT_CROP_EATEN, EventLog.RENT_MISSED, EventLog.POWER_CUT, EventLog.ORDER_EXPIRED, EventLog.ORDER_PAID,
	EventLog.HELPER_SAVED, EventLog.ORDER_MISSED,
]
## The day's events that stay in the summary beside the numbers.
const DAY_NEWS: Array[String] = [
	EventLog.RAID_RESOLVED, EventLog.INSPECTION_PASSED, EventLog.INSPECTION_FAILED, EventLog.COURIER_STOLE,
	EventLog.DELIVERY_STOPPED, EventLog.HAUL_STOPPED, EventLog.WORKER_QUIT, EventLog.WORKER_STOLE,
	EventLog.RENT_MISSED, EventLog.JACK_OUT_LATE, EventLog.MILESTONE_REACHED,
]
const MAX_NEWS: int = 4


static func announcement(event: SimEvent, sim: SimState) -> String:
	match event.type:
		EventLog.HAUL_STARTED:
			if String(event.data["driver"]) == Helper.ACTOR:
				return "%s повёз в тайник %s." % [UiText.REGGIE, crates(int(event.data["units"]))]
			return "Джек сам везёт в тайник %s." % crates(int(event.data["units"]))
		EventLog.HAUL_ARRIVED:
			return "В тайнике %s. Дальше — стол фасовки." % crates(int(event.data["units"]))
		EventLog.HAUL_STOPPED:
			var who := UiText.REGGIE if String(event.data["driver"]) == Helper.ACTOR else "Джека"
			return "Лендровер с ящиками остановила полиция — %s отпустили, а %s потеряно. О ферме пошли разговоры." % [who, crates(int(event.data["units"]))]
		EventLog.EVENING_CALL:
			return evening_call(sim)
		EventLog.JACK_OUT_LATE:
			return "Ночь, а Джек не дома. Свет и машина на просёлке в такой час — деревня это замечает, подозрение растёт."
		EventLog.JACK_ARRIVED:
			return "Приехали: %s." % Travel.NAMES.get(String(event.data["to"]), "")
		EventLog.HELPER_SKILLS_REFUNDED:
			return "Грядки теперь на садовниках. %s вернул деньги за старые курсы: %s." % [UiText.REGGIE, UiText.money(int(event.data["refund"]))]
	return ""


static func evening_call(sim: SimState) -> String:
	var hour := floori(sim.config.day.evening_hour) if sim.day.enabled() else 20
	return "%s: %d:00, Джек. Поехали домой — Вивьен ждёт к ужину. А ферма до утра и без нас постоит." % [UiText.REGGIE, hour]


## Day-rhythm guidance; empty when the hour asks for nothing special.
static func objective(sim: SimState) -> String:
	var day := sim.day
	if not day.enabled() or day.travelling():
		return ""
	var now := sim.clock.elapsed_game_seconds
	if day.is_home():
		if day.can_sleep(now).is_empty():
			return "Вы дома, Джек. Вивьен уже зевает — ложитесь спать: кровать в углу. Утром расскажу, что было за ночь."
		return ""
	if is_evening(sim):
		return "Поздно, Джек. Пора домой: садитесь в лендровер — или «Домой» на баннере. Ночью нас видно издалека."
	return ""


static func is_evening(sim: SimState) -> bool:
	if not sim.day.enabled():
		return false
	var now := sim.clock.elapsed_game_seconds
	return sim.clock.hour_of_day() >= sim.day.definition().evening_hour or sim.day.is_night(now)


static func crates(count: int) -> String:
	return "%d %s" % [count, plural(count, "ящик", "ящика", "ящиков")]


static func plural(count: int, one: String, few: String, many: String) -> String:
	var tens := count % 100
	if tens >= 11 and tens <= 14:
		return many
	match count % 10:
		1:
			return one
		2, 3, 4:
			return few
	return many


# --- the summary of the day, shown when Jack goes to bed

static func summary_title(sim: SimState, from: float) -> String:
	return "День %d окончен" % (floori(from / SimClock.GAME_SECONDS_PER_DAY) + 1)


static func summary(sim: SimState, from: float, to: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var totals := MoneyLedger.totals(sim, from, to)
	if totals == Vector2i.ZERO:
		lines.append("Деньги: не пришло и не ушло ни пенни.")
	else:
		lines.append("Деньги: пришло %s, ушло %s, итог %s." % [UiText.money(totals.x), UiText.money(totals.y), PhoneFinance.signed(totals.x - totals.y)])
	lines.append("В кассе %s." % UiText.money(sim.economy.money))
	var counts := _counts(sim, from, to)
	var work := PackedStringArray()
	if counts.harvested > 0:
		work.append("собрано %d шт." % counts.harvested)
	if counts.hauled > 0:
		work.append("в тайник привезено %s" % crates(counts.hauled))
	if counts.packed > 0:
		work.append("расфасовано %d шт." % counts.packed)
	if counts.delivered > 0:
		work.append("доставлено заказов: %d" % counts.delivered)
	lines.append(("Урожай: " + ", ".join(work) + ".") if not work.is_empty() else "Урожая сегодня не было.")
	if counts.lost > 0:
		lines.append("Перехвачено по дороге: %s." % crates(counts.lost))
	var news := news_between(sim, from, to, DAY_NEWS)
	if not news.is_empty():
		lines.append("Что было:")
		for line: String in news:
			lines.append("• " + line)
	return lines


class Counts:
	var harvested: int = 0
	var hauled: int = 0
	var lost: int = 0
	var packed: int = 0
	var delivered: int = 0


static func _counts(sim: SimState, from: float, to: float) -> Counts:
	var counts := Counts.new()
	for event: SimEvent in sim.event_log.entries():
		if event.game_time < from or event.game_time > to:
			continue
		match event.type:
			EventLog.PLOT_HARVESTED:
				counts.harvested += int(event.data.get("quantity", 1))
			EventLog.HAUL_ARRIVED:
				counts.hauled += int(event.data["units"])
			EventLog.HAUL_STOPPED:
				counts.lost += int(event.data["units"])
			EventLog.PACKING_DONE:
				counts.packed += int(event.data["units"])
			EventLog.ORDER_PAID:
				counts.delivered += 1
	return counts


static func news_between(sim: SimState, from: float, to: float, types: Array[String]) -> PackedStringArray:
	var lines := PackedStringArray()
	for event: SimEvent in sim.event_log.entries():
		if event.game_time < from or event.game_time > to or not types.has(event.type):
			continue
		var text := UiText.announcement(event, sim)
		if not text.is_empty() and not lines.has(text):
			lines.append(text)
	if lines.size() > MAX_NEWS:
		var more := lines.size() - MAX_NEWS
		lines = lines.slice(lines.size() - MAX_NEWS)
		lines.insert(0, "…и ещё %d %s раньше." % [more, plural(more, "событие", "события", "событий")])
	return lines


# --- the morning briefing

static func briefing_title(sim: SimState) -> String:
	return "Утро, день %d · %s" % [sim.clock.day() + 1, UiText.clock(sim.clock).get_slice("· ", 1)]


static func night(sim: SimState, from: float, to: float) -> PackedStringArray:
	var news := news_between(sim, from, to, NIGHT_NEWS)
	if news.is_empty():
		news.append("Ночь прошла спокойно. Садовники своё отработали, гопников не было.")
	return news


static func today(sim: SimState) -> PackedStringArray:
	var lines := PackedStringArray()
	var now := sim.clock.elapsed_game_seconds
	if sim.raids.pending:
		lines.append("У контейнера гопники — разберитесь или ждите, пока %s их прогонит." % UiText.REGGIE)
	if sim.suspicion.inspection_pending():
		lines.append("Едет проверка — через %s." % UiText.real_duration(sim.suspicion.inspection_at - now, sim))
	var calls := sim.orders.with_status(Order.Status.OFFERED).size()
	if calls > 0:
		lines.append("Ждут ответа звонков: %d — телефон, «Звонки»." % calls)
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		lines.append("Заказ #%d ждёт отправки — сгорит через %s." % [order.id, UiText.real_duration(order.deadline - now, sim)])
	var story := sim.stories.pending()
	if story != null and story.place == "manor":
		lines.append("Лорд Эшкомб просит зайти в усадьбу.")
	if sim.rent.amount() > 0 and sim.rent.due_in(now) <= SimClock.GAME_SECONDS_PER_DAY:
		lines.append("Аренда лорду через %s — %s." % [UiText.real_duration(sim.rent.due_in(now), sim), UiText.money(sim.rent.amount())])
	var waiting := sim.inventory.farm_crates().size()
	if waiting > 0:
		lines.append("На ферме %s — отвезти в тайник." % crates(waiting))
	if sim.packing.unpacked_count() > 0:
		lines.append("В тайнике не расфасовано: %d шт." % sim.packing.unpacked_count())
	if not sim.supplies.parcel().is_empty():
		lines.append("У контейнера посылка — заберите.")
	if lines.is_empty():
		lines.append("Срочного ничего. Грядки растут, звонков ждём.")
	return lines
