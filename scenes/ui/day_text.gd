class_name DayText
extends RefCounted

## Texts for Jack's day: trips and crates, Reggie's evening call, nights out, the summary of the day
## at bedtime and the morning briefing.

## Situations worth a line in the bedtime summary and the morning briefing. Losses are not here:
## they add up into one line of their own.
const SITUATIONS: Array[String] = [
	EventLog.RAID_RESOLVED, EventLog.INSPECTION_PASSED, EventLog.INSPECTION_FAILED, EventLog.WORKER_QUIT,
	EventLog.WORKER_UNPAID, EventLog.HELPER_UNPAID, EventLog.COURIER_QUIT, EventLog.RENT_MISSED, EventLog.RENT_EVICTED,
	EventLog.POWER_CUT, EventLog.MILESTONE_REACHED,
]
## Clues go on the wall in the container; the briefing only says a new one is there.
const CLUE_EVENTS: Array[String] = [EventLog.INTRIGUE_CLUE]
const MAX_NEWS: int = 4
const MAX_TODAY: int = 5


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
			return "Ночь, а Джек не дома. Когда машина поедет с поля через деревню, соседи увидят фары и запомнят. Каждый такой час — плюс к подозрению."
		EventLog.JACK_ARRIVED:
			return "Приехали: %s." % Travel.NAMES.get(String(event.data["to"]), "")
		EventLog.HELPER_SKILLS_REFUNDED:
			return "Грядки теперь на садовниках. %s вернул деньги за старые курсы: %s." % [UiText.REGGIE, UiText.money(int(event.data["refund"]))]
		EventLog.HOME_NIGHT:
			return "Ночь дома: %s." % ", ".join(home_night_gains(event))
	return RentTalk.announcement(event, sim)


static func evening_call(sim: SimState) -> String:
	var hour := floori(sim.config.day.evening_hour) if sim.day.enabled() else 20
	return "%s: %d:00, Джек. Поехали домой — Вивьен ждёт к ужину. Ферма до утра постоит, а машина с поля среди ночи — это фары через всю деревню." % [UiText.REGGIE, hour]


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
		if sim.rent.visit_promised():
			return "Поздно, Джек, но сначала — поместье: лорд ждёт аренду %s. Потом домой." % RentTalk.deadline(sim)
		return "Поздно, Джек. Пора домой: садитесь в лендровер — или «Домой» на баннере. Чем позже машина выедет с поля, тем больше соседей увидят её фары."
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
	lines.append_array(DayReport.lines(sim, from, to))
	return lines


static func news_between(sim: SimState, from: float, to: float, types: Array[String]) -> PackedStringArray:
	var lines := PackedStringArray()
	for event: SimEvent in sim.event_log.entries():
		if event.game_time < from or event.game_time > to or not types.has(event.type):
			continue
		var text := DayReport.situation(event, sim)
		if not text.is_empty() and not lines.has(text):
			lines.append(text)
	if lines.size() > MAX_NEWS:
		var more := lines.size() - MAX_NEWS
		lines = lines.slice(lines.size() - MAX_NEWS)
		lines.insert(0, "…и ещё %d %s раньше." % [more, plural(more, "событие", "события", "событий")])
	return lines


# --- the morning briefing

## What the night at home gave, for the morning briefing; empty after a night away.
static func home_night(sim: SimState, from: float, to: float) -> PackedStringArray:
	var lines := PackedStringArray()
	for event: SimEvent in sim.event_log.of_type(EventLog.HOME_NIGHT):
		if event.game_time >= from and event.game_time <= to:
			lines.append(UiText.capitalized(", ".join(home_night_gains(event))) + ".")
	return lines


static func home_night_gains(event: SimEvent) -> PackedStringArray:
	var gains := PackedStringArray()
	var relief := float(event.data.get("suspicion_relief", 0.0))
	if relief > 0.0:
		gains.append("подозрение −%d%% — машина всю ночь простояла у коттеджа, соседям нечего обсуждать" % roundi(relief))
	var bonus := int(event.data.get("bonus", 0))
	if bonus > 0:
		gains.append("Вивьен выиграла в бридж у жены викария %s — в кассу" % UiText.money(bonus))
	if gains.is_empty():
		gains.append("Джек выспался")
	return gains


static func briefing_title(sim: SimState) -> String:
	return "Утро, день %d · %s" % [sim.clock.day() + 1, UiText.clock(sim.clock).get_slice("· ", 1)]


static func night(sim: SimState, from: float, to: float) -> PackedStringArray:
	var news := DayReport.lines(sim, from, to)
	var totals := MoneyLedger.totals(sim, from, to)
	if totals != Vector2i.ZERO:
		news.insert(0, "Деньги за ночь: пришло %s, ушло %s." % [UiText.money(totals.x), UiText.money(totals.y)])
	if news.is_empty():
		news.append("Ночь прошла спокойно. Садовники своё отработали, гопников не было.")
	return news


static func today(sim: SimState) -> PackedStringArray:
	var lines := PackedStringArray()
	var now := sim.clock.elapsed_game_seconds
	if sim.raids.pending:
		lines.append("У контейнера гопники — разберитесь или ждите, пока %s их прогонит." % UiText.REGGIE)
	if sim.suspicion.inspection_pending():
		lines.append("Едет проверка — %s." % UiText.game_when(sim.suspicion.inspection_at, sim))
	if sim.rent.visit_promised():
		lines.append("Аренду %s обещали привезти лорду в поместье %s." % [UiText.money(sim.rent.owed()), RentTalk.deadline(sim)])
	elif sim.rent.amount() > 0 and sim.rent.due_in(now) <= SimClock.GAME_SECONDS_PER_DAY:
		lines.append("Аренда лорду — %s, срок %s." % [UiText.money(sim.rent.amount()), RentTalk.deadline(sim)])
	var story := sim.stories.pending()
	if story != null and story.place == StoryDef.MANOR:
		lines.append("Лорд Эшкомб просит заехать в поместье.")
	var calls := sim.orders.with_status(Order.Status.OFFERED).size()
	if calls > 0:
		lines.append("Ждут ответа звонков: %d — телефон, «Звонки»." % calls)
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		lines.append("Заказ #%d ждёт отправки, срок: %s." % [order.id, UiText.due_by(order.deadline, sim)])
	var waiting := sim.inventory.farm_crates().size()
	if waiting > 0:
		lines.append("На ферме %s — отвезти в тайник, пока не нашли." % crates(waiting))
	if lines.size() > MAX_TODAY:
		var more := lines.size() - MAX_TODAY
		lines = lines.slice(0, MAX_TODAY)
		lines.append("…и ещё %d %s — в телефоне." % [more, plural(more, "дело", "дела", "дел")])
	if lines.is_empty():
		lines.append("Срочного ничего. Грядки растут, звонков ждём.")
	return lines
