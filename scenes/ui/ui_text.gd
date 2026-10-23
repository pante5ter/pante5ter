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
	CommandResult.ORDER_NOT_OPEN: "Этот заказ уже в тайнике.",
	CommandResult.NOT_ENOUGH_PRODUCT: "Не хватает товара нужного качества.",
	CommandResult.STRAIN_LOCKED: "Этот сорт пока недоступен — вырасти империю.",
	CommandResult.NO_SUPPLY: "Нечем лечить — закажи в телефоне.",
	CommandResult.NO_PROBLEM: "С грядкой всё в порядке.",
	CommandResult.NO_RAID: "Никого нет.",
	CommandResult.UNKNOWN_CHOICE: "Так нельзя.",
	CommandResult.UNKNOWN_WORKER: "Такого работника нет.",
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


static func item_name(item: String, sim: SimState) -> String:
	if item == Supplies.FERTILIZER:
		return "удобрение"
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
	var any_planted := false
	var any_ready := false
	var any_dry := false
	for plot: Plot in sim.grow.plots():
		any_planted = any_planted or plot.stage != Plot.Stage.EMPTY
		any_ready = any_ready or plot.stage == Plot.Stage.READY
		any_dry = any_dry or (plot.is_growing() and plot.water_seconds <= 0.0)
	if any_ready:
		return "Собери созревший урожай на плантации."
	if sim.inventory.count() > 0:
		return _selling_objective(sim)
	if any_dry:
		return "Полей сухие грядки на плантации."
	if not any_planted:
		return "Спустись через контейнер на плантацию и посади растения."
	var worker := sim.workers.definition()
	if not sim.workers.hired and sim.economy.money >= worker.daily_wage:
		return "Найми %s у дороги — он будет сам ухаживать за грядками." % worker.display_name
	return "Жди урожай. Пока растёт — закажи семена и удобрения в телефоне (Tab), обрежь кусты."


static func _selling_objective(sim: SimState) -> String:
	var orders := sim.orders.all()
	for order: Order in orders:
		if sim.orders.can_fill(order):
			return "Положи заказ в тайник у западного края поля."
	if orders.is_empty():
		return "Жди заказ — он придёт в телефон (Tab)."
	return "Заказам нужно качество выше — удобряй и обрезай кусты."


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
			return "Новый заказ в телефоне: %d шт., качество %d+, %s." % [int(event.data["quantity"]), int(event.data["min_quality"]), money(int(event.data["reward"]))]
		EventLog.ORDER_PAID:
			return "Курьер забрал заказ #%d: +%s." % [int(event.data["order_id"]), money(int(event.data["reward"]))]
		EventLog.ORDER_EXPIRED:
			return "Заказ #%d сгорел — не успели." % int(event.data["order_id"])
		EventLog.SUPPLY_DELIVERED:
			return "Посылка в ящике у контейнера: %s × %d." % [item_name(String(event.data["item"]), sim), int(event.data["quantity"])]
		EventLog.PLOT_STAGE_CHANGED:
			if String(event.data["stage"]) == Plot.stage_name(Plot.Stage.READY):
				return "Грядка %d созрела." % plot_number(int(event.data["plot_id"]))
	return ""


static func error(code: String) -> String:
	return ERRORS.get(code, "Не получилось.")
