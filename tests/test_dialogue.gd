extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const PROLOGUE_PATH: String = "res://content/prologue.tres"
const TEST_SAVE_PATH: String = "user://test_dialogue_save.json"
const SETTLE_FRAMES: int = 4
const VIEWPORT_SIZE: Vector2i = Vector2i(1600, 900)


func before_each() -> void:
	Game.new_game(7)
	Game.is_running = false
	Game.save_path = TEST_SAVE_PATH


func after_each() -> void:
	Game.set_speed(0)
	Game.is_running = false
	Game.save_path = Game.DEFAULT_SAVE_PATH
	Game.new_game(7)
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)


## The headless root window is tiny and GUT's own output label covers it, so mouse
## events pushed there never reach the level; a full-size SubViewport has no such cover.
func _open(path: String) -> Level:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autoqfree(viewport)
	var level := (load(path) as PackedScene).instantiate() as Level
	viewport.add_child(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	return level


func _lines(count: int) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = []
	for index: int in count:
		lines.append(DialogueLineDef.make("Реджи", "Строка %d." % index))
	return lines


func _press_key(level: Level, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	level.get_viewport().push_input(key, true)
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	level.get_viewport().push_input(release, true)


func _push_click(level: Level, at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = at
		button.global_position = at
		level.get_viewport().push_input(button, true)


func _prologue_lines() -> Array[DialogueLineDef]:
	return (load(PROLOGUE_PATH) as DialogueDef).lines


func test_space_enter_and_click_advance_lines_then_finish() -> void:
	var level := await _open(FIELD_SCENE)
	watch_signals(level.hud)
	level.hud.play_dialogue(_lines(3))
	assert_true(level.hud.is_dialogue_open())
	assert_eq(level.hud.dialogue_box.current_line().text, "Строка 0.")
	_press_key(level, KEY_SPACE)
	assert_eq(level.hud.dialogue_box.line_index(), 1)
	_press_key(level, KEY_ENTER)
	assert_eq(level.hud.dialogue_box.line_index(), 2)
	assert_signal_not_emitted(level.hud, "dialogue_finished")
	_push_click(level, Vector2(800.0, 450.0))
	assert_false(level.hud.is_dialogue_open())
	assert_signal_emit_count(level.hud, "dialogue_finished", 1)


func test_escape_skips_the_whole_dialogue_without_opening_the_menu() -> void:
	var level := await _open(FIELD_SCENE)
	watch_signals(level.hud)
	level.hud.play_dialogue(_lines(5))
	_press_key(level, KEY_ESCAPE)
	assert_false(level.hud.is_dialogue_open())
	assert_signal_emit_count(level.hud, "dialogue_finished", 1)
	assert_false(level.hud.pause_menu.visible)


func test_hud_hotkeys_do_not_leak_while_open() -> void:
	var level := await _open(FIELD_SCENE)
	level.hud.play_dialogue(_lines(2))
	_press_key(level, KEY_TAB)
	_press_key(level, KEY_3)
	_press_key(level, KEY_2)
	_press_key(level, KEY_F5)
	assert_false(level.hud.phone.visible)
	assert_eq(Game.time_scale, Game.SPEEDS[0])
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_true(level.hud.is_dialogue_open())
	assert_eq(level.hud.dialogue_box.line_index(), 0)


func test_world_click_advances_the_line_but_does_not_walk_jack() -> void:
	var level := await _open(FIELD_SCENE)
	level.hud.play_dialogue(_lines(3))
	var start := level.jack.global_position
	var at := level.camera_rig.camera.unproject_position(start + Vector3(3.0, 0.0, 1.0))
	_push_click(level, at)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(level.jack.is_moving())
	assert_eq(level.jack.global_position, start)
	assert_eq(level.hud.dialogue_box.line_index(), 1)
	level.hud.dialogue_box.skip()
	_push_click(level, at)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(level.jack.is_moving(), "the same click walks Jack once the dialogue is closed")


func test_hud_chrome_hides_while_open_and_returns_after() -> void:
	var level := await _open(FIELD_SCENE)
	var stats := level.hud.money_label.get_parent().get_parent() as Control
	level.hud.play_dialogue(_lines(1))
	assert_false(stats.visible)
	assert_true(level.hud.dialogue_box.visible)
	level.hud.dialogue_box.skip()
	assert_true(stats.visible)


func test_sim_clock_stops_while_open_and_resumes_after() -> void:
	var level := await _open(FIELD_SCENE)
	Game.is_running = true
	level.hud.play_dialogue(_lines(2))
	var before := Game.sim.clock.elapsed_game_seconds
	await wait_process_frames(10)
	assert_eq(Game.sim.clock.elapsed_game_seconds, before)
	level.hud.dialogue_box.skip()
	assert_true(Game.is_running)
	await wait_process_frames(3)
	assert_gt(Game.sim.clock.elapsed_game_seconds, before)


func test_prologue_has_a_short_scene_with_jacks_offer() -> void:
	var lines := _prologue_lines()
	assert_between(lines.size(), 5, 7)
	var speakers := PackedStringArray()
	for line: DialogueLineDef in lines:
		assert_false(line.text.strip_edges().is_empty())
		speakers.append(line.speaker)
	assert_true(speakers.has("Джек"))
	assert_true(speakers.has("Реджи"))
	assert_true(speakers.has("Лорд Эшкомб"))
	assert_eq(lines[lines.size() - 1].speaker, "Реджи")
	assert_true(lines.any(func(line: DialogueLineDef) -> bool: return line.text.contains("Мне нужно только поле")))


func test_new_game_opens_the_field_with_the_prologue_once() -> void:
	Game.new_game(7, true)
	var level := await _open(FIELD_SCENE)
	assert_true(level.hud.is_dialogue_open())
	assert_eq(level.hud.dialogue_box.current_line().text, _prologue_lines()[0].text)
	assert_false(Game.is_running)
	level.hud.dialogue_box.skip()
	assert_true(Game.is_running)
	level.get_parent().queue_free()
	await wait_process_frames(2)
	var again := await _open(FIELD_SCENE)
	assert_false(again.hud.is_dialogue_open())


func test_loading_a_save_skips_the_prologue() -> void:
	assert_eq(Game.save_game(TEST_SAVE_PATH), OK)
	Game.new_game(7, true)
	assert_eq(Game.load_game(TEST_SAVE_PATH), OK)
	var level := await _open(FIELD_SCENE)
	assert_false(level.hud.is_dialogue_open())


func test_plain_new_game_and_other_levels_do_not_play_it() -> void:
	var field := await _open(FIELD_SCENE)
	assert_false(field.hud.is_dialogue_open())
	field.get_parent().queue_free()
	await wait_process_frames(2)
	Game.new_game(7, true)
	var plantation := await _open(PLANTATION_SCENE)
	assert_false(plantation.hud.is_dialogue_open())
