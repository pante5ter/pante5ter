extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const SETTLE_FRAMES: int = 3
const AWAY: Vector3 = Vector3(14.0, 0.0, 9.0)
const GLIDE_TIMEOUT: float = 3.0


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()

	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(42)


func _open() -> Level:
	var level := (load(FIELD_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _off_camera(level: Level) -> float:
	return _flat(level.camera_rig.position).distance_to(_flat(level.jack.global_position))


func _press(keycode: Key) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = true
	get_viewport().push_input(key)


func _click_portrait(level: Level, double: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = double
	level.hud.jack_button.gui_input.emit(click)


func test_space_glides_the_camera_back_to_jack() -> void:
	var level := await _open()
	level.camera_rig.focus(level.jack.global_position + AWAY)
	var start := _off_camera(level)
	assert_gt(start, 10.0)
	_press(KEY_SPACE)
	await wait_process_frames(1)
	assert_true(level.camera_rig.is_gliding())
	assert_gt(_off_camera(level), 1.0, "a glide, not a jump cut")
	await wait_until(func() -> bool: return not level.camera_rig.is_gliding(), GLIDE_TIMEOUT)
	assert_lt(_off_camera(level), 0.05)


func test_home_and_the_portrait_do_the_same() -> void:
	var level := await _open()
	level.camera_rig.focus(level.jack.global_position + AWAY)
	_press(KEY_HOME)
	await wait_until(func() -> bool: return not level.camera_rig.is_gliding(), GLIDE_TIMEOUT)
	assert_lt(_off_camera(level), 0.05)
	level.camera_rig.focus(level.jack.global_position + AWAY)
	_click_portrait(level, false)
	assert_true(level.camera_rig.is_gliding())
	assert_false(level.camera_rig.is_following())
	await wait_until(func() -> bool: return not level.camera_rig.is_gliding(), GLIDE_TIMEOUT)
	assert_lt(_off_camera(level), 0.05)


func test_panning_takes_the_camera_back_from_the_glide() -> void:
	var level := await _open()
	level.camera_rig.focus(level.jack.global_position + AWAY)
	_press(KEY_SPACE)
	await wait_process_frames(1)
	level.camera_rig.drag(Vector2(40.0, 0.0))
	assert_false(level.camera_rig.is_gliding())
	var held := level.camera_rig.position
	await wait_process_frames(10)
	assert_almost_eq(level.camera_rig.position.distance_to(held), 0.0, 0.001)


func test_double_clicking_the_portrait_keeps_jack_in_frame_until_a_pan() -> void:
	var level := await _open()
	_click_portrait(level, true)
	assert_true(level.camera_rig.is_following())
	level.jack.global_position += Vector3(6.0, 0.0, 4.0)
	await wait_until(func() -> bool: return _off_camera(level) < 0.1, GLIDE_TIMEOUT)
	assert_lt(_off_camera(level), 0.1)
	assert_true(level.camera_rig.is_following(), "following does not end when it catches up")
	level.camera_rig.drag(Vector2(0.0, 40.0))
	assert_false(level.camera_rig.is_following())


func test_the_portrait_sits_on_the_hud() -> void:
	var level := await _open()
	assert_not_null(level.hud.jack_button)
	assert_true(level.hud.jack_button.visible)
	assert_true(level.hud.jack_button.tooltip_text.contains("Пробел"))
