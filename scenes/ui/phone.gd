class_name Phone
extends PanelContainer

const REFRESH_SECONDS: float = 0.5
const PHONE_SIZE: Vector2 = Vector2(380.0, 640.0)
const TAB_SHOP: int = 0
const TAB_STOCK: int = 1
const TAB_EMPIRE: int = 2

signal message(text: String)

var _tabs: TabContainer
var _status: Label
var _notice: Label
var _shop: VBoxContainer
var _stock: VBoxContainer
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
	_shop = _add_tab("Магазин")
	_stock = _add_tab("Склад")
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
	_notice.text = ("Пропущенных звонков: %d — ответь на компьютере." % calls) if calls > 0 else ""
	_notice.visible = calls > 0
	_fill_shop(sim)
	_fill_stock(sim)
	_fill_empire(sim)


func buy(item: String, quantity: int) -> void:
	var result := Game.sim.apply(BuyCommand.new(item, quantity))
	if result.ok:
		message.emit("Заказано за %s. Доставка в ящик у контейнера через %s." % [UiText.money(result.value), UiText.real_duration(Game.sim.config.delivery_hours * SimClock.GAME_SECONDS_PER_HOUR, Game.sim)])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func buy_plot() -> void:
	var result := Game.sim.apply(BuyPlotCommand.new())
	message.emit("Новая грядка готова на плантации." if result.ok else UiText.error(result.error))
	refresh()


func _clear(box: VBoxContainer) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func _fill_shop(sim: SimState) -> void:
	_clear(_shop)
	var delivery := UiText.real_duration(sim.config.delivery_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)
	_shop.add_child(UiStyle.label("Доставка в ящик у контейнера через %s." % delivery, 13, UiStyle.MUTED))
	for strain: StrainDef in sim.config.extra_strains:
		var item := Supplies.seed_item(strain.id)
		if not sim.progress.is_strain_unlocked(strain.id):
			var unlock := sim.progress.unlocking_milestone(strain.id)
			_shop.add_child(UiStyle.label("Семена «%s» откроются на уровне «%s» (%s)." % [strain.display_name, unlock.title, UiText.money(unlock.value)], 15, UiStyle.MUTED))
			continue
		_add_shop_row("Семена «%s»: %s/шт.\nРастёт %s, качество около %d." % [strain.display_name, UiText.money(strain.seed_price), UiText.real_duration(strain.growth_hours() * SimClock.GAME_SECONDS_PER_HOUR, sim), strain.base_quality], item, strain.seed_price, sim)
	_add_shop_row("Удобрение: %s/шт.\n+%d к качеству одной грядки." % [UiText.money(sim.config.fertilizer_price), sim.config.fertilizer_bonus], Supplies.FERTILIZER, sim.config.fertilizer_price, sim)
	_add_shop_row("Средство от вредителей: %s/шт." % UiText.money(sim.config.problems.pesticide_price), Supplies.PESTICIDE, sim.config.problems.pesticide_price, sim)
	_add_shop_row("Запасная лампа: %s/шт." % UiText.money(sim.config.problems.lamp_price), Supplies.LAMP, sim.config.problems.lamp_price, sim)
	var beds := sim.grow.plots().size()
	var cap := sim.progress.plot_cap()
	var row := VBoxContainer.new()
	row.add_child(UiStyle.label("Новая грядка: %s (сейчас %d, можно до %d)." % [UiText.money(sim.config.plot_price), beds, cap]))
	row.add_child(UiStyle.button("Купить грядку", buy_plot, beds < cap and sim.economy.money >= sim.config.plot_price))
	_shop.add_child(row)
	var pending := sim.supplies.pending_deliveries()
	if not pending.is_empty():
		var lines := PackedStringArray(["В пути:"])
		for delivery_item: Dictionary in pending:
			lines.append("%s × %d — через %s" % [UiText.item_name(String(delivery_item["item"]), sim), int(delivery_item["quantity"]), UiText.real_duration(float(delivery_item["arrives_at"]) - sim.clock.elapsed_game_seconds, sim)])
		_shop.add_child(UiStyle.label("\n".join(lines), 13, UiStyle.MUTED))


func _add_shop_row(text: String, item: String, price: int, sim: SimState) -> void:
	var row := VBoxContainer.new()
	row.add_child(UiStyle.label(text))
	var buttons := HBoxContainer.new()
	buttons.add_child(UiStyle.button("Купить 1", buy.bind(item, 1), sim.economy.money >= price))
	buttons.add_child(UiStyle.button("Купить 5", buy.bind(item, 5), sim.economy.money >= price * 5))
	row.add_child(buttons)
	_shop.add_child(row)


func _fill_stock(sim: SimState) -> void:
	_clear(_stock)
	var products := sim.inventory.products()
	var qualities := PackedStringArray()
	for product: Product in products:
		qualities.append(str(product.quality))
	_stock.add_child(UiStyle.label("Урожай: %d шт.%s" % [products.size(), (" (качество: %s)" % ", ".join(qualities)) if not products.is_empty() else ""]))
	for strain: StrainDef in sim.config.extra_strains:
		_stock.add_child(UiStyle.label("Семена «%s»: %d" % [strain.display_name, sim.supplies.seeds(strain.id)]))
	_stock.add_child(UiStyle.label("«%s»: без ограничений" % sim.config.strain.display_name, 15, UiStyle.MUTED))
	_stock.add_child(UiStyle.label("Удобрение: %d" % sim.supplies.fertilizer))
	for tool: String in Supplies.TOOLS:
		_stock.add_child(UiStyle.label("%s: %d" % [UiText.capitalized(UiText.item_name(tool, sim)), sim.supplies.count(tool)]))


func _fill_empire(sim: SimState) -> void:
	_clear(_empire)
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
