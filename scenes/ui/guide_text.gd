class_name GuideText
extends RefCounted

## Reggie's lines for the first-minutes guide: one goal and one short hint per step.

const TO_FARM: String = " Сначала — на ферму, лендровер ждёт."
const DOWN_THERE: String = " Плантация внизу, через контейнер."


## The HUD objective while the guide runs; empty when it is over or something urgent comes first.
static func objective(sim: SimState, underground: bool) -> String:
	var guide := sim.first_day.guide
	if not guide.active():
		return ""
	if not sim.orders.with_status(Order.Status.OFFERED).is_empty() or _any_trouble(sim):
		return ""
	return "Шаг %d из %d. %s" % [int(guide.current()) + 1, Guide.step_count(), hint(sim, underground)]


## Reggie's plain answer to «Что делать?» while the guide runs.
static func plain(sim: SimState, underground: bool) -> String:
	var guide := sim.first_day.guide
	var step := "По плану шаг %d из %d. %s" % [int(guide.current()) + 1, Guide.step_count(), hint(sim, underground)]
	if not sim.orders.with_status(Order.Status.OFFERED).is_empty():
		return "Сначала ответьте клиенту: телефон (Tab), «Звонки». " + step
	return step


static func hint(sim: SimState, underground: bool) -> String:
	match sim.first_day.guide.current():
		Guide.Step.GO_DOWN:
			if underground:
				return _plant(sim, true)
			return "Контейнер на краю поля — кликните по нему: за стеллажом лифт на плантацию. Там посадите семена."
		Guide.Step.PLANT:
			return _plant(sim, underground)
		Guide.Step.WATER:
			var strain := sim.config.strain
			return "Полейте грядку: кликните по ней → «Полить». Воды хватает на %s, сухая грядка не растёт.%s" % [_hours(strain.water_capacity_hours, sim), _bunker_note(sim, underground)]
		Guide.Step.PRUNE:
			return _prune(sim, underground)
		Guide.Step.HIRE:
			return _hire(sim)
		Guide.Step.HARVEST:
			return _harvest(sim, underground)
		Guide.Step.HAUL:
			return _haul(sim, underground)
		Guide.Step.PACK:
			return _pack(sim)
		Guide.Step.SEND:
			return _send(sim)
	return ""


static func _plant(sim: SimState, underground: bool) -> String:
	var strain := sim.config.strain
	var text := "Посадите семена: кликните по пустой грядке. «%s» бесплатная и созреет за %s." % [strain.display_name, _hours(strain.growth_hours(), sim)]
	return text + _bunker_note(sim, underground)


static func _prune(sim: SimState, underground: bool) -> String:
	var bonus := sim.config.prune_bonus
	for plot: Plot in sim.grow.plots():
		if plot.stage == Plot.Stage.BUSH and not plot.pruned:
			return "Грядка %d стала кустом. Обрежьте листья — кликните по ней: +%d к качеству, а качество — это цена у клиента.%s" % [UiText.plot_number(plot.id), bonus, _bunker_note(sim, underground)]
	var wait := _soonest(sim, Plot.Stage.BUSH)
	var when := " Куст будет через %s." % UiText.real_duration(wait, sim) if is_finite(wait) else ""
	return "Пока растёт — про обрезку: когда росток станет кустом, обрежьте листья. +%d к качеству, а значит, и к цене.%s" % [bonus, when]


static func _hire(sim: SimState) -> String:
	var wage := -1
	for person: WorkerDef in sim.config.candidates():
		wage = person.daily_wage if wage < 0 else mini(wage, person.daily_wage)
	var text := "Двух рук на ферму мало. Наймите садовника: телефон (Tab) → «Люди». Он сам сажает, поливает и собирает — видно, как работает."
	if wage > sim.economy.money:
		text += " Нужно %s на первый день." % UiText.money(wage)
	return text


static func _harvest(sim: SimState, underground: bool) -> String:
	for plot: Plot in sim.grow.plots():
		if plot.stage == Plot.Stage.READY:
			return "Грядка %d созрела. Соберите урожай — кликните по ней. Он ляжет в ящики у лифта.%s" % [UiText.plot_number(plot.id), _bunker_note(sim, underground)]
	var wait := _soonest(sim, Plot.Stage.READY)
	if not is_finite(wait):
		return "Соберите урожай, когда созреет. Пустые грядки — посадите и полейте.%s" % _bunker_note(sim, underground)
	return "Ждём урожая: созреет через %s. Соберёте сами или садовник — урожай ляжет в ящики у лифта." % UiText.real_duration(wait, sim)


static func _haul(sim: SimState, underground: bool) -> String:
	if sim.stash.on_the_road():
		return "Ящики едут в тайник при пекарне. Как доедут — фасовка."
	if sim.inventory.farm_crates().is_empty():
		return "Сначала урожай: соберите созревшую грядку."
	return "Урожай на ферме не держим. Кликните по ящикам у лифта — %s отвезёт в тайник при пекарне. Или везите сами.%s" % [UiText.REGGIE, _bunker_note(sim, underground)]


static func _pack(sim: SimState) -> String:
	var now := sim.clock.elapsed_game_seconds
	if sim.packing.busy():
		return "Фасуется. Коробки лягут на полку в тайнике через %s." % UiText.real_duration(sim.packing.ends_at - now, sim)
	var why := "клиенты берут только коробки, россыпью не продаём"
	if sim.day.place == DayCycle.STASH and not sim.day.travelling():
		return "Расфасуйте урожай: кликните по столу фасовки — %s." % why
	return "Ящики в тайнике при пекарне. Езжайте туда на лендровере и расфасуйте на столе: %s." % why


static func _send(sim: SimState) -> String:
	var accepted := sim.orders.with_status(Order.Status.ACCEPTED)
	for order: Order in accepted:
		if sim.orders.can_fill(order):
			return "Заказ #%d готов. Компьютер в бункере или в тайнике → «Заказы» → «Отправить». %s довезёт." % [order.id, UiText.REGGIE]
	if not accepted.is_empty():
		var order := accepted[0]
		return "Заказ #%d ждёт %d шт. качества %d+. Растим и фасуем ещё." % [order.id, order.quantity, order.min_quality]
	return "Коробки на полке. Ждём звонка клиента — ответьте по телефону (Tab), потом отправьте заказ с компьютера."


static func _bunker_note(sim: SimState, underground: bool) -> String:
	if sim.day.place != DayCycle.FARM or sim.day.travelling():
		return TO_FARM
	return "" if underground else DOWN_THERE


## Game seconds until the first growing bed reaches `stage`; INF when none is on its way.
static func _soonest(sim: SimState, stage: Plot.Stage) -> float:
	var best := INF
	for plot: Plot in sim.grow.plots():
		if not plot.is_growing() or plot.stage >= stage:
			continue
		var strain := sim.grow.strain_of(plot)
		var left := sim.grow.stage_duration(plot) - plot.progress_seconds
		var next := plot.stage + 1
		while next < stage:
			left += _stage_hours(strain, next as Plot.Stage) * SimClock.GAME_SECONDS_PER_HOUR
			next += 1
		best = minf(best, left)
	return best


static func _stage_hours(strain: StrainDef, stage: Plot.Stage) -> float:
	match stage:
		Plot.Stage.SPROUT:
			return strain.sprout_hours
		Plot.Stage.BUSH:
			return strain.bush_hours
	return 0.0


static func _hours(game_hours: float, sim: SimState) -> String:
	return UiText.real_duration(game_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)


static func _any_trouble(sim: SimState) -> bool:
	for plot: Plot in sim.grow.plots():
		if not plot.problem.is_empty():
			return true
	return false
