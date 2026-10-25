class_name PhoneCalls
extends RefCounted


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var now := sim.clock.elapsed_game_seconds
	var calls := sim.orders.with_status(Order.Status.OFFERED)
	if calls.is_empty():
		box.add_child(PhoneKit.label("Тихо. Клиенты звонят сами — телефон пискнет.", PhoneKit.BODY_SIZE, PhoneKit.MUTED))
	for order: Order in calls:
		var card := PhoneKit.card(box, PhoneKit.DANGER if order.urgent else Phone.APP_COLORS[Phone.APP_CALLS])
		PhoneKit.heading(card, "%sКлиент%s: %d шт." % ["Срочно! " if order.urgent else "", UiText.order_kind(order.kind), order.quantity], UiText.money(order.reward))
		var strain := sim.config.find_strain(order.strain_id) if not order.strain_id.is_empty() else null
		var wants := "Сорт «%s» · качество от %d" % [strain.display_name, order.min_quality] if strain != null else "Качество от %d" % order.min_quality
		card.add_child(PhoneKit.label("%s · повесит трубку через %s" % [wants, UiText.real_duration(order.answer_by - now, sim)], PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
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
