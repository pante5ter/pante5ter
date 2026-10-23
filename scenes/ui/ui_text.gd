class_name UiText
extends RefCounted

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
	if not sim.couriers.is_free(Couriers.JACK, sim.clock.elapsed_game_seconds):
		text += "\nДжек в дороге с заказом"
	return text


static func courier_name(courier_id: String, sim: SimState) -> String:
	if courier_id == Couriers.JACK:
		return "Джек"
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


static func objective(sim: SimState) -> String:
	if sim.raids.pending:
		return "У контейнера гопники! Иди наверх и разберись, пока не обчистили."
	if sim.suspicion.inspection_pending() and not sim.suspicion.quiet:
		return "Едет проверка! Затихни: на компьютере выключи свет и придержи курьеров."
	if not sim.supplies.parcel().is_empty():
		return "У контейнера ждёт посылка — забери её."
	var any_planted := false
	var any_ready := false
	var any_dry := false
	for plot: Plot in sim.grow.plots():
		any_planted = any_planted or plot.stage != Plot.Stage.EMPTY
		any_ready = any_ready or plot.stage == Plot.Stage.READY
		any_dry = any_dry or (plot.is_growing() and plot.water_seconds <= 0.0)
	for plot: Plot in sim.grow.plots():
		if not plot.problem.is_empty():
			return "Грядка %d: %s. Вылечи её, иначе урожай пропадёт." % [plot_number(plot.id), problem(plot.problem)]
	if not sim.orders.with_status(Order.Status.OFFERED).is_empty():
		return "Звонит клиент — ответь на компьютере на плантации."
	if any_ready:
		return "Собери созревший урожай на плантации."
	if sim.inventory.count() > 0:
		return _selling_objective(sim)
	if any_dry:
		return "Полей сухие грядки на плантации."
	if not any_planted:
		return "Спустись через контейнер на плантацию и посади растения."
	if not sim.workers.hired and sim.economy.money >= sim.workers.definition().daily_wage:
		return "Найми работника у дороги — он будет сам ухаживать за грядками."
	return "Жди урожай. Пока растёт — закажи семена и удобрения в телефоне (Tab), обрежь кусты."


static func _selling_objective(sim: SimState) -> String:
	if sim.packing.unpacked_count() > 0 and not sim.packing.busy():
		return "Расфасуй урожай на столе на плантации."
	var accepted := sim.orders.with_status(Order.Status.ACCEPTED)
	for order: Order in accepted:
		if sim.orders.can_fill(order):
			return "Отправь заказ курьером или отвези сам — с компьютера."
	if accepted.is_empty():
		return "Товар на полке. Жди звонков клиентов на компьютер."
	return "Заказу нужно качество выше — удобряй и обрезай кусты."


static func announcement(event: SimEvent, sim: SimState) -> String:
	var worker := sim.workers.definition()
	match event.type:
		EventLog.WORKER_QUIT:
			return "%s ушёл: нечем было заплатить зарплату." % worker.display_name
		EventLog.WORKER_PAID:
			return "Зарплата %s: %s." % [worker.display_name, money(int(event.data["wage"]))]
		EventLog.PLOT_DRIED_OUT:
			return "Грядка %d пересохла — рост остановился." % plot_number(int(event.data["plot_id"]))
		EventLog.ORDER_RECEIVED:
			return "Звонок: нужно %d шт., качество %d+, %s. Ответь на компьютере." % [int(event.data["quantity"]), int(event.data["min_quality"]), money(int(event.data["reward"]))]
		EventLog.ORDER_MISSED:
			return "Клиент не дождался ответа и повесил трубку."
		EventLog.ORDER_HAGGLED:
			return "Клиент поворчал, но согласился на %s." % money(int(event.data["reward"]))
		EventLog.ORDER_WALKED_AWAY:
			return "Клиенту не понравился торг — ушёл к другим."
		EventLog.ORDER_PAID:
			var fee := int(event.data["fee"])
			return "Заказ #%d доставлен: +%s%s." % [int(event.data["order_id"]), money(int(event.data["reward"]) - fee), (" (курьеру %s)" % money(fee)) if fee > 0 else ""]
		EventLog.ORDER_EXPIRED:
			return "Заказ #%d сгорел — не успели." % int(event.data["order_id"])
		EventLog.DELIVERY_STOPPED:
			return "Курьера остановили по дороге — товар пропал, о ферме заговорили."
		EventLog.COURIER_STOLE:
			return "Курьер %s пропал вместе с товаром." % courier_name(String(event.data["courier_id"]), sim)
		EventLog.PACKING_DONE:
			return "Расфасовано: %d шт. — на полке склада." % int(event.data["units"])
		EventLog.SUPPLY_DELIVERED:
			return "Посылка у контейнера: %s × %d — забери." % [item_name(String(event.data["item"]), sim), int(event.data["quantity"])]
		EventLog.MILESTONE_REACHED:
			var reached := sim.config.milestones[int(event.data["index"])]
			return "Новый уровень — «%s». %s" % [reached.title, reached.description]
		EventLog.PLOT_PROBLEM:
			return "Грядка %d: %s!" % [plot_number(int(event.data["plot_id"])), problem(String(event.data["problem"]))]
		EventLog.WORKER_STOLE:
			return "С грядки %d пропал урожай. Кто-то нечист на руку…" % plot_number(int(event.data["plot_id"]))
		EventLog.INSPECTION_WARNED:
			return "Сосед заметил неладное — скоро проверка! Затихни: выключи свет и придержи курьеров."
		EventLog.INSPECTION_PASSED:
			return "Проверяющий потоптался у контейнера и ушёл ни с чем."
		EventLog.INSPECTION_FAILED:
			return "Проверка: пришлось откупиться на %s." % money(int(event.data["fine"]))
		EventLog.RAID_STARTED:
			return "У контейнера гопники! Разберись, пока не обчистили."
		EventLog.RAID_RESOLVED:
			return _raid_outcome(String(event.data["outcome"]))
		EventLog.PLOT_STAGE_CHANGED:
			if String(event.data["stage"]) == Plot.stage_name(Plot.Stage.READY):
				return "Грядка %d созрела." % plot_number(int(event.data["plot_id"]))
	return ""


static func _raid_outcome(outcome: String) -> String:
	match outcome:
		"paid":
			return "Гопники взяли деньги и ушли."
		"gave":
			return "Гопники забрали половину товара."
		"chased":
			return "Гопников прогнали. Шуму, правда, наделали."
		"chase_failed":
			return "Прогнать не вышло — гопники обчистили всё."
	return "Гопники обчистили всё, пока никого не было."


static func error(code: String) -> String:
	return ERRORS.get(code, "Не получилось.")
