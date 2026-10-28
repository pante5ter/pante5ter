extends GutTest

const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(31)
	Game.sim.first_day.skip()

	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	Game.is_running = false
	get_tree().root.size = _old_screen
	Game.new_game(31)


func _open() -> Level:
	var level := (load(PLANTATION_SCENE) as PackedScene).instantiate() as Level
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


func _button(screen: ComputerScreen, text: String) -> Button:
	for node: Node in screen.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and button.text.begins_with(text):
			return button
	return null


func test_fire_button_works_even_when_held_past_a_refresh() -> void:
	var level := await _open()
	Game.sim.economy.earn(5000)
	var couriers := Game.sim.config.courier_candidates
	Game.sim.apply(HireCourierCommand.new(couriers[0].id))
	Game.sim.apply(HireCourierCommand.new(couriers[1].id))
	var screen := level.hud.computer
	screen.open(ComputerScreen.TAB_COURIERS)
	await wait_process_frames(3)
	var quick := _button(screen, "Уволить").get_global_rect().get_center()
	_mouse(level, quick, true)
	_mouse(level, quick, false)
	await wait_process_frames(2)
	assert_eq(Game.sim.couriers.hired.size(), 1, "a quick click fires (input reaches the computer)")
	var slow := _button(screen, "Уволить").get_global_rect().get_center()
	_mouse(level, slow, true)
	await wait_seconds(ComputerScreen.REFRESH_SECONDS * 2.5)
	_mouse(level, slow, false)
	await wait_process_frames(2)
	assert_eq(Game.sim.couriers.hired.size(), 0, "a press held past a refresh still fires")
