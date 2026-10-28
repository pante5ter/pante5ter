extends GutTest

const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const TEST_SETTINGS_PATH: String = "user://test_phone_ui.cfg"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(11)
	Game.sim.first_day.skip()
	Game.is_running = false
	Game.ui_settings_path = TEST_SETTINGS_PATH
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	Game.is_running = false
	Game.ui_settings_path = Game.DEFAULT_UI_SETTINGS_PATH
	get_tree().root.size = _old_screen
	Game.new_game(11)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)


func _open(path: String = PLANTATION_SCENE) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _hours_to_real(hours: float) -> float:
	return hours * Game.sim.config.real_seconds_per_game_day / 24.0


func _ring() -> void:
	Game.sim.orders.inject(2, 50, 300, 6.0, 0.0, false, Game.sim.clock.elapsed_game_seconds)


func _deliver_parcel() -> void:
	Game.sim.economy.earn(1000)
	Game.sim.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	var arrives := Game.sim.supplies.arrival_for(Game.sim.clock.elapsed_game_seconds)
	var wait := (arrives - Game.sim.clock.elapsed_game_seconds) / SimClock.GAME_SECONDS_PER_HOUR + 0.1
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(wait)))


func _press_key(level: Level, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	level.get_viewport().push_input(key)


func _inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)


func test_phone_keeps_its_size_and_content_stays_on_its_screen_in_every_app() -> void:
	var level := await _open()
	Game.sim.economy.earn(100000)
	Game.sim.apply(HireWorkerCommand.new("dave"))
	_deliver_parcel()
	_ring()
	var phone := level.hud.phone
	phone.open()
	var screen := phone.get_node("Screen") as Control
	for app: int in range(Phone.HOME, Phone.APP_TITLES.size()):
		phone.open_app(app)
		await wait_process_frames(3)
		assert_eq(phone.size, Phone.PHONE_SIZE, "app %d must not stretch the phone" % app)
		assert_true(_inside(phone.get_global_rect(), screen.get_global_rect()), "the screen sits inside the body")
		for node: Node in screen.find_children("*", "ScrollContainer", true, false):
			var scroll := node as ScrollContainer
			if scroll.is_visible_in_tree():
				assert_true(_inside(screen.get_global_rect(), scroll.get_global_rect()), "app %d scrolls inside the screen" % app)


func test_reopened_phone_keeps_its_size() -> void:
	var level := await _open()
	var phone := level.hud.phone
	Game.sim.economy.earn(1000)
	level.hud.toggle_phone()
	phone.open_app(Phone.APP_SHOP)
	phone.buy(Supplies.FERTILIZER, 1)
	phone.open_app(Phone.APP_PEOPLE)
	await wait_process_frames(3)
	level.hud.toggle_phone()
	await wait_process_frames(3)
	level.hud.toggle_phone()
	await wait_process_frames(3)
	assert_true(phone.visible)
	assert_eq(phone.size, Phone.PHONE_SIZE, "reopening must not stretch the phone")
	assert_true(_inside(phone.get_viewport_rect(), phone.get_global_rect()), "the phone stays on screen")


func test_a_button_press_survives_the_screen_refresh() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.economy.earn(1000)
	var phone := level.hud.phone
	phone.open(Phone.APP_SHOP)
	await wait_process_frames(3)
	var quick := _buttons(phone, "Купить 1")[0]
	_click(level, quick.get_global_rect().get_center(), 0.0)
	await wait_process_frames(2)
	assert_eq(Game.sim.supplies.pending_deliveries().size(), 1, "a quick click buys (input reaches the phone)")
	var slow := _buttons(phone, "Купить 1")[0]
	var at := slow.get_global_rect().get_center()
	_mouse(level, at, true)
	await wait_seconds(Phone.REFRESH_SECONDS * 2.5)
	_mouse(level, at, false)
	await wait_process_frames(2)
	assert_eq(Game.sim.supplies.pending_deliveries().size(), 2, "a press held past a refresh still buys")


func _click(level: Level, at: Vector2, _hold: float) -> void:
	_mouse(level, at, true)
	_mouse(level, at, false)


func test_people_opened_by_the_helper_keeps_the_phone_size() -> void:
	var level := await _open()
	var talk := (level.get_node("Helper") as WorkerView).find_children("*", "WorkerTalk", true, false)[0] as WorkerTalk
	talk.interact(level)
	assert_true(level.hud.action_menu.choose_label("Открыть"))
	await wait_process_frames(3)
	assert_eq(level.hud.phone.current_app(), Phone.APP_PEOPLE)
	assert_eq(level.hud.phone.size, Phone.PHONE_SIZE)


func test_phone_opens_on_the_home_screen_and_apps_open_from_their_icons() -> void:
	var level := await _open()
	var phone := level.hud.phone
	level.hud.toggle_phone()
	assert_eq(phone.current_app(), Phone.HOME)
	phone.app_icon(Phone.APP_PEOPLE).pressed.emit()
	assert_eq(phone.current_app(), Phone.APP_PEOPLE)
	assert_gt(_buttons(phone, "Нанять").size(), 0, "the app shows its content")
	phone.back()
	assert_eq(phone.current_app(), Phone.HOME, "back from an app goes home")
	assert_true(phone.visible)
	phone.back()
	assert_false(phone.visible, "back on the home screen puts the phone away")


func test_escape_goes_home_first_and_then_puts_the_phone_away() -> void:
	var level := await _open()
	var phone := level.hud.phone
	phone.open(Phone.APP_SHOP)
	_press_key(level, KEY_ESCAPE)
	await wait_process_frames(1)
	assert_true(phone.visible)
	assert_eq(phone.current_app(), Phone.HOME)
	_press_key(level, KEY_ESCAPE)
	await wait_process_frames(1)
	assert_false(phone.visible)
	assert_false(level.hud.pause_menu.visible, "the same press does not also open the menu")


func test_badges_count_calls_and_the_waiting_parcel() -> void:
	var level := await _open()
	var phone := level.hud.phone
	phone.open()
	phone.go_home()
	assert_eq(phone.app_icon(Phone.APP_CALLS).badge, "")
	_deliver_parcel()
	_ring()
	phone.go_home()
	var ringing := Game.sim.orders.with_status(Order.Status.OFFERED).size()
	assert_gt(ringing, 0)
	assert_eq(phone.app_icon(Phone.APP_CALLS).badge, str(ringing))
	assert_eq(phone.app_icon(Phone.APP_STOCK).badge, "1", "a parcel is waiting at the container")
	phone.open_app(Phone.APP_STOCK)
	assert_gt(_labels(phone, "у двери контейнера").size(), 0, "the stock app says where the parcel is")


func test_reggie_badge_counts_unread_news_until_the_app_is_opened() -> void:
	var level := await _open()
	var phone := level.hud.phone
	phone.open()
	Game.sim.event_log.record(EventLog.PLOT_DRIED_OUT, 0.0, PackedStringArray(), {"plot_id": 0})
	Game.sim.event_log.record(EventLog.PLOT_DRIED_OUT, 0.0, PackedStringArray(), {"plot_id": 1})
	phone.refresh()
	assert_eq(phone.app_icon(Phone.APP_MESSAGES).badge, "2")
	phone.open_app(Phone.APP_MESSAGES)
	assert_gt(_labels(phone, "пересохла").size(), 0, "the news are listed")
	phone.go_home()
	assert_eq(phone.app_icon(Phone.APP_MESSAGES).badge, "")


func test_map_marks_the_parcel_and_the_drop_point() -> void:
	var level := await _open()
	_deliver_parcel()
	var titles := PhoneMap.spots(Game.sim).map(func(spot: PhoneMap.Spot) -> String: return spot.title)
	assert_has(titles, "Посылка")
	assert_has(titles, "Точка передачи")
	level.hud.phone.open(Phone.APP_MAP)
	assert_not_null(level.hud.phone.find_child("EstateMap", true, false))


func test_phone_can_still_be_dragged_by_its_status_bar() -> void:
	var level := await _open(FIELD_SCENE)
	var phone := level.hud.phone
	phone.open()
	await wait_process_frames(2)
	var start := phone.global_position
	var grab := start + Vector2(Phone.PHONE_SIZE.x / 2.0, 30.0)
	var drop := grab + Vector2(-100.0, 0.0)
	_mouse(level, grab, true)
	await wait_process_frames(1)
	var motion := InputEventMouseMotion.new()
	motion.position = drop
	motion.global_position = drop
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	level.get_viewport().push_input(motion)
	await wait_process_frames(1)
	_mouse(level, drop, false)
	await wait_process_frames(2)
	assert_almost_eq(phone.global_position.x, start.x - 100.0, 1.0)


func _mouse(level: Level, at: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.global_position = at
	level.get_viewport().push_input(button)


func _buttons(root: Node, prefix: String) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and button.text.begins_with(prefix):
			found.append(button)
	return found


func _labels(root: Node, part: String) -> Array[Label]:
	var found: Array[Label] = []
	for node: Node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.contains(part):
			found.append(label)
	return found


func test_an_incoming_call_brings_the_phone_up_ringing() -> void:
	var level := await _open(FIELD_SCENE)
	var phone := level.hud.phone
	assert_false(phone.visible)
	_ring()
	await wait_process_frames(2)
	assert_true(phone.visible, "the phone pops up by itself")
	assert_eq(phone.current_app(), Phone.APP_CALLS)
	assert_true(phone.is_ringing(), "it buzzes")
	assert_ne(phone.rotation, 0.0, "the shake is visible")
	phone.close()
	assert_false(phone.is_ringing())
	assert_eq(phone.rotation, 0.0)


func test_a_call_does_not_pull_the_player_out_of_another_app() -> void:
	var level := await _open(FIELD_SCENE)
	var phone := level.hud.phone
	phone.open(Phone.APP_SHOP)
	_ring()
	await wait_process_frames(2)
	assert_eq(phone.current_app(), Phone.APP_SHOP)
	assert_true(phone.is_ringing())
