class_name PhoneCalls
extends RefCounted


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var now := sim.clock.elapsed_game_seconds
	var calls := sim.orders.with_status(Order.Status.OFFERED)
	if calls.is_empty():
		box.add_child(PhoneKit.label("Тихо. Клиенты звонят сами — телефон пискнет.", PhoneKit.BODY_SIZE, PhoneKit.MUTED))
	for order: Order in calls:
		var card := PhoneKit.card(box, PhoneKit.DANGER if order.urgent else Phone.APP_COLORS[Phone.APP_CALLS])
		PhoneKit.heading(card, "%sКлиент: %d шт." % ["Срочно! " if order.urgent else "", order.quantity], UiText.money(order.reward))
		card.add_child(PhoneKit.label("Качество от %d · повесит трубку через %s" % [order.min_quality, UiText.real_duration(order.answer_by - now, sim)], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		card.add_child(PhoneKit.primary("Принять", phone.answer.bind(order.id, Orders.ACCEPT)))
		var haggle := "Торг +%d%% (шанс %d%%)" % [roundi(sim.config.orders.haggle_bonus * 100.0), roundi(sim.config.orders.haggle_success * 100.0)]
		var buttons: Array[Button] = [
			PhoneKit.secondary(haggle, phone.answer.bind(order.id, Orders.HAGGLE), not order.haggled),
			PhoneKit.secondary("Отказать", phone.answer.bind(order.id, Orders.DECLINE)),
		]
		PhoneKit.row(card, buttons)
	var accepted := sim.orders.with_status(Order.Status.ACCEPTED).size()
	if accepted > 0:
		var waiting := PhoneKit.card(box)
		PhoneKit.heading(waiting, "Принятые заказы", str(accepted))
		waiting.add_child(PhoneKit.label("Отправляются с компьютера на плантации, когда коробки на полке.", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
