extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const TEST_SETTINGS_PATH: String = "user://test_ui_settings.cfg"
const SETTLE_FRAMES: int = 3
const DRAG: Vector2 = Vector2(-300.0, 40.0)
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(5)
	Game.is_running = false
	Game.ui_settings_path = TEST_SETTINGS_PATH
	# Headless runs start with a tiny window; the phone needs a real screen to be dragged around.
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN
	_remove_settings()


func after_each() -> void:
	Game.is_running = false
	Game.ui_settings_path = Game.DEFAULT_UI_SETTINGS_PATH
	get_tree().root.size = _old_screen
	Game.new_game(5)
	_remove_settings()


func _remove_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(TEST_SETTINGS_PATH)


func _open() -> Level:
	var level := (load(FIELD_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _mouse(level: Level, at: Vector2, pressed: bool) -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at
	button.global_position = at
	level.get_viewport().push_input(button)


func _move(level: Level, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	level.get_viewport().push_input(motion)


## The phone's top margin is plain panel, so grabbing it drags the whole phone.
func _drag_phone(level: Level, offset: Vector2) -> void:
	var phone := level.hud.phone
	var grab := phone.global_position + Vector2(phone.size.x / 2.0, 6.0)
	_mouse(level, grab, true)
	await wait_process_frames(1)
	_move(level, grab + offset / 2.0)
	_move(level, grab + offset)
	await wait_process_frames(1)
	_mouse(level, grab + offset, false)
	await wait_process_frames(2)


func test_phone_can_be_dragged_and_keeps_its_place() -> void:
	var level := await _open()
	level.hud.toggle_phone()
	await wait_process_frames(2)
	var start := level.hud.phone.global_position
	await _drag_phone(level, DRAG)
	var moved := level.hud.phone.global_position
	assert_almost_eq(moved.x, start.x + DRAG.x, 1.0)
	assert_almost_eq(moved.y, start.y + DRAG.y, 1.0)
	level.hud.toggle_phone()
	level.hud.toggle_phone()
	await wait_process_frames(2)
	assert_almost_eq(level.hud.phone.global_position.x, moved.x, 1.0, "reopening keeps the dragged place")
	assert_true(FileAccess.file_exists(TEST_SETTINGS_PATH), "the place is remembered between runs")


func test_remembered_place_is_used_by_a_new_session() -> void:
	var first := await _open()
	first.hud.toggle_phone()
	await wait_process_frames(2)
	await _drag_phone(first, DRAG)
	var remembered := first.hud.phone.global_position
	first.queue_free()
	await wait_process_frames(2)
	var second := await _open()
	second.hud.toggle_phone()
	await wait_process_frames(2)
	assert_almost_eq(second.hud.phone.global_position.x, remembered.x, 1.0)
	assert_almost_eq(second.hud.phone.global_position.y, remembered.y, 1.0)


func test_phone_cannot_be_dragged_off_screen() -> void:
	var level := await _open()
	level.hud.toggle_phone()
	await wait_process_frames(2)
	await _drag_phone(level, Vector2(5000.0, 5000.0))
	var phone := level.hud.phone
	var screen := phone.get_viewport_rect().size
	assert_lte(phone.global_position.x + phone.size.x, screen.x + 1.0)
	assert_lte(phone.global_position.y + phone.size.y, screen.y + 1.0)


func test_dialogue_speakers_have_their_own_colours() -> void:
	var level := await _open()
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.LORD, "a"), DialogueLineDef.make(UiText.FINN, "b")]
	level.hud.play_dialogue(lines)
	var box := level.hud.dialogue_box
	var lord_colour := box.speaker_label.get_theme_color("font_color")
	box.advance()
	assert_ne(box.speaker_label.get_theme_color("font_color"), lord_colour, "Finn and the lord must not look alike")
	assert_string_contains(box.speaker_label.text, UiText.FINN)
	box.skip()
