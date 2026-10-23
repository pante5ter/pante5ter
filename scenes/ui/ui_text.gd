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
}


static func money(amount: int) -> String:
	return "£%d" % amount


static func clock(sim_clock: SimClock) -> String:
	var hour := sim_clock.hour_of_day()
	var whole_hour := floori(hour)
	var minute := floori((hour - float(whole_hour)) * 60.0)
	return "День %d · %02d:%02d" % [sim_clock.day() + 1, whole_hour, minute]


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
	if sim.inventory.count() > 0:
		return "Продай урожай покупателю у дороги."
	var any_planted := false
	var any_ready := false
	var any_dry := false
	for plot: Plot in sim.grow.plots():
		any_planted = any_planted or plot.stage != Plot.Stage.EMPTY
		any_ready = any_ready or plot.stage == Plot.Stage.READY
		any_dry = any_dry or (plot.is_growing() and plot.water_seconds <= 0.0)
	if any_ready:
		return "Собери созревший урожай на плантации."
	if any_dry:
		return "Полей сухие грядки на плантации."
	if not any_planted:
		return "Спустись через контейнер на плантацию и посади растения."
	var worker := sim.workers.definition()
	if not sim.workers.hired and sim.economy.money >= worker.daily_wage:
		return "Найми %s у дороги — он будет сам ухаживать за грядками." % worker.display_name
	return "Жди урожай и следи, чтобы грядки не пересыхали."


static func announcement(event: SimEvent, sim: SimState) -> String:
	var worker := sim.workers.definition()
	match event.type:
		EventLog.WORKER_QUIT:
			return "%s ушёл: нечем было заплатить зарплату." % worker.display_name
		EventLog.WORKER_PAID:
			return "Зарплата %s: %s." % [worker.display_name, money(int(event.data["wage"]))]
		EventLog.PLOT_DRIED_OUT:
			return "Грядка %d пересохла — рост остановился." % plot_number(int(event.data["plot_id"]))
		EventLog.PLOT_STAGE_CHANGED:
			if String(event.data["stage"]) == Plot.stage_name(Plot.Stage.READY):
				return "Грядка %d созрела." % plot_number(int(event.data["plot_id"]))
	return ""


static func error(code: String) -> String:
	return ERRORS.get(code, "Не получилось.")
