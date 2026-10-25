class_name PhoneShop
extends RefCounted

## One tap cycles the auto-reorder rule through these stock levels.
const AUTO_STEPS: Array[int] = [0, 2, 4, 8]


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var delivery := UiText.real_duration(sim.config.delivery_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)
	box.add_child(PhoneKit.label("Привезут к двери контейнера через %s." % delivery, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
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
	var pending := sim.supplies.pending_deliveries()
	if not pending.is_empty():
		var road := PhoneKit.card(box)
		PhoneKit.heading(road, "В пути")
		for delivery_item: Dictionary in pending:
			var left := UiText.real_duration(float(delivery_item["arrives_at"]) - sim.clock.elapsed_game_seconds, sim)
			road.add_child(PhoneKit.label("%s × %d — через %s" % [UiText.item_name(String(delivery_item["item"]), sim), int(delivery_item["quantity"]), left], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))


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
