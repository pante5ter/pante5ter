class_name Hud
extends CanvasLayer

signal dialogue_finished
## The player wants the camera back on Jack; with follow it stays on him until they pan away.
signal jack_focus_requested(follow: bool)

const DIALOGUE_BOX_SCENE: PackedScene = preload("res://scenes/ui/dialogue_box.tscn")
const MESSAGE_SECONDS: float = 4.0
const MESSAGE_FADE_SECONDS: float = 0.6
const HOVER_OFFSET: Vector2 = Vector2(18.0, 14.0)
const MAX_NEWS_LINES: int = 3
## Bottom left, just above the speed buttons: where a map keeps its «back to me» button.
const JACK_BUTTON_RECT: Rect2 = Rect2(12.0, -128.0, 60.0, 60.0)

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
var computer: ComputerScreen
var dialogue_box: DialogueBox
var story_presenter: StoryPresenter
var alert_banner: AlertBanner
var edge_markers: EdgeMarkers
var jack_button: JackButton
var day_card: DayCard
## Set by the level: Finn phrases directions from where Jack stands.
var underground: bool = false
var speed_buttons: Array[Button] = []

var _message_left: float = 0.0
var _watched_sim: SimState
var _seen_events: int = 0
var _dialogue_was_running: bool = false
var _hidden_for_dialogue: Array[CanvasItem] = []


func _ready() -> void:
	message_label.modulate.a = 0.0
	hover_label.visible = false
	_add_corner_button("Телефон  [Tab]", toggle_phone, Vector2(1.0, 1.0), Rect2(-190.0, -60.0, 176.0, 44.0))
	_add_corner_button("Меню  [Esc]", toggle_pause, Vector2(1.0, 0.0), Rect2(-150.0, 12.0, 136.0, 36.0))
	jack_button = JackButton.new()
	jack_button.anchor_top = 1.0
	jack_button.anchor_bottom = 1.0
	jack_button.offset_left = JACK_BUTTON_RECT.position.x
	jack_button.offset_top = JACK_BUTTON_RECT.position.y
	jack_button.offset_right = JACK_BUTTON_RECT.end.x
	jack_button.offset_bottom = JACK_BUTTON_RECT.end.y
	jack_button.centre_requested.connect(jack_focus_requested.emit.bind(false))
	jack_button.follow_requested.connect(jack_focus_requested.emit.bind(true))
	add_child(jack_button)
	day_card = DayCard.new()
	day_card.hud = self
	add_child(day_card)
	edge_markers = EdgeMarkers.new()
	add_child(edge_markers)
	alert_banner = AlertBanner.new()
	alert_banner.action_requested.connect(_on_alert_action)
	add_child(alert_banner)
	phone = Phone.new()
	phone.message.connect(show_message)
	add_child(phone)
	var phone_drag := PanelDrag.new()
	phone_drag.settings_key = "phone"
	phone.add_child(phone_drag)
	action_menu = ActionMenu.new()
	add_child(action_menu)
	computer = ComputerScreen.new()
	computer.message.connect(show_message)
	add_child(computer)
	pause_menu = PauseMenu.new()
	pause_menu.message.connect(show_message)
	add_child(pause_menu)
	for index: int in Game.SPEEDS.size():
		var button := UiStyle.button("x%d" % roundi(Game.SPEEDS[index]), set_speed.bind(index))
		button.toggle_mode = true
		button.anchor_top = 1.0
		button.anchor_bottom = 1.0
		button.offset_left = 12.0 + 58.0 * float(index)
		button.offset_right = 64.0 + 58.0 * float(index)
		button.offset_top = -52.0
		button.offset_bottom = -16.0
		add_child(button)
		speed_buttons.append(button)
	dialogue_box = DIALOGUE_BOX_SCENE.instantiate() as DialogueBox
	dialogue_box.finished.connect(_on_dialogue_finished)
	add_child(dialogue_box)
	story_presenter = StoryPresenter.new()
	story_presenter.hud = self
	add_child(story_presenter)


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
	stock_label.text = UiText.stock(sim)
	worker_label.text = StoryText.crew_status(sim)
	objective_label.text = "Финн: " + UiText.objective(sim, underground)
	empire_label.text = UiText.empire(sim)
	suspicion_label.text = UiText.suspicion(sim)
	suspicion_label.modulate = Color(1.0, 0.55, 0.45) if sim.suspicion.inspection_pending() or sim.raids.pending else Color.WHITE
	phone.underground = underground
	_announce_new_events(sim)
	for index: int in speed_buttons.size():
		speed_buttons[index].set_pressed_no_signal(is_equal_approx(Game.time_scale, Game.SPEEDS[index]))
	_message_left = maxf(_message_left - delta, 0.0)
	message_label.modulate.a = clampf(_message_left / MESSAGE_FADE_SECONDS, 0.0, 1.0)
	if hover_label.visible:
		hover_label.position = hover_label.get_viewport().get_mouse_position() + HOVER_OFFSET


func _announce_new_events(sim: SimState) -> void:
	if sim != _watched_sim:
		_watched_sim = sim
		_seen_events = sim.event_log.size()
		alert_banner.clear()
		return
	var news := PackedStringArray()
	for event: SimEvent in sim.event_log.since(_seen_events):
		var alert := Alert.from_event(event, sim)
		if alert != null:
			alert_banner.push(alert)
			if alert.topic == Alert.CALL and not (dialogue_box.is_open() or computer.visible or pause_menu.visible):
				action_menu.close()
				phone.ring()
			continue
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
	var blocked := action_menu.visible or phone.visible or pause_menu.visible or computer.visible or dialogue_box.is_open()
	hover_label.text = text
	hover_label.visible = not text.is_empty() and not blocked


func show_actions(title: String, actions: Array[UiAction]) -> void:
	action_menu.open(title, actions, hover_label.get_viewport().get_mouse_position())


func close_actions() -> void:
	action_menu.close()


func is_blocking_world() -> bool:
	return action_menu.visible or pause_menu.visible or computer.visible or dialogue_box.is_open()


## With choices the box waits on the last line for one; its chosen signal carries the index.
func play_dialogue(lines: Array[DialogueLineDef], choices: PackedStringArray = PackedStringArray()) -> void:
	action_menu.close()
	phone.close()
	computer.close()
	pause_menu.close()
	if not dialogue_box.is_open():
		_dialogue_was_running = Game.is_running
		_hide_for_dialogue()
	Game.is_running = false
	dialogue_box.play(lines, choices)


func is_dialogue_open() -> bool:
	return dialogue_box.is_open()


func _hide_for_dialogue() -> void:
	for child: Node in get_children():
		var item := child as CanvasItem
		if item != null and item != dialogue_box and item.visible:
			item.visible = false
			_hidden_for_dialogue.append(item)


func _on_dialogue_finished() -> void:
	for item: CanvasItem in _hidden_for_dialogue:
		item.visible = true
	_hidden_for_dialogue.clear()
	Game.is_running = _dialogue_was_running
	dialogue_finished.emit()


func _dialogue_input(event: InputEvent) -> void:
	if dialogue_box.is_choosing():
		_choice_input(event)
		return
	var button := event as InputEventMouseButton
	if button != null:
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			dialogue_box.advance()
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			dialogue_box.advance()
		KEY_ESCAPE:
			dialogue_box.skip()
		KEY_TAB, KEY_1, KEY_2, KEY_3, KEY_F5, KEY_F9:
			pass
		_:
			return
	get_viewport().set_input_as_handled()


## Clicks go through to the choice buttons; the number keys pick too.
func _choice_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null:
		return
	if key.pressed and not key.echo and key.physical_keycode >= KEY_1 and key.physical_keycode <= KEY_9:
		dialogue_box.choose(key.physical_keycode - KEY_1)
	get_viewport().set_input_as_handled()


## A call opens the phone on it; anything with a place on the map swings the camera there.
func _on_alert_action(topic: String) -> void:
	if topic == Alert.CALL:
		action_menu.close()
		phone.open(Phone.APP_CALLS)
		return
	var target := AlertTarget.find_live(get_tree(), topic)
	var camera := get_viewport().get_camera_3d()
	var rig := camera.get_parent() as IsoCameraRig if camera != null else null
	if target != null and rig != null:
		rig.focus(target.global_position)


func open_computer() -> void:
	action_menu.close()
	phone.close()
	computer.open()


func set_speed(index: int) -> void:
	Game.set_speed(index)


func toggle_phone() -> void:
	action_menu.close()
	phone.toggle()


func toggle_pause() -> void:
	action_menu.close()
	phone.close()
	pause_menu.toggle()


func _input(event: InputEvent) -> void:
	if dialogue_box.is_open():
		_dialogue_input(event)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_TAB:
			toggle_phone()
		KEY_ESCAPE:
			if action_menu.visible:
				action_menu.close()
			elif computer.visible:
				computer.close()
			elif phone.visible:
				phone.back()
			else:
				toggle_pause()
		KEY_1, KEY_2, KEY_3:
			set_speed(key.physical_keycode - KEY_1)
		KEY_SPACE, KEY_HOME:
			jack_focus_requested.emit(false)
		KEY_F5:
			show_message("Игра сохранена." if Game.save_game() == OK else "Не удалось сохранить игру.")
		KEY_F9:
			show_message("Игра загружена." if Game.load_game() == OK else "Сохранения нет или оно повреждено.")
		_:
			return
	get_viewport().set_input_as_handled()
