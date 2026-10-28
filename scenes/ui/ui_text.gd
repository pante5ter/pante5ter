class_name UiText
extends RefCounted

const LORD: String = "Лорд Эшкомб"
const REGGIE: String = "Реджи"
const VIVIENNE: String = "Вивьен"
const JACK: String = "Джек"
## Reggie starts nagging about rent this many game hours before it is due.
const RENT_WARNING_HOURS: float = 12.0
## Deadlines further off than this read as game clock time; nearer ones as a real countdown.
const CLOCK_DEADLINE_HOURS: float = 2.0

const STAGE_NAMES: Dictionary[Plot.Stage, String] = {
	Plot.Stage.EMPTY: "пусто",
	Plot.Stage.SEED: "семя",
	Plot.Stage.SPROUT: "росток",
	Plot.Stage.BUSH: "куст",
	Plot.Stage.READY: "готово к сбору",
}

const TASK_VERBS: Dictionary[Workers.Task, String] = {
	Workers.Task.PLANT: "сажает",
	Workers.Task.WATER: "поливает",
	Workers.Task.HARVEST: "собирает урожай",
	Workers.Task.PRUNE: "обрезает куст",
	Workers.Task.FERTILIZE: "удобряет",
	Workers.Task.TREAT: "лечит грядку",
	Workers.Task.PACK: "фасует урожай",
}

const ERRORS: Dictionary[String, String] = {
	CommandResult.INVALID_PLOT: "Такой грядки нет.",
	CommandResult.PLOT_OCCUPIED: "Грядка уже занята.",
	CommandResult.PLOT_NOT_GROWING: "Здесь нечего поливать.",
	CommandResult.PLOT_NOT_READY: "Ещё не созрело.",
	CommandResult.UNKNOWN_PRODUCT: "Такого товара нет.",
	CommandResult.UNKNOWN_COMMAND: "Неизвестное действие.",
	CommandResult.WORKER_ALREADY_HIRED: "Работник уже нанят.",
	CommandResult.NOT_ENOUGH_MONEY: "Не хватает денег.",
	CommandResult.WORKER_NOT_HIRED: "Работника нет.",
	CommandResult.UNKNOWN_STRAIN: "Такого сорта нет.",
	CommandResult.NO_SEEDS: "Нет семян этого сорта — закажи в телефоне.",
	CommandResult.NO_FERTILIZER: "Нет удобрений — закажи в телефоне.",
	CommandResult.ALREADY_DONE: "Уже сделано.",
	CommandResult.PLOT_NOT_BUSH: "Обрезать можно только куст.",
	CommandResult.UNKNOWN_ITEM: "Такого товара в магазине нет.",
	CommandResult.INVALID_QUANTITY: "Неверное количество.",
	CommandResult.MAX_PLOTS: "Больше грядок не поместится.",
	CommandResult.UNKNOWN_ORDER: "Такого заказа нет.",
	CommandResult.ORDER_NOT_OPEN: "С этим заказом уже всё решено.",
	CommandResult.NOT_ENOUGH_PRODUCT: "Не хватает товара нужного качества.",
	CommandResult.STRAIN_LOCKED: "Этот сорт пока недоступен — вырасти империю.",
	CommandResult.NO_SUPPLY: "Нечем лечить — закажи в телефоне.",
	CommandResult.NO_PROBLEM: "С грядкой всё в порядке.",
	CommandResult.NO_RAID: "Никого нет.",
	CommandResult.UNKNOWN_CHOICE: "Так нельзя.",
	CommandResult.UNKNOWN_WORKER: "Такого работника нет.",
	CommandResult.TOO_MANY_COURIERS: "Больше курьеров не нужно — уволь кого-нибудь.",
	CommandResult.COURIER_BUSY: "Курьер ещё в дороге.",
	CommandResult.CROP_EATEN: "Собирать нечего: вредители съели весь урожай. Грядка свободна.",
	CommandResult.COURIER_BANNED: "С этим человеком мы больше не работаем. Второй раз — это уже не доверие, а глупость.",
	CommandResult.LYING_LOW: "Ферма затихла — курьеры сидят дома.",
	CommandResult.NOTHING_TO_PACK: "Фасовать нечего — сначала собери урожай и привези ящики сюда.",
	CommandResult.CRATES_ON_FARM: "Ящики ещё на ферме — сначала отвезите их в тайник.",
	CommandResult.NOTHING_TO_HAUL: "Везти нечего — ящиков на ферме нет.",
	CommandResult.HAUL_UNDER_WAY: "Одна машина с ящиками уже в пути.",
	CommandResult.UNKNOWN_PLACE: "Туда не доехать.",
	CommandResult.ON_THE_ROAD: "Джек уже в дороге.",
	CommandResult.NOT_AT_HOME: "Спать — только дома.",
	CommandResult.NOT_AT_FARM: "Ящики на ферме, а Джек — нет.",
	CommandResult.TOO_EARLY_TO_SLEEP: "Рано спать — день ещё не кончился.",
	CommandResult.CREW_FULL: "Садовников и так полный комплект — сначала кого-нибудь уволь.",
	CommandResult.NO_PARCEL: "Посылок нет.",
	CommandResult.EVICTED: "Лорд Эшкомб расторг аренду. Поле больше не ваше, мистер Кэллоуэй.",
	CommandResult.UNKNOWN_SKILL: "Такому не учат.",
	CommandResult.HELPER_AWAY: "Помощника сейчас нет на ферме — он в дороге или на курсах.",
	CommandResult.NOTHING_TO_RESTOCK: "Запас и так полный.",
	CommandResult.NO_STORY: "Этот разговор уже закончен.",
	CommandResult.NO_INSPECTION: "Проверки не ждём — готовиться не к чему.",
}


static func money(amount: int) -> String:
	return "£%d" % amount


static func clock(sim_clock: SimClock) -> String:
	var hour := sim_clock.hour_of_day()
	var whole_hour := floori(hour)
	var minute := floori((hour - float(whole_hour)) * 60.0)
	return "День %d · %02d:%02d" % [sim_clock.day() + 1, whole_hour, minute]


static func real_duration(game_seconds: float, sim: SimState) -> String:
	var real_seconds := maxi(ceili(maxf(game_seconds, 0.0) * sim.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY), 0)
	var minutes := floori(real_seconds / 60.0)
	var seconds := real_seconds % 60
	if minutes == 0:
		return "%d с" % seconds
	if seconds == 0:
		return "%d мин" % minutes
	return "%d мин %d с" % [minutes, seconds]


## A game moment as the HUD clock shows it: «сегодня в 18:00», «завтра в 10:00», «в 00:00, день 3».
## With until: «до 18:00 сегодня», «до 10:00 завтра», «до 00:00, день 3». Midnight always names the day:
## «завтра в 00:00» reads as the end of tomorrow.
static func game_when(at: float, sim: SimState, until: bool = false) -> String:
	if not is_finite(at):
		return "без срока"
	var minutes_total := roundi(at / 60.0)
	var minutes_per_day := roundi(SimClock.GAME_SECONDS_PER_DAY / 60.0)
	var day := floori(float(minutes_total) / float(minutes_per_day))
	var minute_of_day := minutes_total - day * minutes_per_day
	var hhmm := "%02d:%02d" % [floori(minute_of_day / 60.0), minute_of_day % 60]
	var days_ahead := day - sim.clock.day()
	if minute_of_day == 0 or days_ahead < 0 or days_ahead > 1:
		return "%s %s, день %d" % ["до" if until else "в", hhmm, day + 1]
	var which := "сегодня" if days_ahead == 0 else "завтра"
	return ("до %s %s" % [hhmm, which]) if until else ("%s в %s" % [which, hhmm])


## A deadline Jack has to meet: far ones as clock time, near ones as a real countdown.
## «до 18:00 сегодня» or «через 45 с».
static func due_by(at: float, sim: SimState) -> String:
	var left := at - sim.clock.elapsed_game_seconds
	if left > CLOCK_DEADLINE_HOURS * SimClock.GAME_SECONDS_PER_HOUR:
		return game_when(at, sim, true)
	return "через " + real_duration(left, sim)


const PROBLEM_NAMES: Dictionary[String, String] = {
	Problems.PESTS: "вредители",
	Problems.MOLD: "плесень",
	Problems.LAMP: "перегорела лампа",
}

const PROBLEM_CURES: Dictionary[String, String] = {
	Problems.PESTS: "Обработать от вредителей",
	Problems.MOLD: "Убрать плесень",
	Problems.LAMP: "Заменить лампу",
}


static func problem(name: String) -> String:
	return PROBLEM_NAMES.get(name, name)


static func cure(name: String) -> String:
	return PROBLEM_CURES.get(name, "Вылечить")


static func empire(sim: SimState) -> String:
	var value := sim.empire_value()
	var next := sim.progress.next_milestone()
	if next == null:
		return "Империя: %s · все цели взяты" % money(value)
	return "Империя: %s → %s «%s»" % [money(value), money(next.value), next.title]


static func suspicion(sim: SimState) -> String:
	var text := "Подозрение: %d%%" % roundi(sim.suspicion.level)
	if sim.suspicion.inspection_pending():
		text += " · ПРОВЕРКА %s" % game_when(sim.suspicion.inspection_at, sim)
	if sim.suspicion.quiet:
		text += " · ферма затихла"
	return text


## The sensor's readings per bunker room, or what Jack needs to see them.
static func climate_report(sim: SimState) -> String:
	if not sim.climate.exists():
		return ""
	var def := sim.climate.definition()
	if not sim.climate.sensor_installed:
		return "Влажность и температуру в бункере не видно — нужен датчик (%s). Без него плесень замечают, когда уже поздно." % money(def.sensor_price)
	var lines := PackedStringArray()
	for room: RoomDef in def.rooms:
		var line := "%s: %d°C, влажность %d%%" % [room.display_name, roundi(sim.climate.temperature(room)), roundi(sim.climate.humidity(room))]
		if room.has_beds:
			line += " — риск плесени" if sim.climate.mold_factor() > 0.0 else " — плесени не грозит"
		lines.append(line)
	var air := sim.climate.running()
	var cost := "бесплатно" if air.power_per_hour <= 0 else "%s/ч" % money(air.power_per_hour)
	lines.append("Вентиляция: %s (%s)%s" % [air.display_name, cost, " — ферма затихла" if sim.suspicion.quiet else ""])
	return "\n".join(lines)


## Russian noun form for a count: 1 коробка, 2 коробки, 5 коробок.
static func plural(count: int, one: String, few: String, many: String) -> String:
	var tens := absi(count) % 100
	var units := tens % 10
	if tens >= 11 and tens <= 14:
		return many
	if units == 1:
		return one
	if units >= 2 and units <= 4:
		return few
	return many


static func stock(sim: SimState) -> String:
	var packed := 0
	for product: Product in sim.inventory.products():
		if product.packed:
			packed += 1
	var loose := sim.packing.unpacked_count()
	var text := "Товар: %d %s на полке" % [packed, plural(packed, "коробка", "коробки", "коробок")]
	if loose > 0:
		text += ", ещё не расфасовано: %d" % loose
	var crates := sim.inventory.farm_crates().size()
	if crates > 0:
		text += "
На ферме %s урожая" % DayText.crates(crates)
	if sim.stash.on_the_road():
		text += "
В пути в тайник: %s" % DayText.crates(sim.stash.transit.size())
	if sim.helper.exists() and not sim.helper.present():
		text += "\n" + PeopleText.helper_status(sim)
	return text


static func courier_name(courier_id: String, sim: SimState) -> String:
	if courier_id == Couriers.JACK:
		return JACK
	if courier_id == Helper.ACTOR and sim.helper.exists():
		return sim.helper.definition().display_name
	var courier := sim.config.find_courier(courier_id)
	return courier.display_name if courier != null else courier_id


static func item_name(item: String, sim: SimState) -> String:
	if item == Supplies.FERTILIZER:
		return "удобрение"
	if item == Supplies.PESTICIDE:
		return "средство от вредителей"
	if item == Supplies.LAMP:
		return "запасная лампа"
	var strain := sim.config.find_strain(item.trim_prefix(Supplies.SEED_PREFIX))
	return "семена «%s»" % strain.display_name if strain != null else item


## " (опт)" / " (розница)" after the word naming a regular call; empty for scripted and urgent ones.
static func order_kind(kind: String) -> String:
	match kind:
		Order.WHOLESALE:
			return " (опт)"
		Order.RETAIL:
			return " (розница)"
	return ""


## " сорта «Классика»" after the unit count of an order that names a strain; empty when any will do.
static func order_strain(strain_id: String, sim: SimState) -> String:
	var strain := sim.config.find_strain(strain_id) if not strain_id.is_empty() else null
	return " сорта «%s»" % strain.display_name if strain != null else ""


static func stage(value: Plot.Stage) -> String:
	return STAGE_NAMES.get(value, "?")


static func capitalized(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


static func plot_number(plot_id: int) -> int:
	return plot_id + 1


static func gardener_status(gardener: Gardener) -> String:
	var name := gardener.definition().display_name
	if gardener.task == Workers.Task.NONE:
		return "%s: ждёт работы" % name
	return "%s: %s, грядка %d" % [name, TASK_VERBS.get(gardener.task, "работает"), plot_number(gardener.task_plot_id)]


static func where_is_jack(sim: SimState) -> String:
	if sim.day.travelling():
		return "он в дороге (%s)" % Travel.TITLES.get(sim.day.trip_to, "")
	return "он сейчас: %s" % Travel.NAMES.get(sim.day.place, sim.day.place)


static func worker_status(workers: Workers) -> String:
	var name := workers.definition().display_name
	if not workers.hired:
		return "Работника нет"
	if workers.task == Workers.Task.NONE:
		return "%s: ждёт работы" % name
	return "%s: %s, грядка %d" % [name, TASK_VERBS.get(workers.task, "работает"), plot_number(workers.task_plot_id)]


static func objective(sim: SimState, underground: bool = false) -> String:
	if sim.rent.evicted:
		return "Лорд Эшкомб расторг аренду, ферма потеряна. Загрузите сохранение (F9) или начните заново."
	if sim.raids.pending:
		if underground:
			return "У контейнера гости, и не с пирогами — гопники. Поднимитесь наверх и разберитесь."
		return "У контейнера гости, и не с пирогами — гопники. Подойдите и разберитесь."
	if sim.suspicion.inspection_pending() and not sim.suspicion.quiet:
		return "Едет проверка. Изобразим скуку: на компьютере выключите свет, придержите курьеров."
	if _rent_is_short(sim):
		return "Лорду пора платить: аренда %s %s, а в кассе %s. Продайте товар через компьютер, иначе лорд обидится." % [money(sim.rent.amount()), game_when(sim.rent.next_due_at, sim, true), money(sim.economy.money)]
	var day := DayText.objective(sim)
	if not day.is_empty():
		return day
	if not sim.supplies.parcel().is_empty():
		return "У контейнера посылка. Сама она вниз не спустится — заберите её."
	var summons := StoryText.summons(sim, underground)
	if not summons.is_empty():
		return summons
	var lesson := StoryText.lesson(sim, underground)
	if not lesson.is_empty():
		return lesson
	var any_planted := false
	var any_ready := false
	var any_dry := false
	for plot: Plot in sim.grow.plots():
		any_planted = any_planted or plot.stage != Plot.Stage.EMPTY
		any_ready = any_ready or plot.stage == Plot.Stage.READY
		any_dry = any_dry or (plot.is_growing() and plot.water_seconds <= 0.0)
	for plot: Plot in sim.grow.plots():
		if not plot.problem.is_empty():
			var cure := Problems.cure_item(plot.problem)
			if not cure.is_empty() and sim.supplies.count(cure) <= 0:
				return "Грядка %d: %s. На складе нет: %s — закажите в телефоне (Tab, «Магазин»), заберите посылку и займитесь грядкой." % [plot_number(plot.id), problem(plot.problem), item_name(cure, sim)]
			return "Грядка %d: %s. Само не пройдёт — вылечите её на плантации, пока урожай цел." % [plot_number(plot.id), problem(plot.problem)]
	if not sim.orders.with_status(Order.Status.OFFERED).is_empty():
		return "Звонит клиент. Ответьте по телефону (Tab, «Звонки») — дважды они не звонят."
	if any_ready:
		return "Созрело, мистер Кэллоуэй. Соберите урожай на плантации."
	if sim.inventory.count() > 0:
		return _selling_objective(sim)
	if any_dry:
		return "Грядки сами себя не польют, мистер Кэллоуэй. Полейте сухие на плантации."
	var hunt := StoryText.rat_hunt(sim)
	if not hunt.is_empty():
		return hunt
	var idle := StoryText.idle_line(sim)
	if not idle.is_empty():
		return idle
	if not any_planted:
		if underground:
			return "Погреб пока пустой. Посадите семена на грядках."
		return "Погреб пока пустой. Спуститесь через контейнер на плантацию и посадите семена."
	if not sim.workers.hired and sim.economy.money >= sim.workers.definition().daily_wage:
		return "Двух рук на ферму мало. Наймите садовника: телефон (Tab) → «Люди» или компьютер, вкладка «Люди». Грядки он возьмёт на себя."
	return "Терпение. А пока закажите семена и удобрения в телефоне (Tab), обрежьте кусты."


static func _selling_objective(sim: SimState) -> String:
	if not sim.inventory.farm_crates().is_empty() and not sim.stash.on_the_road():
		return "Урожай в ящиках, а на ферме его не держат. Кликните по ящикам в бункере — отвезу в тайник. Или везите сами на лендровере."
	if sim.packing.unpacked_count() > 0 and not sim.packing.busy():
		return "Россыпью приличные люди не продают. Расфасуйте товар на столе в тайнике."
	var accepted := sim.orders.with_status(Order.Status.ACCEPTED)
	for order: Order in accepted:
		if sim.orders.can_fill(order):
			return "Заказ готов. На компьютере отправьте %s или курьера." % _driver_name(sim)
	if accepted.is_empty():
		return "Товар на полке. Теперь ждём звонков — клиенты звонят на телефон."
	return "Клиент хочет лучше, чем у нас есть. Удобряйте и обрезайте кусты на плантации."


static func _driver_name(sim: SimState) -> String:
	return sim.helper.definition().display_name if sim.helper.exists() else "курьера"


static func person(event: SimEvent, sim: SimState) -> WorkerDef:
	var worker_id := String(event.data.get("worker_id", ""))
	if sim.helper.exists() and worker_id == sim.helper.definition().id:
		return sim.helper.definition()
	var packer := sim.config.find_packer(worker_id)
	if packer != null:
		return packer
	var farmhand := sim.config.find_worker(worker_id)
	return farmhand if farmhand != null else sim.workers.definition()


static func announcement(event: SimEvent, sim: SimState) -> String:
	var worker := person(event, sim)
	match event.type:
		EventLog.WORKER_QUIT:
			return "%s %s: платить было нечем, а бесплатно работать — не по правилам. Принципиальн%s." % [worker.display_name, PeopleText.left_word(worker), "ый" if worker.male else "ая"]
		EventLog.WORKER_UNPAID:
			var days_left := int(event.data.get("days_left", 1))
			return "%s остался без зарплаты, долг %s. Работает, но ворчит: ещё %d %s без денег — и уйдёт." % [worker.display_name, money(int(event.data["debt"])), days_left, "день" if days_left == 1 else "дня"]
		EventLog.WORKER_PAID:
			return "Зарплата %s: %s." % [worker.display_name, money(int(event.data["wage"]))]
		EventLog.HELPER_UNPAID:
			return "%s остался без зарплаты. Промолчал, но запомнил: долг %s." % [worker.display_name, money(int(event.data["debt"]))]
		EventLog.HELPER_TRAINING_STARTED:
			var course := sim.config.find_skill(String(event.data["skill_id"]))
			return "%s уехал на курсы «%s». Ферма пока без него." % [_driver_name(sim), course.display_name if course != null else "?"]
		EventLog.HELPER_SKILL_LEARNED:
			var learned := sim.config.find_skill(String(event.data["skill_id"]))
			return "%s вернулся с курсов: «%s» теперь на нём." % [_driver_name(sim), learned.display_name if learned != null else "?"]
		EventLog.HELPER_SAVED:
			if String(event.data["kind"]) == Helper.SAVED_LIGHTS:
				return "%s сам выключил свет и вентиляцию — проверка вот-вот. Включит, когда уедут." % _driver_name(sim)
			return "%s вышел к гопникам сам. Разговор был короткий, гопники ушли." % _driver_name(sim)
		EventLog.HELPER_NEEDS_LAMP:
			return "%s готов поменять перегоревшую лампу, но запасной нет, а на новую (%s) в кассе не хватает. Нужна запасная лампа — телефон → «Магазин»." % [_driver_name(sim), money(int(event.data["price"]))]
		EventLog.SUPPLY_ORDERED:
			if event.actors.has(Helper.ACTOR) and String(event.data["item"]) == Supplies.LAMP:
				return "%s сам заказал запасную лампу за %s — привезут к контейнеру, и он её вкрутит." % [_driver_name(sim), money(int(event.data["cost"]))]
		EventLog.PARCEL_PICKED_UP:
			if event.actors.has(Helper.ACTOR):
				return "%s занёс посылку от двери контейнера на склад — там была запасная лампа." % _driver_name(sim)
		EventLog.PLOT_TREATED:
			if event.actors.has(Helper.ACTOR):
				return "%s вылечил грядку %d: %s — больше не проблема." % [_driver_name(sim), plot_number(int(event.data["plot_id"])), problem(String(event.data["problem"]))]
		EventLog.PLOT_DRIED_OUT:
			return "Грядка %d пересохла — рост остановился." % plot_number(int(event.data["plot_id"]))
		EventLog.ORDER_RECEIVED:
			if event.data.get("urgent", false) == true:
				return StoryText.urgent_call(event, sim)
			return "Звонит клиент%s: нужно %d шт.%s, качество %d+, %s. Ответьте по телефону." % [order_kind(String(event.data.get("kind", ""))), int(event.data["quantity"]), order_strain(String(event.data.get("strain_id", "")), sim), int(event.data["min_quality"]), money(int(event.data["reward"]))]
		EventLog.ORDER_MISSED:
			return "Клиент не дождался ответа и повесил трубку. Второй раз он вряд ли позвонит."
		EventLog.ORDER_HAGGLED:
			return "Клиент поворчал, но согласился на %s." % money(int(event.data["reward"]))
		EventLog.ORDER_WALKED_AWAY:
			return "Торг клиенту не понравился. Ушёл к другим — с гордостью и без товара."
		EventLog.ORDER_PAID:
			var fee := int(event.data["fee"])
			return "Заказ #%d доставлен: +%s%s." % [int(event.data["order_id"]), money(int(event.data["reward"]) - fee), (" (курьеру %s)" % money(fee)) if fee > 0 else ""]
		EventLog.ORDER_EXPIRED:
			return "Заказ #%d сгорел — не успели." % int(event.data["order_id"])
		EventLog.DELIVERY_STOPPED:
			return "%s остановили по дороге. Товар потерян, о ферме пошли разговоры. Неприятно." % courier_name(String(event.data["courier_id"]), sim)
		EventLog.COURIER_STOLE:
			return "Курьер %s исчез вместе с товаром. Открытки, полагаю, не будет — и работы у нас тоже." % courier_name(String(event.data["courier_id"]), sim)
		EventLog.COURIER_FIRED:
			if String(event.data.get("reason", "")) == Couriers.REASON_RAT:
				return "%s больше не работает на нас. Крысам ключи от фургона не дают." % courier_name(String(event.data["courier_id"]), sim)
		EventLog.COURIER_QUIT:
			return "%s обиделся на обвинение и ушёл. Курьером у нас он больше не работает." % courier_name(String(event.data["courier_id"]), sim)
		EventLog.PACKING_DONE:
			return "Расфасовано: %d шт. — на полке в тайнике." % int(event.data["units"])
		EventLog.SUPPLY_DELIVERED:
			return "Посылка у контейнера: %s × %d — заберите." % [item_name(String(event.data["item"]), sim), int(event.data["quantity"])]
		EventLog.MILESTONE_REACHED:
			var reached := sim.config.milestones[int(event.data["index"])]
			return "Новый уровень — «%s». Неплохо, мистер Кэллоуэй. %s" % [reached.title, reached.description]
		EventLog.PLOT_PROBLEM:
			if String(event.data["problem"]) == Problems.MOLD and sim.climate.exists():
				return "Грядка %d: плесень. В бункере сыро — уберите плесень (кликните по грядке), иначе вернётся. %s" % [plot_number(int(event.data["plot_id"])), ClimateControls.what_to_do(sim)]
			if String(event.data["problem"]) == Problems.PESTS:
				return "Грядка %d: вредители. Пока их не вытравить, они едят будущий урожай." % plot_number(int(event.data["plot_id"]))
			return "Грядка %d: %s. Лучше заняться сейчас, чем объяснять потом." % [plot_number(int(event.data["plot_id"])), problem(String(event.data["problem"]))]
		EventLog.SENSOR_INSTALLED:
			return "Датчик температуры и влажности стоит в бункере. Показания — %s." % ClimateControls.FARM_TAB
		EventLog.POWER_BILLED:
			return "Счёт за электричество для вентиляции: %s." % money(int(event.data["amount"]))
		EventLog.POWER_CUT:
			return "Счёт за электричество (%s) оплатить нечем — усиленную вентиляцию отключили. В бункере снова сыро: включить обратно — %s." % [money(int(event.data["amount"])), ClimateControls.PLACE]
		EventLog.PLOT_CROP_EATEN:
			return "Грядка %d: вредители съели весь урожай. Собирать нечего — грядка свободна под новую посадку." % plot_number(int(event.data["plot_id"]))
		EventLog.WORKER_STOLE:
			return "С грядки %d пропал урожай. Сам он уйти не мог." % plot_number(int(event.data["plot_id"]))
		EventLog.INSPECTION_WARNED:
			return "Звонит знакомый из участка: сосед написал жалобу, скоро проверка. Ответьте и решите, как её встретить."
		EventLog.INSPECTION_PASSED, EventLog.INSPECTION_FAILED:
			return InspectionTalk.outcome(event, sim)
		EventLog.RAID_STARTED:
			return "У контейнера «Молочные зубы» — в балаклавах и с телефоном: снимают клип прямо на налёте. Разберитесь, пока не обчистили ферму."
		EventLog.RAID_RESOLVED:
			return _raid_outcome(String(event.data["outcome"]), int(event.data.get("taken", 0)))
		EventLog.PLOT_STAGE_CHANGED:
			if String(event.data["stage"]) == Plot.stage_name(Plot.Stage.READY):
				return "Грядка %d созрела." % plot_number(int(event.data["plot_id"]))
		EventLog.RENT_PAID:
			if String(event.data.get("where", "")) == Rent.FROM_CREDIT:
				return "Аренду за этот срок лорд Эшкомб списал из аванса. Звонить не стал: джентльмены о деньгах дважды не говорят."
			return "Лорду Эшкомбу ушла аренда: %s. Дом пока не продают." % money(int(event.data["amount"]))
		EventLog.RENT_MISSED:
			if event.data.get("promised", false) == true:
				return RentTalk.missed_visit(event)
			return "Аренду заплатить нечем. Лорд недоволен, по округе пошли разговоры. Пропущено %d из %d.%s" % [int(event.data["missed"]), int(event.data["evict_after"]), RentTalk.debt_note(event)]
		EventLog.RENT_DEBT_PAID:
			return "Лорд Эшкомб забрал долг по аренде с пеней: %s. Пропуски прощены, отношения — почти." % money(int(event.data["amount"]))
		EventLog.RENT_EVICTED:
			return error(CommandResult.EVICTED)
	var day := DayText.announcement(event, sim)
	if not day.is_empty():
		return day
	return StoryText.announcement(event, sim)


static func _rent_is_short(sim: SimState) -> bool:
	var rent := sim.rent
	if rent.amount() <= 0 or sim.economy.money >= rent.amount():
		return false
	# The advance covers it, or the manor summons already names the sum and the hour.
	if rent.owed() <= 0 or rent.visit_promised():
		return false
	return rent.due_in(sim.clock.elapsed_game_seconds) <= RENT_WARNING_HOURS * SimClock.GAME_SECONDS_PER_HOUR


static func lord_lines(sim: SimState) -> Array[DialogueLineDef]:
	var rent := sim.rent
	if rent.evicted:
		return [
			DialogueLineDef.make(LORD, "Мне искренне жаль, мистер Кэллоуэй. Банк, знаете ли, не принимает обещаний. Я тоже больше не могу."),
			DialogueLineDef.make(REGGIE, "Поле больше не наше. Предлагаю не задерживаться."),
		]
	var due := "следующий платёж %s %s" % [money(rent.amount()), game_when(rent.next_due_at, sim, true)]
	if rent.missed > 0:
		return [
			DialogueLineDef.make(LORD, "Мистер Кэллоуэй, платёж так и не пришёл. Я не привык напоминать о деньгах. Это неловко для нас обоих."),
			DialogueLineDef.make(JACK, "Будет, милорд."),
			DialogueLineDef.make(REGGIE, "Пропущено %d из %d — после этого поле уйдёт. Аренда: %s.%s" % [rent.missed, rent.max_missed(), due, RentTalk.debt_reminder(sim)]),
		]
	return [
		DialogueLineDef.make(LORD, "Мистер Кэллоуэй. Дом всё ещё мой — полагаю, вашими стараниями. Что бы вы там ни сеяли."),
		DialogueLineDef.make(REGGIE, "Аренда: %s. Лорд ценит пунктуальность больше, чем показывает." % due),
	]


static func _raid_outcome(outcome: String, taken: int) -> String:
	var loot := DayText.crates(taken)
	match outcome:
		"paid":
			return "Гопники взяли деньги и ушли. Вежливо, по их меркам."
		"gave":
			return "Гопники забрали с фермы %s — половину. Вторую, видимо, оставили из уважения." % loot
		"chased":
			return "Гопников прогнали. Тихо, правда, не получилось."
		"helper_chased":
			return "Гопники ушли. Реджи даже не повысил голос."
	if taken == 0:
		return "Гопники покрутились у контейнера и ушли ни с чем: ящиков на ферме не было. Про тайник они не знают."
	match outcome:
		"chase_failed":
			return "Прогнать не вышло — гопники унесли с фермы %s. Уходили не спеша. До тайника они не добрались." % loot
		"helper_failed":
			return "Реджи вышел к гопникам один против толпы. Сам цел, но с фермы унесли %s. Тайник они не тронули." % loot
	return "Пока никого не было, гопники унесли с фермы %s. Без свидетелей им было удобно. Про тайник они не знают." % loot


static func error(code: String) -> String:
	return ERRORS.get(code, "Не получилось.")
