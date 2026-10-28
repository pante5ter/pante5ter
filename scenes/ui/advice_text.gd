class_name AdviceText
extends RefCounted

## What Reggie says to «Что делать?»: the guide's step while it runs, then the most useful thing to do.


static func text(sim: SimState, underground: bool) -> String:
	if sim.first_day.guide.active():
		return GuideText.plain(sim, underground)
	return say(Advice.next(sim), sim)


static func say(advice: Advice, sim: SimState) -> String:
	match advice.kind:
		Advice.EVICTED:
			return UiText.error(CommandResult.EVICTED)
		Advice.RAID:
			return "У контейнера гопники. Сначала они, потом всё остальное."
		Advice.INSPECTION:
			return "Едет проверка. Компьютер → «Ферма» → «Затихнуть»: свет выключен, курьеры дома. Скука — лучшая маскировка."
		Advice.RENT:
			if sim.rent.visit_promised():
				return "Лорд ждёт аренду %s в поместье %s. Джентльмены не опаздывают — по крайней мере, к деньгам." % [UiText.money(sim.rent.owed()), RentTalk.deadline(sim)]
			return "Аренда %s %s, а в кассе %s. Продайте коробки — объясняться с лордом дороже." % [UiText.money(advice.amount), UiText.game_when(sim.rent.next_due_at, sim, true), UiText.money(sim.economy.money)]
		Advice.CALL:
			return "Звонит клиент — телефон (Tab), «Звонки». Дважды они не звонят."
		Advice.SEND:
			return "Заказ #%d готов: компьютер → «Заказы» → «Отправить». Коробки на полке не дорожают." % advice.order_id
		Advice.PACK:
			return "В тайнике %d шт. россыпью. Расфасуйте на столе: клиенты берут только коробки." % advice.amount
		Advice.HAUL:
			return "На ферме %s. Кликните по ящикам у лифта — отвезу в тайник. Урожаю на ферме не место." % DayText.crates(advice.amount)
		Advice.HARVEST:
			return "%s. Соберите урожай — садовник тоже соберёт, если не занят." % _beds("Созрела грядка", "Созрели грядки", advice.plot_ids)
		Advice.WATER:
			return "%s. Полейте: сухая грядка не растёт и теряет качество." % _beds("Сухая грядка", "Сухие грядки", advice.plot_ids)
		Advice.PROBLEM:
			var plot := sim.grow.plot(advice.plot_ids[0])
			return "Грядка %d: %s. %s — на плантации, пока урожай цел." % [UiText.plot_number(plot.id), UiText.problem(plot.problem), UiText.cure(plot.problem)]
		Advice.HIRE:
			return "Садовника нет. Телефон (Tab) → «Люди»: от %s в день, и грядки на нём." % UiText.money(advice.amount)
		Advice.EXPAND:
			return "В кассе %s без дела. Новая грядка — %s в «Магазине». Больше грядок — больше коробок." % [UiText.money(sim.economy.money), UiText.money(advice.amount)]
		Advice.LIE_LOW:
			return "Подозрение %d%%. Пару часов не растём: меньше заказов, ночью — домой. Совсем жарко — компьютер, «Затихнуть»." % advice.amount
		Advice.PLANT:
			return "%s. Посадите — земля без дела аренду не оплачивает." % _beds("Пустая грядка", "Пустые грядки", advice.plot_ids)
		Advice.WAIT_STOCK:
			return "Заказ #%d ждёт коробок. Растим, собираем, фасуем — и отправляем." % advice.order_id
	return "Всё под контролем, мистер Кэллоуэй. Грядки растут, звонков ждём. Можно выпить чаю."


## «Созрела грядка 2» / «Созрели грядки 2, 4, 5».
static func _beds(one: String, many: String, plot_ids: Array[int]) -> String:
	var numbers := PackedStringArray()
	for plot_id: int in plot_ids:
		numbers.append(str(UiText.plot_number(plot_id)))
	return "%s %s" % [one if plot_ids.size() == 1 else many, ", ".join(numbers)]
