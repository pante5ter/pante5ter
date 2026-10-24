class_name Phone
extends PanelContainer

const REFRESH_SECONDS: float = 0.5
const PHONE_SIZE: Vector2 = Vector2(380.0, 640.0)
const TAB_CALLS: int = 0
const TAB_SHOP: int = 1
const TAB_STOCK: int = 2
const TAB_PEOPLE: int = 3
const TAB_EMPIRE: int = 4

signal message(text: String)

var _tabs: TabContainer
var _status: Label
var _notice: Label
var _calls: VBoxContainer
var _shop: VBoxContainer
var _stock: VBoxContainer
var _people: VBoxContainer
var _empire: VBoxContainer
var _refresh_left: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.09, 0.09, 0.1, 0.98)
	body.border_color = Color(0.02, 0.02, 0.02)
	body.set_border_width_all(10)
	body.set_corner_radius_all(34)
	body.content_margin_left = 22.0
	body.content_margin_right = 22.0
	body.content_margin_top = 18.0
	body.content_margin_bottom = 26.0
	add_theme_stylebox_override("panel", body)
	custom_minimum_size = PHONE_SIZE
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)
	var speaker := ColorRect.new()
	speaker.color = Color(0.25, 0.25, 0.27)
	speaker.custom_minimum_size = Vector2(60.0, 6.0)
	speaker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(speaker)
	_status = UiStyle.label("", 13, UiStyle.MUTED)
	rows.add_child(_status)
	_notice = UiStyle.label("", 14, UiStyle.ACCENT)
	rows.add_child(_notice)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_NONE
	rows.add_child(_tabs)
	_calls = _add_tab("Звонки")
	_shop = _add_tab("Магазин")
	_stock = _add_tab("Склад")
	_people = _add_tab("Люди")
	_empire = _add_tab("Империя")
	var home := UiStyle.button("Убрать телефон  [Tab]", close)
	rows.add_child(home)


func _add_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_tabs.add_child(scroll)
	return content


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open(tab: int = -1) -> void:
	visible = true
	if tab >= 0:
		_tabs.current_tab = tab
	elif not Game.sim.orders.with_status(Order.Status.OFFERED).is_empty():
		_tabs.current_tab = TAB_CALLS
	refresh()
	var screen := get_viewport_rect().size
	position = Vector2(screen.x - PHONE_SIZE.x - 24.0, maxf((screen.y - PHONE_SIZE.y) / 2.0, 12.0))


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
	_status.text = "%s     %s" % [UiText.clock(sim.clock), UiText.money(sim.economy.money)]
	var calls := sim.orders.with_status(Order.Status.OFFERED).size()
	_notice.text = ("Звонит клиент! Звонков: %d — вкладка «Звонки»." % calls) if calls > 0 else ""
	_notice.visible = calls > 0
	_fill_calls(sim)
	PhoneShop.fill(_shop, sim, self)
	_fill_stock(sim)
	PhonePeople.fill(_people, sim, self)
	_fill_empire(sim)


func answer(order_id: int, choice: String) -> void:
	var result := Game.sim.apply(AnswerOrderCommand.new(order_id, choice))
	if not result.ok:
		message.emit(UiText.error(result.error))
	elif choice == Orders.ACCEPT:
		message.emit("Договорились. Отправить заказ — на компьютере на плантации, когда товар будет на полке.")
	refresh()


func buy(item: String, quantity: int) -> void:
	var result := Game.sim.apply(BuyCommand.new(item, quantity))
	if result.ok:
		message.emit("Заказано за %s. Доставка в ящик у контейнера через %s." % [UiText.money(result.value), _delivery_time()])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func restock() -> void:
	var result := Game.sim.apply(RestockCommand.new())
	if result.ok:
		message.emit("Запас пополнен на %s. Посылка у контейнера через %s." % [UiText.money(result.value), _delivery_time()])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func set_auto_reorder(item: String, keep: int) -> void:
	var result := Game.sim.apply(SetAutoReorderCommand.new(item, keep))
	if not result.ok:
		message.emit(UiText.error(result.error))
	elif keep > 0:
		message.emit("Финн будет держать %s: %d шт. Докупит сам, пока есть деньги." % [UiText.item_name(item, Game.sim), keep])
	else:
		message.emit("Автозаказ «%s» выключен." % UiText.item_name(item, Game.sim))
	refresh()


func buy_plot() -> void:
	var result := Game.sim.apply(BuyPlotCommand.new())
	message.emit("Новая грядка готова на плантации." if result.ok else UiText.error(result.error))
	refresh()


func hire(worker_id: String) -> void:
	var result := Game.sim.apply(HireWorkerCommand.new(worker_id))
	var person := _find_person(worker_id)
	if result.ok and person != null:
		message.emit("%s %s. Спустится на плантацию и возьмётся за дело." % [person.display_name, PeopleText.hired_word(person)])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func fire(worker_id: String) -> void:
	var result := Game.sim.apply(FireWorkerCommand.new(worker_id))
	var person := _find_person(worker_id)
	if result.ok and person != null:
		message.emit("%s %s." % [person.display_name, PeopleText.fired_word(person)])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func learn(skill_id: String) -> void:
	var result := Game.sim.apply(LearnSkillCommand.new(skill_id))
	if result.ok:
		message.emit("%s уехал учиться. Вернётся через %s." % [Game.sim.helper.definition().display_name, UiText.real_duration(Game.sim.helper.away_until - Game.sim.clock.elapsed_game_seconds, Game.sim)])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func _find_person(worker_id: String) -> WorkerDef:
	var packer := Game.sim.config.find_packer(worker_id)
	return packer if packer != null else Game.sim.config.find_worker(worker_id)


func _delivery_time() -> String:
	return UiText.real_duration(Game.sim.config.delivery_hours * SimClock.GAME_SECONDS_PER_HOUR, Game.sim)


static func clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _fill_calls(sim: SimState) -> void:
	clear(_calls)
	var now := sim.clock.elapsed_game_seconds
	var calls := sim.orders.with_status(Order.Status.OFFERED)
	if calls.is_empty():
		_calls.add_child(UiStyle.label("Тихо. Клиенты звонят сами — телефон пискнет.", 15, UiStyle.MUTED))
	for order: Order in calls:
		var row := VBoxContainer.new()
		row.add_child(UiStyle.label("Клиенту нужно %d шт., качество от %d. Платит %s.\nПовесит трубку через %s." % [order.quantity, order.min_quality, UiText.money(order.reward), UiText.real_duration(order.answer_by - now, sim)]))
		var buttons := HBoxContainer.new()
		buttons.add_child(UiStyle.button("Принять", answer.bind(order.id, Orders.ACCEPT)))
		buttons.add_child(UiStyle.button("Торг +%d%% (%d%%)" % [roundi(sim.config.orders.haggle_bonus * 100.0), roundi(sim.config.orders.haggle_success * 100.0)], answer.bind(order.id, Orders.HAGGLE), not order.haggled))
		buttons.add_child(UiStyle.button("Отказать", answer.bind(order.id, Orders.DECLINE)))
		row.add_child(buttons)
		_calls.add_child(row)
	var accepted := sim.orders.with_status(Order.Status.ACCEPTED).size()
	if accepted > 0:
		_calls.add_child(UiStyle.label("Принятых заказов: %d — отправляются с компьютера на плантации." % accepted, 13, UiStyle.MUTED))


func _fill_stock(sim: SimState) -> void:
	clear(_stock)
	var products := sim.inventory.products()
	var qualities := PackedStringArray()
	for product: Product in products:
		qualities.append(str(product.quality))
	_stock.add_child(UiStyle.label("Урожай: %d шт.%s" % [products.size(), (" (качество: %s)" % ", ".join(qualities)) if not products.is_empty() else ""]))
	_stock.add_child(UiStyle.label(UiText.stock(sim), 14, UiStyle.MUTED))
	for strain: StrainDef in sim.config.extra_strains:
		_stock.add_child(UiStyle.label("Семена «%s»: %d" % [strain.display_name, sim.supplies.seeds(strain.id)]))
	_stock.add_child(UiStyle.label("«%s»: без ограничений" % sim.config.strain.display_name, 15, UiStyle.MUTED))
	_stock.add_child(UiStyle.label("Удобрение: %d" % sim.supplies.fertilizer))
	for tool: String in Supplies.TOOLS:
		_stock.add_child(UiStyle.label("%s: %d" % [UiText.capitalized(UiText.item_name(tool, sim)), sim.supplies.count(tool)]))


func _fill_empire(sim: SimState) -> void:
	clear(_empire)
	_empire.add_child(UiStyle.label("Оценка империи: %s" % UiText.money(sim.empire_value()), 18, UiStyle.ACCENT))
	_empire.add_child(UiStyle.label("Деньги, грядки, товар на руках и в тайнике.", 13, UiStyle.MUTED))
	for index: int in sim.config.milestones.size():
		var milestone := sim.config.milestones[index]
		var mark := "[готово]" if index < sim.progress.reached else "[цель]"
		_empire.add_child(UiStyle.label("%s %s — «%s»\n%s" % [mark, UiText.money(milestone.value), milestone.title, milestone.description], 14, Color.WHITE if index < sim.progress.reached else UiStyle.MUTED))
	_add_rent(sim)
	_empire.add_child(UiStyle.label(UiText.suspicion(sim)))
	_empire.add_child(UiStyle.label("Подозрение растёт от заказов, болтливых работников и большой фермы. Проверку переживёшь, если вовремя замаскируешь вход.", 13, UiStyle.MUTED))


func _add_rent(sim: SimState) -> void:
	var rent := sim.rent
	if rent.amount() <= 0:
		return
	if rent.evicted:
		_empire.add_child(UiStyle.label("Лорд Эшкомб расторг аренду: поле больше не твоё.", 15, UiStyle.ACCENT))
		return
	var text := "Аренда лорду Эшкомбу: %s, следующий платёж через %s." % [UiText.money(rent.amount()), UiText.real_duration(rent.due_in(sim.clock.elapsed_game_seconds), sim)]
	if rent.missed > 0:
		text += "\nПропущено платежей подряд: %d из %d." % [rent.missed, rent.max_missed()]
	_empire.add_child(UiStyle.label(text, 15, UiStyle.ACCENT if rent.missed > 0 else Color.WHITE))
