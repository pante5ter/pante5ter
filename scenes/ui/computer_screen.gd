class_name ComputerScreen
extends PanelContainer

const REFRESH_SECONDS: float = 0.5
const SCREEN_SIZE: Vector2 = Vector2(620.0, 520.0)
const TAB_CALLS: int = 0
const TAB_ORDERS: int = 1
const TAB_COURIERS: int = 2
const TAB_FARM: int = 3

signal message(text: String)

var _tabs: TabContainer
var _calls: VBoxContainer
var _orders: VBoxContainer
var _couriers: VBoxContainer
var _farm: VBoxContainer
var _refresh_left: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiStyle.panel()
	style.bg_color = Color(0.05, 0.08, 0.07, 0.96)
	style.border_color = Color(0.3, 0.45, 0.35)
	style.set_border_width_all(3)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = SCREEN_SIZE
	var rows := VBoxContainer.new()
	add_child(rows)
	rows.add_child(UiStyle.label("Компьютер · ферма", 18, Color(0.6, 0.95, 0.7)))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	rows.add_child(_tabs)
	_calls = _add_tab("Звонки")
	_orders = _add_tab("Заказы")
	_couriers = _add_tab("Курьеры")
	_farm = _add_tab("Ферма")
	rows.add_child(UiStyle.button("Отойти от компьютера  [Esc]", close))


func _add_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_tabs.add_child(scroll)
	return content


func open(tab: int = -1) -> void:
	visible = true
	if tab >= 0:
		_tabs.current_tab = tab
	elif not Game.sim.orders.with_status(Order.Status.OFFERED).is_empty():
		_tabs.current_tab = TAB_CALLS
	refresh()
	position = (get_viewport_rect().size - SCREEN_SIZE) / 2.0


func close() -> void:
	visible = false


func current_tab() -> int:
	return _tabs.current_tab


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


func refresh() -> void:
	_refresh_left = REFRESH_SECONDS
	var sim := Game.sim
	_fill_calls(sim)
	_fill_orders(sim)
	_fill_couriers(sim)
	_fill_farm(sim)


func answer(order_id: int, choice: String) -> void:
	var result := Game.sim.apply(AnswerOrderCommand.new(order_id, choice))
	if not result.ok:
		message.emit(UiText.error(result.error))
	elif choice == Orders.ACCEPT:
		message.emit("Договорились. Заказ во вкладке «Заказы».")
	refresh()


func dispatch(order_id: int, courier_id: String) -> void:
	var result := Game.sim.apply(DispatchCommand.new(order_id, courier_id))
	if not result.ok:
		message.emit(UiText.error(result.error))
	elif courier_id == Couriers.JACK:
		message.emit("Джек сам повёз заказ. Вернётся через %s." % UiText.real_duration(Game.sim.couriers.trip_seconds(courier_id) * 1.5, Game.sim))
	else:
		message.emit("%s забрал коробки и уехал." % UiText.courier_name(courier_id, Game.sim))
	refresh()


func hire(courier_id: String) -> void:
	var result := Game.sim.apply(HireCourierCommand.new(courier_id))
	message.emit(("%s теперь возит товар." % UiText.courier_name(courier_id, Game.sim)) if result.ok else UiText.error(result.error))
	refresh()


func fire(courier_id: String) -> void:
	var result := Game.sim.apply(FireCourierCommand.new(courier_id))
	message.emit(("%s больше не работает на тебя." % UiText.courier_name(courier_id, Game.sim)) if result.ok else UiText.error(result.error))
	refresh()


func lie_low(on: bool) -> void:
	var result := Game.sim.apply(LieLowCommand.new(on))
	if not result.ok:
		message.emit(UiText.error(result.error))
	else:
		message.emit("Свет и вентиляция выключены. Растения и курьеры ждут." if on else "Лампы снова горят, ферма работает.")
	refresh()


func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _fill_calls(sim: SimState) -> void:
	_clear(_calls)
	var now := sim.clock.elapsed_game_seconds
	var calls := sim.orders.with_status(Order.Status.OFFERED)
	if calls.is_empty():
		_calls.add_child(UiStyle.label("Никто не звонит. Звонки приходят сами, следи за уведомлениями.", 15, UiStyle.MUTED))
	for order: Order in calls:
		var row := VBoxContainer.new()
		row.add_child(UiStyle.label("Клиенту нужно %d шт., качество от %d. Платит %s.\nПовесит трубку через %s." % [order.quantity, order.min_quality, UiText.money(order.reward), UiText.real_duration(order.answer_by - now, sim)]))
		var buttons := HBoxContainer.new()
		buttons.add_child(UiStyle.button("Принять", answer.bind(order.id, Orders.ACCEPT)))
		buttons.add_child(UiStyle.button("Торговаться (+%d%%, шанс %d%%)" % [roundi(sim.config.orders.haggle_bonus * 100.0), roundi(sim.config.orders.haggle_success * 100.0)], answer.bind(order.id, Orders.HAGGLE), not order.haggled))
		buttons.add_child(UiStyle.button("Отказать", answer.bind(order.id, Orders.DECLINE)))
		row.add_child(buttons)
		_calls.add_child(row)


func _fill_orders(sim: SimState) -> void:
	_clear(_orders)
	var now := sim.clock.elapsed_game_seconds
	var packed := 0
	for product: Product in sim.inventory.products():
		if product.packed:
			packed += 1
	_orders.add_child(UiStyle.label("На полке: %d коробок. Нефасованного урожая: %d." % [packed, sim.packing.unpacked_count()], 14, UiStyle.MUTED))
	var any := false
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		any = true
		var row := VBoxContainer.new()
		var can_ship := sim.orders.can_fill(order)
		row.add_child(UiStyle.label("Заказ #%d: %d шт., качество %d+, %s. Срок через %s.%s" % [order.id, order.quantity, order.min_quality, UiText.money(order.reward), UiText.real_duration(order.deadline - now, sim), "" if can_ship else "\nНе хватает фасованного товара нужного качества."]))
		var buttons := HBoxContainer.new()
		buttons.add_child(UiStyle.button("Отвезти самому", dispatch.bind(order.id, Couriers.JACK), can_ship and sim.couriers.is_free(Couriers.JACK, now) and not sim.suspicion.quiet))
		for courier_id: String in sim.couriers.hired:
			buttons.add_child(UiStyle.button("Отправить: %s" % UiText.courier_name(courier_id, sim), dispatch.bind(order.id, courier_id), can_ship and sim.couriers.is_free(courier_id, now) and not sim.suspicion.quiet))
		row.add_child(buttons)
		_orders.add_child(row)
	for order: Order in sim.orders.with_status(Order.Status.IN_TRANSIT):
		any = true
		_orders.add_child(UiStyle.label("Заказ #%d в дороге (%s), доставка через %s." % [order.id, UiText.courier_name(order.courier_id, sim), UiText.real_duration(order.arrives_at - now, sim)], 15, UiStyle.MUTED))
	if not any:
		_orders.add_child(UiStyle.label("Принятых заказов нет. Сначала ответь на звонок.", 15, UiStyle.MUTED))


func _fill_couriers(sim: SimState) -> void:
	_clear(_couriers)
	var now := sim.clock.elapsed_game_seconds
	_couriers.add_child(UiStyle.label("Риск в дороге растёт вместе с подозрением. Сам Джек — риск %d%%." % roundi(sim.couriers.trip_risk(Couriers.JACK) * 100.0), 14, UiStyle.MUTED))
	for courier: CourierDef in sim.config.courier_candidates:
		var row := VBoxContainer.new()
		var hired := sim.couriers.hired.has(courier.id)
		var status := ""
		if hired:
			status = " — в дороге" if not sim.couriers.is_free(courier.id, now) else " — свободен"
		row.add_child(UiStyle.label("%s%s\n%s\nБерёт %d%% с заказа, риск %d%%, скорость ×%.1f." % [courier.display_name, status, courier.description, roundi(courier.cut * 100.0), roundi(sim.couriers.trip_risk(courier.id) * 100.0), courier.speed]))
		if hired:
			row.add_child(UiStyle.button("Уволить", fire.bind(courier.id), sim.couriers.is_free(courier.id, now)))
		else:
			row.add_child(UiStyle.button("Нанять за %s" % UiText.money(courier.hire_fee), hire.bind(courier.id), sim.economy.money >= courier.hire_fee))
		_couriers.add_child(row)


func _fill_farm(sim: SimState) -> void:
	_clear(_farm)
	_farm.add_child(UiStyle.label(UiText.suspicion(sim), 16, UiStyle.ACCENT))
	_farm.add_child(UiStyle.label("Если едет проверка — затихни: лампы и вентиляция выключаются, растения не растут, работники отдыхают, курьеры сидят дома. Тихую ферму проверка не замечает.", 14, UiStyle.MUTED))
	if sim.suspicion.quiet:
		_farm.add_child(UiStyle.button("Вернуться к работе", lie_low.bind(false)))
	else:
		_farm.add_child(UiStyle.button("Затихнуть", lie_low.bind(true)))
