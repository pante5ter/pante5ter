class_name PhoneShop
extends RefCounted

## One tap cycles the auto-reorder rule through these stock levels.
const AUTO_STEPS: Array[int] = [0, 2, 4, 8]


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	Phone.clear(box)
	var delivery := UiText.real_duration(sim.config.delivery_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)
	box.add_child(UiStyle.label("Доставка в ящик у контейнера через %s." % delivery, 13, UiStyle.MUTED))
	_add_restock(box, sim, phone)
	for strain: StrainDef in sim.config.extra_strains:
		var item := Supplies.seed_item(strain.id)
		if not sim.progress.is_strain_unlocked(strain.id):
			var unlock := sim.progress.unlocking_milestone(strain.id)
			box.add_child(UiStyle.label("Семена «%s» откроются на уровне «%s» (%s)." % [strain.display_name, unlock.title, UiText.money(unlock.value)], 15, UiStyle.MUTED))
			continue
		_add_row(box, "Семена «%s»: %s/шт.\nРастёт %s, качество около %d." % [strain.display_name, UiText.money(strain.seed_price), UiText.real_duration(strain.growth_hours() * SimClock.GAME_SECONDS_PER_HOUR, sim), strain.base_quality], item, sim, phone)
	_add_row(box, "Удобрение: %s/шт.\n+%d к качеству одной грядки." % [UiText.money(sim.config.fertilizer_price), sim.config.fertilizer_bonus], Supplies.FERTILIZER, sim, phone)
	_add_row(box, "Средство от вредителей: %s/шт.\nВредители заводятся сами и останавливают рост грядки." % UiText.money(sim.config.problems.pesticide_price), Supplies.PESTICIDE, sim, phone)
	_add_row(box, "Запасная лампа: %s/шт.\nЛампы над грядками иногда перегорают — без света куст не растёт, пока лампу не заменят." % UiText.money(sim.config.problems.lamp_price), Supplies.LAMP, sim, phone)
	var beds := sim.grow.plots().size()
	var cap := sim.progress.plot_cap()
	var row := VBoxContainer.new()
	row.add_child(UiStyle.label("Новая грядка: %s (сейчас %d, можно до %d)." % [UiText.money(sim.config.plot_price), beds, cap]))
	row.add_child(UiStyle.button("Купить грядку", phone.buy_plot, beds < cap and sim.economy.money >= sim.config.plot_price))
	box.add_child(row)
	var pending := sim.supplies.pending_deliveries()
	if not pending.is_empty():
		var lines := PackedStringArray(["В пути:"])
		for delivery_item: Dictionary in pending:
			lines.append("%s × %d — через %s" % [UiText.item_name(String(delivery_item["item"]), sim), int(delivery_item["quantity"]), UiText.real_duration(float(delivery_item["arrives_at"]) - sim.clock.elapsed_game_seconds, sim)])
		box.add_child(UiStyle.label("\n".join(lines), 13, UiStyle.MUTED))


static func basket_text(sim: SimState) -> String:
	var parts := PackedStringArray()
	for item: String in sim.config.restock_basket:
		if sim.supplies.can_order(item):
			parts.append("%s до %d" % [UiText.item_name(item, sim), sim.config.restock_basket[item]])
	return ", ".join(parts)


static func _add_restock(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var cost := sim.supplies.basket_cost()
	var row := VBoxContainer.new()
	row.add_child(UiStyle.label("Обычный запас: %s." % basket_text(sim), 13, UiStyle.MUTED))
	var text := ("Пополнить запас — %s" % UiText.money(cost)) if cost > 0 else "Запас полный"
	row.add_child(UiStyle.button(text, phone.restock, cost > 0 and sim.economy.money > 0))
	box.add_child(row)


static func _add_row(box: VBoxContainer, text: String, item: String, sim: SimState, phone: Phone) -> void:
	var price := sim.supplies.unit_price(item)
	var row := VBoxContainer.new()
	row.add_child(UiStyle.label(text))
	var buttons := HBoxContainer.new()
	buttons.add_child(UiStyle.button("Купить 1", phone.buy.bind(item, 1), sim.economy.money >= price))
	buttons.add_child(UiStyle.button("Купить 5", phone.buy.bind(item, 5), sim.economy.money >= price * 5))
	var keep := int(sim.supplies.auto_keep.get(item, 0))
	var label := ("Авто: держать %d" % keep) if keep > 0 else "Авто: выкл"
	buttons.add_child(UiStyle.button(label, phone.set_auto_reorder.bind(item, next_auto_step(keep))))
	row.add_child(buttons)
	box.add_child(row)


static func next_auto_step(keep: int) -> int:
	for step: int in AUTO_STEPS:
		if step > keep:
			return step
	return 0
