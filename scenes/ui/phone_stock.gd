class_name PhoneStock
extends RefCounted

## The «Склад» and «Империя» apps: what is on hand, and how the business stands.


static func fill(box: VBoxContainer, sim: SimState) -> void:
	var parcel := sim.supplies.parcel()
	if not parcel.is_empty():
		var waiting := PhoneKit.card(box, PhoneKit.GOLD)
		PhoneKit.heading(waiting, "Посылка ждёт", "", PhoneKit.GOLD)
		waiting.add_child(PhoneKit.label("%s.\nЛежит у двери контейнера на краю поля — подойдите и кликните по ящику." % _parcel_text(parcel, sim)))
	var goods := PhoneKit.card(box)
	PhoneKit.heading(goods, "Товар")
	goods.add_child(PhoneKit.label(UiText.stock(sim), PhoneKit.BODY_SIZE))
	var products := sim.inventory.products()
	if not products.is_empty():
		var best := 0
		for product: Product in products:
			best = maxi(best, product.quality)
		goods.add_child(PhoneKit.label("Всего %d шт., лучшее качество %d" % [products.size(), best], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	var supplies := PhoneKit.card(box)
	PhoneKit.heading(supplies, "Расходники")
	_pair(supplies, "Семена «%s»" % sim.config.strain.display_name, "без лимита")
	for strain: StrainDef in sim.config.extra_strains:
		_pair(supplies, "Семена «%s»" % strain.display_name, str(sim.supplies.seeds(strain.id)))
	_pair(supplies, "Удобрение", str(sim.supplies.fertilizer))
	for tool: String in Supplies.TOOLS:
		_pair(supplies, UiText.capitalized(UiText.item_name(tool, sim)), str(sim.supplies.count(tool)))


static func fill_empire(box: VBoxContainer, sim: SimState) -> void:
	var value := PhoneKit.card(box, PhoneKit.GOLD)
	value.add_child(PhoneKit.label("Оценка империи", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	value.add_child(PhoneKit.label(UiText.money(sim.empire_value()), 28, PhoneKit.GOLD))
	value.add_child(PhoneKit.label("Деньги, грядки, товар на руках и в тайнике.", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	var next := sim.progress.next_milestone()
	if next != null:
		var goal := PhoneKit.card(box)
		PhoneKit.heading(goal, "Цель: «%s»" % next.title, UiText.money(next.value))
		goal.add_child(PhoneKit.label(next.description, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	var levels := PhoneKit.card(box)
	PhoneKit.heading(levels, "Уровни")
	for index: int in sim.config.milestones.size():
		var milestone := sim.config.milestones[index]
		var reached := index < sim.progress.reached
		_pair(levels, ("✔ " if reached else "") + milestone.title, UiText.money(milestone.value), PhoneKit.TEXT if reached else PhoneKit.MUTED)
	_add_rent(box, sim)
	var heat := PhoneKit.card(box, PhoneKit.DANGER if sim.suspicion.inspection_pending() else PhoneKit.CARD)
	heat.add_child(PhoneKit.label(UiText.suspicion(sim)))
	heat.add_child(PhoneKit.label("Растёт от заказов, болтливых работников, большой фермы и машины, которая ночью выезжает с поля в деревню: соседи видят фары. Проверку переживёте, если вовремя выключить свет.", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))


static func _add_rent(box: VBoxContainer, sim: SimState) -> void:
	var rent := sim.rent
	if rent.amount() <= 0:
		return
	var card := PhoneKit.card(box, PhoneKit.DANGER if rent.missed > 0 or rent.evicted else PhoneKit.CARD)
	if rent.evicted:
		card.add_child(PhoneKit.label("Лорд Эшкомб расторг аренду: поле больше не ваше."))
		return
	PhoneKit.heading(card, "Аренда лорду", UiText.money(rent.amount()))
	card.add_child(PhoneKit.label("Следующий платёж — %s." % UiText.game_when(rent.next_due_at, sim), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	if rent.missed > 0:
		card.add_child(PhoneKit.label("Пропущено подряд: %d из %d." % [rent.missed, rent.max_missed()], PhoneKit.BODY_SIZE, PhoneKit.GOLD))


static func _parcel_text(parcel: Array[Dictionary], sim: SimState) -> String:
	var items := PackedStringArray()
	for entry: Dictionary in parcel:
		items.append("%s × %d" % [UiText.item_name(String(entry["item"]), sim), int(entry["quantity"])])
	return UiText.capitalized(", ".join(items))


static func _pair(parent: Container, name: String, value: String, color: Color = PhoneKit.TEXT) -> void:
	var line := HBoxContainer.new()
	line.add_child(PhoneKit.label(name, PhoneKit.BODY_SIZE, color))
	var figure := PhoneKit.label(value, PhoneKit.BODY_SIZE, color)
	figure.size_flags_horizontal = Control.SIZE_SHRINK_END
	figure.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(figure)
	parent.add_child(line)
