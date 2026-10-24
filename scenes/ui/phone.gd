class_name Phone
extends Panel

## Jack's phone: a home screen of apps; each app fills the screen and scrolls inside it.
## A Panel (not a container) on purpose: long app content can never stretch the phone.

signal message(text: String)

const REFRESH_SECONDS: float = 0.5
const PHONE_SIZE: Vector2 = Vector2(380.0, 640.0)
const SCREEN_INSET: Vector4 = Vector4(12.0, 18.0, 12.0, 16.0)

const HOME: int = -1
const APP_CALLS: int = 0
const APP_MESSAGES: int = 1
const APP_SHOP: int = 2
const APP_STOCK: int = 3
const APP_PEOPLE: int = 4
const APP_EMPIRE: int = 5
const APP_MAP: int = 6
const APP_TITLES: PackedStringArray = ["Звонки", "Финн", "Магазин", "Склад", "Люди", "Империя", "Карта"]
const APP_GLYPHS: PackedStringArray = [PhoneGlyphs.CALLS, PhoneGlyphs.MESSAGES, PhoneGlyphs.SHOP, PhoneGlyphs.STOCK, PhoneGlyphs.PEOPLE, PhoneGlyphs.EMPIRE, PhoneGlyphs.MAP]
## plant_mid, brass, container_red, oak, camel_coat, hazard_yellow, grass_light
const APP_COLORS: PackedColorArray = [Color("5A8A45"), Color("B08D4A"), Color("A14A35"), Color("7A5A3A"), Color("A88A62"), Color("C9A23A"), Color("7A8F5C")]

## Set by the HUD: Finn phrases directions from where Jack stands.
var underground: bool = false

var _app: int = HOME
var _home: PhoneHome
var _app_view: PhoneAppView
var _status: PhoneStatusBar
var _refresh_left: float = 0.0
var _news: PhoneNews = PhoneNews.new()
var _ringer: PhoneRinger


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = PHONE_SIZE
	size = PHONE_SIZE
	var body := PhoneKit.rounded(PhoneKit.BEZEL, 36, 0.0)
	body.border_color = PhoneKit.CARD
	body.set_border_width_all(2)
	add_theme_stylebox_override("panel", body)
	var speaker := ColorRect.new()
	speaker.color = PhoneKit.CARD
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker.position = Vector2((PHONE_SIZE.x - 56.0) / 2.0, 7.0)
	speaker.size = Vector2(56.0, 5.0)
	add_child(speaker)
	var screen := Panel.new()
	screen.name = "Screen"
	screen.clip_contents = true
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	screen.add_theme_stylebox_override("panel", PhoneKit.rounded(PhoneKit.SCREEN, 26, 0.0))
	screen.position = Vector2(SCREEN_INSET.x, SCREEN_INSET.y)
	screen.size = PHONE_SIZE - Vector2(SCREEN_INSET.x + SCREEN_INSET.z, SCREEN_INSET.y + SCREEN_INSET.w)
	add_child(screen)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_PASS
	rows.position = Vector2(12.0, 8.0)
	rows.size = screen.size - Vector2(24.0, 14.0)
	rows.add_theme_constant_override("separation", 6)
	screen.add_child(rows)
	_status = PhoneStatusBar.new()
	rows.add_child(_status)
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_PASS
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	rows.add_child(stage)
	_home = PhoneHome.new()
	_home.app_chosen.connect(open_app)
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_home)
	_app_view = PhoneAppView.new()
	_app_view.home_requested.connect(go_home)
	_app_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_app_view)
	var home_bar := Button.new()
	home_bar.name = "HomeBar"
	home_bar.focus_mode = Control.FOCUS_NONE
	home_bar.custom_minimum_size = Vector2(120.0, 16.0)
	home_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	home_bar.tooltip_text = "Домой (Esc), убрать телефон (Tab)"
	home_bar.add_theme_stylebox_override("normal", PhoneKit.rounded(PhoneKit.MUTED, 3, 0.0))
	home_bar.add_theme_stylebox_override("hover", PhoneKit.rounded(PhoneKit.TEXT, 3, 0.0))
	home_bar.pressed.connect(back)
	rows.add_child(home_bar)
	_ringer = PhoneRinger.new()
	add_child(_ringer)
	_show(HOME)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Opens on the home screen, or straight on the calls while a client is ringing.
func open(app: int = HOME) -> void:
	visible = true
	if app == HOME and not Game.sim.orders.with_status(Order.Status.OFFERED).is_empty():
		app = APP_CALLS
	_show(app)
	var screen := get_viewport_rect().size
	position = Vector2(screen.x - PHONE_SIZE.x - 24.0, maxf((screen.y - PHONE_SIZE.y) / 2.0, 12.0))


## A client is calling: the phone comes up on the calls by itself, buzzes and rings.
## An app the player is busy in stays open; the badge and the shake say enough.
func ring() -> void:
	if not visible:
		open(APP_CALLS)
	elif _app == HOME:
		open_app(APP_CALLS)
	_ringer.ring(self)


func is_ringing() -> bool:
	return _ringer.is_ringing()


func open_app(app: int) -> void:
	_show(app)


func go_home() -> void:
	_show(HOME)


## Esc and the home bar: an app goes back home, the home screen puts the phone away.
func back() -> void:
	if _app == HOME:
		close()
	else:
		go_home()


func close() -> void:
	visible = false
	_ringer.silence(self)


func current_app() -> int:
	return _app


func app_icon(app: int) -> PhoneAppIcon:
	return _home.icon(app)


func _show(app: int) -> void:
	_app = app
	_home.visible = app == HOME
	_app_view.visible = app != HOME
	if app != HOME:
		_app_view.show_app(APP_TITLES[app], APP_COLORS[app])
	if app == APP_MESSAGES:
		_news.mark_read()
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


func refresh() -> void:
	_refresh_left = REFRESH_SECONDS
	var sim := Game.sim
	_news.scan(sim)
	_status.refresh(sim)
	if _app == HOME:
		_home.refresh(sim, underground, _news.unread)
		return
	var fresh := VBoxContainer.new()
	match _app:
		APP_CALLS:
			PhoneCalls.fill(fresh, sim, self)
		APP_MESSAGES:
			_news.mark_read()
			_news.fill(fresh, sim, underground)
		APP_SHOP:
			PhoneShop.fill(fresh, sim, self)
		APP_STOCK:
			PhoneStock.fill(fresh, sim)
		APP_PEOPLE:
			PhonePeople.fill(fresh, sim, self)
		APP_EMPIRE:
			PhoneStock.fill_empire(fresh, sim)
		APP_MAP:
			PhoneMap.fill(fresh, sim)
	_app_view.fill(fresh)


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
		message.emit("Заказано за %s. Доставка в ящик у двери контейнера через %s." % [UiText.money(result.value), _delivery_time()])
	else:
		message.emit(UiText.error(result.error))
	refresh()


func restock() -> void:
	var result := Game.sim.apply(RestockCommand.new())
	if result.ok:
		message.emit("Запас пополнен на %s. Посылка будет у двери контейнера через %s." % [UiText.money(result.value), _delivery_time()])
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
