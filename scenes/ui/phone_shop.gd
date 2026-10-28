class_name PhoneShop
extends RefCounted

## One tap cycles the auto-reorder rule through these stock levels.
## With one delivery a day a big farm keeps a day's worth in stock.
const AUTO_STEPS: Array[int] = [0, 2, 4, 8, 16, 32]


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	box.add_child(PhoneKit.label(delivery_line(sim), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	_add_village(box, sim, phone)
	_add_restock(box, sim, phone)
	for strain: StrainDef in sim.config.extra_strains:
		var item := Supplies.seed_item(strain.id)
		if not sim.progress.is_strain_unlocked(strain.id):
			var unlock := sim.progress.unlocking_milestone(strain.id)
			var locked := PhoneKit.card(box)
			PhoneKit.heading(locked, "Семена «%s»" % strain.display_name, "", PhoneKit.MUTED)
			locked.add_child(PhoneKit.label("Откроются на уровне «%s» (%s)." % [unlock.title, UiText.money(unlock.value)], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
			continue
		var growth := UiText.real_duration(strain.growth_hours() * SimClock.GAME_SECONDS_PER_HOUR, sim)
		_add_item(box, "Семена «%s»" % strain.display_name, "Растёт %s, качество около %d" % [growth, strain.base_quality], item, sim.supplies.seeds(strain.id), sim, phone)
	PhonePlan.fill(box, sim, phone)
	_add_item(box, "Удобрение", "+%d к качеству одной грядки" % sim.config.fertilizer_bonus, Supplies.FERTILIZER, sim.supplies.fertilizer, sim, phone)
	_add_item(box, "Средство от вредителей", "Вредители останавливают рост грядки", Supplies.PESTICIDE, sim.supplies.count(Supplies.PESTICIDE), sim, phone)
	_add_item(box, "Запасная лампа", "Без света куст не растёт, пока лампу не заменят", Supplies.LAMP, sim.supplies.count(Supplies.LAMP), sim, phone)
	var beds := sim.grow.plots().size()
	var cap := sim.progress.plot_cap()
	var plot := PhoneKit.card(box)
	PhoneKit.heading(plot, "Новая грядка", UiText.money(sim.config.plot_price))
	plot.add_child(PhoneKit.label("Сейчас %d, можно до %d" % [beds, cap], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	plot.add_child(PhoneKit.secondary("Купить грядку", phone.buy_plot, beds < cap and sim.economy.money >= sim.config.plot_price))
	PhoneUpgrades.fill(box, sim, phone)
	var pending := sim.supplies.pending_deliveries()
	if not pending.is_empty():
		var road := PhoneKit.card(box)
		PhoneKit.heading(road, "В пути")
		for delivery_item: Dictionary in pending:
			var left := UiText.real_duration(float(delivery_item["arrives_at"]) - sim.clock.elapsed_game_seconds, sim)
			road.add_child(PhoneKit.label("%s × %d — через %s" % [UiText.item_name(String(delivery_item["item"]), sim), int(delivery_item["quantity"]), left], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))


## When an order placed now arrives: «завтра в 09:00», or a countdown without a daily delivery.
static func delivery_text(sim: SimState) -> String:
	var now := sim.clock.elapsed_game_seconds
	if not sim.supplies.daily_delivery():
		return "через %s" % UiText.real_duration(sim.supplies.arrival_for(now) - now, sim)
	return EconText.delivery_when(sim.supplies.arrival_for(now), sim)


static func delivery_line(sim: SimState) -> String:
	if not sim.supplies.daily_delivery():
		return "Привезут к двери контейнера %s." % delivery_text(sim)
	var now := sim.clock.elapsed_game_seconds
	return "Поставка раз в день к двери контейнера. Заказ сейчас приедет %s; заказы до %s успевают к ней." % [delivery_text(sim), PhoneNews.time_of_day(sim.supplies.cutoff_for(now))]


## Jack in the village: the supply store sells on the spot, dearer.
static func _add_village(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	if not sim.in_village() or sim.config.shop == null:
		return
	var card := PhoneKit.card(box, PhoneKit.GOLD)
	PhoneKit.heading(card, "Деревенская лавка", "+%d%%" % roundi(sim.config.shop.village_markup * 100.0))
	card.add_child(PhoneKit.label("Джек рядом — купить сразу, без ожидания поставки. Дороже, и семян тут нет.", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	for item: String in sim.config.shop.village_items:
		var price := sim.supplies.village_price(item)
		if price <= 0:
			continue
		var title := UiText.capitalized(UiText.item_name(item, sim))
		card.add_child(PhoneKit.secondary("%s — %s" % [title, UiText.money(price)], phone.buy_in_village.bind(item, 1), sim.economy.money >= price))


## One line of the restock: the usual stock of an item, what is in hand or coming, what is missing.
class Shortfall:
	extends RefCounted
	var item: String = ""
	var keep: int = 0
	var have: int = 0
	var need: int = 0
	var price: int = 0

	func cost() -> int:
		return need * price


## What «Пополнить запас» pays for: only the gap up to the usual stock, parcels on the way included.
static func shortfalls(sim: SimState) -> Array[Shortfall]:
	var lines: Array[Shortfall] = []
	for item: String in sim.config.restock_basket:
		if not sim.supplies.can_order(item):
			continue
		var line := Shortfall.new()
		line.item = item
		line.keep = sim.config.restock_basket[item]
		line.have = sim.supplies.stock_and_coming(item)
		line.need = maxi(line.keep - line.have, 0)
		line.price = sim.supplies.unit_price(item)
		lines.append(line)
	return lines


static func _add_restock(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var cost := sim.supplies.basket_cost()
	var card := PhoneKit.card(box, PhoneKit.GOLD)
	PhoneKit.heading(card, "Обычный запас", UiText.money(cost) if cost > 0 else "")
	card.add_child(PhoneKit.label("Докупаем только недостающее до нормы. Что лежит на складе или уже едет, второй раз не берём — поэтому цена каждый раз своя.", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	for line: Shortfall in shortfalls(sim):
		var item := UiText.capitalized(UiText.item_name(line.item, sim))
		if line.need > 0:
			card.add_child(PhoneKit.label("%s: %d × %s = %s (есть %d из %d)" % [item, line.need, UiText.money(line.price), UiText.money(line.cost()), line.have, line.keep], PhoneKit.SMALL_SIZE))
		else:
			card.add_child(PhoneKit.label("%s: хватает (%d из %d)" % [item, line.have, line.keep], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	if cost > sim.economy.money:
		card.add_child(PhoneKit.label("Денег на всё не хватит — купим, сколько выйдет, по порядку списка.", PhoneKit.SMALL_SIZE, PhoneKit.WARNING))
	var text := ("Пополнить запас — %s" % UiText.money(cost)) if cost > 0 else "Запас полный"
	card.add_child(PhoneKit.primary(text, phone.restock, cost > 0 and sim.economy.money > 0))


static func _add_item(box: VBoxContainer, title: String, effect: String, item: String, have: int, sim: SimState, phone: Phone) -> void:
	var price := sim.supplies.unit_price(item)
	var card := PhoneKit.card(box)
	PhoneKit.heading(card, title, "%s/шт." % UiText.money(price))
	card.add_child(PhoneKit.label("%s · на складе %d" % [effect, have], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	var keep := int(sim.supplies.auto_keep.get(item, 0))
	var buttons: Array[Button] = [
		PhoneKit.secondary("Купить 1", phone.buy.bind(item, 1), sim.economy.money >= price),
		PhoneKit.secondary("Купить 5", phone.buy.bind(item, 5), sim.economy.money >= price * 5),
		PhoneKit.secondary(("Авто: %d" % keep) if keep > 0 else "Авто: выкл", phone.set_auto_reorder.bind(item, next_auto_step(keep))),
	]
	buttons[2].tooltip_text = "Реджи сам докупает, чтобы на складе было столько штук"
	PhoneKit.row(card, buttons)


static func next_auto_step(keep: int) -> int:
	for step: int in AUTO_STEPS:
		if step > keep:
			return step
	return 0
