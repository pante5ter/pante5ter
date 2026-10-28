class_name PhoneUpgrades
extends RefCounted

## The shop's big kit: what each piece does, what it costs to run, and when it unlocks.


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var catalogue := sim.upgrades.catalogue()
	if catalogue.is_empty():
		return
	box.add_child(PhoneKit.label("Оборудование для бункера", PhoneKit.TITLE_SIZE, PhoneKit.MUTED))
	var daily := sim.upgrades.daily_cost()
	if daily > 0:
		var state := "" if sim.upgrades.powered else " Сейчас всё отключено — счёт не оплачен."
		box.add_child(PhoneKit.label("Счёт за установленное: %s в день.%s" % [UiText.money(daily), state], PhoneKit.SMALL_SIZE, PhoneKit.MUTED if sim.upgrades.powered else PhoneKit.WARNING))
	for upgrade: UpgradeDef in catalogue:
		_add_upgrade(box, upgrade, sim, phone)


static func _add_upgrade(box: VBoxContainer, upgrade: UpgradeDef, sim: SimState, phone: Phone) -> void:
	var upgrades := sim.upgrades
	var sale := upgrades.on_sale(upgrade.id)
	var card := PhoneKit.card(box, PhoneKit.GOLD if sale else PhoneKit.CARD)
	var price := upgrades.price_of(upgrade.id)
	PhoneKit.heading(card, upgrade.display_name, UiText.money(price))
	if sale:
		card.add_child(PhoneKit.label("Б/у по наводке Вивьен: вместо %s, только до %s." % [UiText.money(upgrade.price), PhoneNews.time_of_day(upgrades.sale_until)], PhoneKit.SMALL_SIZE, PhoneKit.GOLD))
	card.add_child(PhoneKit.label(upgrade.description, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	card.add_child(PhoneKit.label("Содержание: %s в день." % UiText.money(upgrade.daily_cost), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	if upgrades.has(upgrade.id):
		card.add_child(PhoneKit.label("Установлено.", PhoneKit.SMALL_SIZE, PhoneKit.GOOD))
		return
	if upgrades.on_order.has(upgrade.id):
		card.add_child(PhoneKit.label("Едет — %s." % EconText.delivery_when(upgrades.on_order[upgrade.id], sim), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		return
	var refused := upgrades.refusal(upgrade.id)
	match refused:
		CommandResult.UPGRADE_LOCKED:
			card.add_child(PhoneKit.label(_unlock_text(upgrade, sim), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		CommandResult.NEEDS_UPGRADE:
			card.add_child(PhoneKit.label("Сначала — «%s»." % EconText.upgrade_name(upgrade.requires, sim), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		"":
			card.add_child(PhoneKit.secondary("Заказать — %s" % UiText.money(price), phone.buy_upgrade.bind(upgrade.id), sim.economy.money >= price))


static func _unlock_text(upgrade: UpgradeDef, sim: SimState) -> String:
	var milestones := sim.config.milestones
	if upgrade.level <= 0 or upgrade.level > milestones.size():
		return "Пока не продают."
	var milestone := milestones[upgrade.level - 1]
	return "Продадут на уровне «%s» (%s)." % [milestone.title, UiText.money(milestone.value)]
