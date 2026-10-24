class_name UiText
extends RefCounted

const LORD: String = "Лорд Эшкомб"
const FINN: String = "Финн"
const JACK: String = "Джек"
## Finn starts nagging about rent this many game hours before it is due.
const RENT_WARNING_HOURS: float = 12.0

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
	CommandResult.LYING_LOW: "Ферма затихла — курьеры сидят дома.",
	CommandResult.NOTHING_TO_PACK: "Фасовать нечего — сначала собери урожай.",
	CommandResult.NO_PARCEL: "Посылок нет.",
	CommandResult.EVICTED: "Лорд Эшкомб расторг аренду. Поле больше не ваше, мистер Кэллоуэй.",
	CommandResult.UNKNOWN_SKILL: "Такому не учат.",
	CommandResult.HELPER_AWAY: "Помощника сейчас нет на ферме — он в дороге или на курсах.",
	CommandResult.NOTHING_TO_RESTOCK: "Запас и так полный.",
	CommandResult.NO_STORY: "Этот разговор уже закончен.",
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
	return "%d:%02d" % [floori(real_seconds / 60.0), real_seconds % 60]


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
		text += " · ПРОВЕРКА через %s" % real_duration(sim.suspicion.inspection_at - sim.clock.elapsed_game_seconds, sim)
	if sim.suspicion.quiet:
		text += " · ферма затихла"
	return text


static func stock(sim: SimState) -> String:
	var packed := 0
	for product: Product in sim.inventory.products():
		if product.packed:
			packed += 1
	var loose := sim.inventory.count() - packed
	var text := "Товар: %d коробок на полке" % packed
	if loose > 0:
		text += ", %d нефасованных" % loose
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


static func stage(value: Plot.Stage) -> String:
	return STAGE_NAMES.get(value, "?")


static func capitalized(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


static func plot_number(plot_id: int) -> int:
	return plot_id + 1


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
		return "Через %s аренда лорду — %s, а в кассе %s. Продайте товар через компьютер, иначе лорд обидится." % [real_duration(sim.rent.due_in(sim.clock.elapsed_game_seconds), sim), money(sim.rent.amount()), money(sim.economy.money)]
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
		return "Двух рук на ферму мало. Наймите работника в телефоне (Tab, «Люди») — он сам займётся грядками."
	return "Терпение. А пока закажите семена и удобрения в телефоне (Tab), обрежьте кусты."


static func _selling_objective(sim: SimState) -> String:
	if sim.packing.unpacked_count() > 0 and not sim.packing.busy():
		return "Россыпью приличные люди не продают. Расфасуйте урожай на столе на плантации."
	var accepted := sim.orders.with_status(Order.Status.ACCEPTED)
	for order: Order in accepted:
		if sim.orders.can_fill(order):
			return "Заказ готов. На компьютере отправьте %s или курьера." % _driver_name(sim)
	if accepted.is_empty():
		return "Товар на полке. Теперь ждём звонков — клиенты звонят на телефон."
	return "Клиент хочет лучше, чем у нас есть. Удобряйте и обрезайте кусты на плантации."


static func _driver_name(sim: SimState) -> String:
	return sim.helper.definition().display_name if sim.helper.exists() else "курьера"


static func _person(event: SimEvent, sim: SimState) -> WorkerDef:
	var worker_id := String(event.data.get("worker_id", ""))
	if sim.helper.exists() and worker_id == sim.helper.definition().id:
		return sim.helper.definition()
	var packer := sim.config.find_packer(worker_id)
	if packer != null:
		return packer
	var farmhand := sim.config.find_worker(worker_id)
	return farmhand if farmhand != null else sim.workers.definition()


static func announcement(event: SimEvent, sim: SimState) -> String:
	var worker := _person(event, sim)
	match event.type:
		EventLog.WORKER_QUIT:
			return "%s %s: платить было нечем, а бесплатно работать — не по правилам. Принципиальн%s." % [worker.display_name, PeopleText.left_word(worker), "ый" if worker.male else "ая"]
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
		EventLog.PLOT_TREATED:
			if event.actors.has(Helper.ACTOR):
				return "%s вылечил грядку %d: %s — больше не проблема." % [_driver_name(sim), plot_number(int(event.data["plot_id"])), problem(String(event.data["problem"]))]
		EventLog.PLOT_DRIED_OUT:
			return "Грядка %d пересохла — рост остановился." % plot_number(int(event.data["plot_id"]))
		EventLog.ORDER_RECEIVED:
			if event.data.get("urgent", false) == true:
				return StoryText.urgent_call(event)
			return "Звонит клиент: нужно %d шт., качество %d+, %s. Ответьте по телефону (Tab)." % [int(event.data["quantity"]), int(event.data["min_quality"]), money(int(event.data["reward"]))]
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
			return "Курьер %s исчез вместе с товаром. Открытки, полагаю, не будет." % courier_name(String(event.data["courier_id"]), sim)
		EventLog.PACKING_DONE:
			return "Расфасовано: %d шт. — на полке склада." % int(event.data["units"])
		EventLog.SUPPLY_DELIVERED:
			return "Посылка у контейнера: %s × %d — заберите." % [item_name(String(event.data["item"]), sim), int(event.data["quantity"])]
		EventLog.MILESTONE_REACHED:
			var reached := sim.config.milestones[int(event.data["index"])]
			return "Новый уровень — «%s». Неплохо, мистер Кэллоуэй. %s" % [reached.title, reached.description]
		EventLog.PLOT_PROBLEM:
			return "Грядка %d: %s. Лучше заняться сейчас, чем объяснять потом." % [plot_number(int(event.data["plot_id"])), problem(String(event.data["problem"]))]
		EventLog.WORKER_STOLE:
			return "С грядки %d пропал урожай. Сам он уйти не мог." % plot_number(int(event.data["plot_id"]))
		EventLog.INSPECTION_WARNED:
			if sim.helper.exists():
				return "Сосед проявил бдительность — скоро проверка. На компьютере выключите свет, или %s сделает это сам в последний момент." % _driver_name(sim)
			return "Сосед проявил бдительность — скоро проверка. На компьютере выключите свет и придержите курьеров."
		EventLog.INSPECTION_PASSED:
			return "Проверяющий потоптался у контейнера и уехал ни с чем. Приятный человек."
		EventLog.INSPECTION_FAILED:
			return "Проверка обошлась в %s. Взятка — тоже статья расходов." % money(int(event.data["fine"]))
		EventLog.RAID_STARTED:
			return "У контейнера «Молочные зубы» — в балаклавах и с телефоном: снимают клип прямо на налёте. Разберитесь, пока не обчистили ферму."
		EventLog.RAID_RESOLVED:
			return _raid_outcome(String(event.data["outcome"]))
		EventLog.PLOT_STAGE_CHANGED:
			if String(event.data["stage"]) == Plot.stage_name(Plot.Stage.READY):
				return "Грядка %d созрела." % plot_number(int(event.data["plot_id"]))
		EventLog.RENT_PAID:
			return "Лорду Эшкомбу ушла аренда: %s. Дом пока не продают." % money(int(event.data["amount"]))
		EventLog.RENT_MISSED:
			return "Аренду заплатить нечем. Лорд недоволен, по округе пошли разговоры. Пропущено %d из %d." % [int(event.data["missed"]), int(event.data["evict_after"])]
		EventLog.RENT_EVICTED:
			return error(CommandResult.EVICTED)
	return StoryText.announcement(event, sim)


static func _rent_is_short(sim: SimState) -> bool:
	var rent := sim.rent
	if rent.amount() <= 0 or sim.economy.money >= rent.amount():
		return false
	return rent.due_in(sim.clock.elapsed_game_seconds) <= RENT_WARNING_HOURS * SimClock.GAME_SECONDS_PER_HOUR


static func lord_lines(sim: SimState) -> Array[DialogueLineDef]:
	var rent := sim.rent
	if rent.evicted:
		return [
			DialogueLineDef.make(LORD, "Мне искренне жаль, мистер Кэллоуэй. Банк, знаете ли, не принимает обещаний. Я тоже больше не могу."),
			DialogueLineDef.make(FINN, "Поле больше не наше. Предлагаю не задерживаться."),
		]
	var due := "следующий платёж %s через %s" % [money(rent.amount()), real_duration(rent.due_in(sim.clock.elapsed_game_seconds), sim)]
	if rent.missed > 0:
		return [
			DialogueLineDef.make(LORD, "Мистер Кэллоуэй, платёж так и не пришёл. Я не привык напоминать о деньгах. Это неловко для нас обоих."),
			DialogueLineDef.make(JACK, "Будет, милорд."),
			DialogueLineDef.make(FINN, "Пропущено %d из %d — после этого поле уйдёт. Аренда: %s." % [rent.missed, rent.max_missed(), due]),
		]
	return [
		DialogueLineDef.make(LORD, "Мистер Кэллоуэй. Дом всё ещё мой — полагаю, вашими стараниями. Что бы вы там ни сеяли."),
		DialogueLineDef.make(FINN, "Аренда: %s. Лорд ценит пунктуальность больше, чем показывает." % due),
	]


static func _raid_outcome(outcome: String) -> String:
	match outcome:
		"paid":
			return "Гопники взяли деньги и ушли. Вежливо, по их меркам."
		"gave":
			return "Гопники забрали половину товара. Вторую, видимо, оставили из уважения."
		"chased":
			return "Гопников прогнали. Тихо, правда, не получилось."
		"chase_failed":
			return "Прогнать не вышло — гопники обчистили всё. Уходили не спеша."
		"helper_chased":
			return "Гопники ушли. Помощник даже не повысил голос."
		"helper_failed":
			return "Помощник вышел к гопникам один против толпы. Товар унесли, сам цел."
	return "Гопники обчистили всё, пока никого не было. Без свидетелей им было удобно."


static func error(code: String) -> String:
	return ERRORS.get(code, "Не получилось.")
