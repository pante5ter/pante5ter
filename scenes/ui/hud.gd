class_name Hud
extends CanvasLayer

const MESSAGE_SECONDS: float = 4.0
const MESSAGE_FADE_SECONDS: float = 0.6
const HOVER_OFFSET: Vector2 = Vector2(18.0, 14.0)
const MAX_NEWS_LINES: int = 3

@export var money_label: Label
@export var time_label: Label
@export var stock_label: Label
@export var worker_label: Label
@export var objective_label: Label
@export var empire_label: Label
@export var suspicion_label: Label
@export var message_label: Label
@export var hover_label: Label

var action_menu: ActionMenu
var phone: Phone
var pause_menu: PauseMenu

var _message_left: float = 0.0
var _watched_sim: SimState
var _seen_events: int = 0


func _ready() -> void:
	message_label.modulate.a = 0.0
	hover_label.visible = false
	_add_corner_button("Телефон  [Tab]", toggle_phone, Vector2(1.0, 1.0), Rect2(-190.0, -60.0, 176.0, 44.0))
	_add_corner_button("Меню  [Esc]", toggle_pause, Vector2(1.0, 0.0), Rect2(-150.0, 12.0, 136.0, 36.0))
	phone = Phone.new()
	phone.message.connect(show_message)
	add_child(phone)
	action_menu = ActionMenu.new()
	add_child(action_menu)
	pause_menu = PauseMenu.new()
	pause_menu.message.connect(show_message)
	add_child(pause_menu)


func _add_corner_button(text: String, on_pressed: Callable, anchor: Vector2, rect: Rect2) -> void:
	var button := UiStyle.button(text, on_pressed)
	button.anchor_left = anchor.x
	button.anchor_right = anchor.x
	button.anchor_top = anchor.y
	button.anchor_bottom = anchor.y
	button.offset_left = rect.position.x
	button.offset_top = rect.position.y
	button.offset_right = rect.end.x
	button.offset_bottom = rect.end.y
	add_child(button)


func _process(delta: float) -> void:
	var sim := Game.sim
	money_label.text = UiText.money(sim.economy.money)
	time_label.text = UiText.clock(sim.clock)
	stock_label.text = "Урожай на руках: %d шт." % sim.inventory.count()
	worker_label.text = UiText.worker_status(sim.workers)
	objective_label.text = "Цель: " + UiText.objective(sim)
	empire_label.text = UiText.empire(sim)
	suspicion_label.text = UiText.suspicion(sim)
	suspicion_label.modulate = Color(1.0, 0.55, 0.45) if sim.suspicion.inspection_pending() or sim.raids.pending else Color.WHITE
	_announce_new_events(sim)
	_message_left = maxf(_message_left - delta, 0.0)
	message_label.modulate.a = clampf(_message_left / MESSAGE_FADE_SECONDS, 0.0, 1.0)
	if hover_label.visible:
		hover_label.position = hover_label.get_viewport().get_mouse_position() + HOVER_OFFSET


func _announce_new_events(sim: SimState) -> void:
	if sim != _watched_sim:
		_watched_sim = sim
		_seen_events = sim.event_log.size()
		return
	var news := PackedStringArray()
	for event: SimEvent in sim.event_log.since(_seen_events):
		var text := UiText.announcement(event, sim)
		if not text.is_empty() and not news.has(text):
			news.append(text)
	_seen_events = sim.event_log.size()
	if not news.is_empty():
		show_message("\n".join(news.slice(maxi(news.size() - MAX_NEWS_LINES, 0))))


func show_message(text: String) -> void:
	message_label.text = text
	_message_left = MESSAGE_SECONDS


func set_hover(text: String) -> void:
	var blocked := action_menu.visible or phone.visible or pause_menu.visible
	hover_label.text = text
	hover_label.visible = not text.is_empty() and not blocked


func show_actions(title: String, actions: Array[UiAction]) -> void:
	action_menu.open(title, actions, hover_label.get_viewport().get_mouse_position())


func close_actions() -> void:
	action_menu.close()


func is_blocking_world() -> bool:
	return action_menu.visible or pause_menu.visible


func toggle_phone() -> void:
	action_menu.close()
	phone.toggle()


func toggle_pause() -> void:
	action_menu.close()
	phone.close()
	pause_menu.toggle()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_TAB:
			toggle_phone()
		KEY_ESCAPE:
			if action_menu.visible:
				action_menu.close()
			elif phone.visible:
				phone.close()
			else:
				toggle_pause()
		KEY_F5:
			show_message("Игра сохранена." if Game.save_game() == OK else "Не удалось сохранить игру.")
		KEY_F9:
			show_message("Игра загружена." if Game.load_game() == OK else "Сохранения нет или оно повреждено.")
		_:
			return
	get_viewport().set_input_as_handled()
