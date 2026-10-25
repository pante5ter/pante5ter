class_name ComputerScreen
extends PanelContainer

const REFRESH_SECONDS: float = 0.5
const SCREEN_SIZE: Vector2 = Vector2(620.0, 520.0)
const TAB_ORDERS: int = 0
const TAB_COURIERS: int = 1
const TAB_FARM: int = 2
const TAB_SHOP: int = 3
const TAB_PEOPLE: int = 4

signal message(text: String)

## Set by the HUD: the shop and the people tabs are the phone's apps and act through it.
var phone: Phone

var _tabs: TabContainer
var _orders: VBoxContainer
var _couriers: VBoxContainer
var _farm: VBoxContainer
var _shop: VBoxContainer
var _people: VBoxContainer
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
	_orders = _add_tab("Заказы")
	_couriers = _add_tab("Курьеры")
	_farm = _add_tab("Ферма")
	_shop = _add_tab("Магазин")
	_people = _add_tab("Люди")
	if phone != null:
		phone.message.connect(_on_phone_action.unbind(1))
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
	elif not Game.sim.orders.with_status(Order.Status.ACCEPTED).is_empty():
		_tabs.current_tab = TAB_ORDERS
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
	UiRefresh.swap_if_changed(_orders, _fill_orders(sim))
	UiRefresh.swap_if_changed(_couriers, _fill_couriers(sim))
	UiRefresh.swap_if_changed(_farm, _fill_farm(sim))
	if phone != null:
		var shop := VBoxContainer.new()
		PhoneShop.fill(shop, sim, phone)
		UiRefresh.swap_if_changed(_shop, shop)
		var people := VBoxContainer.new()
		PhonePeople.fill(people, sim, phone)
		UiRefresh.swap_if_changed(_people, people)


func _on_phone_action() -> void:
	if visible:
		refresh()


func dispatch(order_id: int, courier_id: String) -> void:
	var result := Game.sim.apply(DispatchCommand.new(order_id, courier_id))
	if not result.ok:
		message.emit(UiText.error(result.error))
	else:
		message.emit("%s забрал коробки и уехал. Вернётся через %s." % [UiText.courier_name(courier_id, Game.sim), UiText.real_duration(Game.sim.couriers.trip_seconds(courier_id) * 1.5, Game.sim)])
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


## The dispatch buttons of one accepted order, as shown on the Orders tab.
func dispatch_buttons(order_id: int) -> Array[Button]:
	var found: Array[Button] = []
	for row: Node in _orders.get_children():
		if row.get_meta("order_id", -1) != order_id:
			continue
		for button: Node in row.find_children("*", "Button", true, false):
			found.append(button as Button)
	return found


static func _button(text: String, on_pressed: Callable, enabled: bool = true) -> Button:
	return UiRefresh.press_on_down(UiStyle.button(text, on_pressed, enabled))


func _fill_orders(sim: SimState) -> VBoxContainer:
	var box := VBoxContainer.new()
	var now := sim.clock.elapsed_game_seconds
	var packed := 0
	for product: Product in sim.inventory.products():
		if product.packed:
			packed += 1
	box.add_child(UiStyle.label("На полке: %d коробок. Нефасованного урожая: %d." % [packed, sim.packing.unpacked_count()], 14, UiStyle.MUTED))
	if sim.helper.exists() and not sim.helper.present():
		box.add_child(UiStyle.label(PeopleText.helper_status(sim) + ".", 14, UiStyle.MUTED))
	var any := false
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		any = true
		box.add_child(_order_row(order, sim, now))
	for order: Order in sim.orders.with_status(Order.Status.IN_TRANSIT):
		any = true
		box.add_child(UiStyle.label("Заказ #%d в дороге (%s), доставка через %s." % [order.id, UiText.courier_name(order.courier_id, sim), UiText.real_duration(order.arrives_at - now, sim)], 15, UiStyle.MUTED))
	if not any:
		box.add_child(UiStyle.label("Принятых заказов нет. Клиенты звонят на телефон (Tab, «Звонки»).", 15, UiStyle.MUTED))
	return box


func _order_row(order: Order, sim: SimState, now: float) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.set_meta("order_id", order.id)
	var matching := sim.orders.matching_products(order).size()
	var can_ship := sim.orders.can_fill(order)
	var strain := UiText.order_strain(order.strain_id, sim)
	var shortage := "" if can_ship else "\nПодходящих коробок %d из %d — нужен фасованный товар%s качества %d+." % [matching, order.quantity, strain, order.min_quality]
	row.add_child(UiStyle.label("Заказ #%d: %d шт.%s, качество %d+, %s. Срок: %s.%s" % [order.id, order.quantity, strain, order.min_quality, UiText.money(order.reward), UiText.due_by(order.deadline, sim), shortage]))
	var buttons := VBoxContainer.new()
	var free := sim.couriers.available_for(order, now)
	for courier_id: String in sim.couriers.drivers():
		var label := "Отправить: %s" % UiText.courier_name(courier_id, sim)
		var reason := "" if free.has(courier_id) else DispatchText.blocked_reason(order, courier_id, sim)
		if not reason.is_empty():
			label += " — " + reason
		var button := _button(label, dispatch.bind(order.id, courier_id), free.has(courier_id))
		button.tooltip_text = reason
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buttons.add_child(button)
	if buttons.get_child_count() == 0:
		row.add_child(UiStyle.label("Везти некому — наймите курьера во вкладке «Курьеры».", 13, UiStyle.MUTED))
	row.add_child(buttons)
	return row


func _fill_couriers(sim: SimState) -> VBoxContainer:
	var box := VBoxContainer.new()
	var now := sim.clock.elapsed_game_seconds
	var intro := "Риск в дороге растёт вместе с подозрением."
	if sim.helper.exists():
		intro += " %s возит бесплатно, риск %d%%, но пока он в дороге, ферма без него." % [sim.helper.definition().display_name, roundi(sim.couriers.trip_risk(Helper.ACTOR) * 100.0)]
	box.add_child(UiStyle.label(intro, 14, UiStyle.MUTED))
	box.add_child(UiStyle.label("Садовников и фасовщика нанимают во вкладке «Люди» — или в телефоне, Tab → «Люди».", 14, UiStyle.ACCENT))
	for courier: CourierDef in sim.config.courier_candidates:
		var row := VBoxContainer.new()
		var hired := sim.couriers.hired.has(courier.id)
		var status := ""
		if hired:
			status = " — в дороге" if not sim.couriers.is_free(courier.id, now) else " — свободен"
		row.add_child(UiStyle.label("%s%s\n%s\nБерёт %d%% с заказа, риск %d%%, скорость ×%.1f." % [courier.display_name, status, courier.description, roundi(courier.cut * 100.0), roundi(sim.couriers.trip_risk(courier.id) * 100.0), courier.speed]))
		if hired:
			row.add_child(_button("Уволить", fire.bind(courier.id), sim.couriers.is_free(courier.id, now)))
		else:
			row.add_child(_button("Нанять за %s" % UiText.money(courier.hire_fee), hire.bind(courier.id), sim.economy.money >= courier.hire_fee))
		box.add_child(row)
	return box


func _fill_farm(sim: SimState) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(UiStyle.label(UiText.suspicion(sim), 16, UiStyle.ACCENT))
	box.add_child(UiStyle.label("Если едет проверка — затихни: лампы и вентиляция выключаются, растения не растут, работники отдыхают, курьеры сидят дома. Тихую ферму проверка не замечает.", 14, UiStyle.MUTED))
	if sim.suspicion.quiet:
		box.add_child(_button("Вернуться к работе", lie_low.bind(false)))
	else:
		box.add_child(_button("Затихнуть", lie_low.bind(true)))
	return box
