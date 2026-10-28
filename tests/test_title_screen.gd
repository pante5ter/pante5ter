extends GutTest

## Title splash: new game goes to the field with the prologue; continue needs a save.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const TEST_SAVE: String = "user://gut_title_save.json"


func before_each() -> void:
	Game.is_running = false
	Game.save_path = TEST_SAVE
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	Game.new_game(42)


func after_each() -> void:
	Game.is_running = false
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(TEST_SAVE)
	Game.save_path = Game.DEFAULT_SAVE_PATH
	Game.new_game(42)


func test_title_offers_new_game_continue_and_quit() -> void:
	var title := (load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen
	add_child_autoqfree(title)
	await wait_process_frames(2)
	assert_false(Game.is_running)
	assert_eq(_button(title, "Новая игра").size(), 1)
	assert_eq(_button(title, "Продолжить").size(), 1)
	assert_eq(_button(title, "Выйти").size(), 1)
	assert_true(_button(title, "Продолжить")[0].disabled, "no save yet")


func test_new_game_from_the_title_opens_the_field_with_the_prologue() -> void:
	var title := (load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen
	add_child_autoqfree(title)
	await wait_process_frames(1)
	title._new_game()
	await wait_until(func() -> bool: return not SceneRouter.is_busy(), 5.0)
	SceneRouter.take_spawn()
	var loaded := get_tree().current_scene as Level
	assert_not_null(loaded)
	assert_eq(loaded.scene_file_path, FIELD_SCENE)
	assert_true(loaded.hud.is_dialogue_open(), "prologue after a fresh start")
	await _free_loaded(loaded)


func test_continue_loads_the_save_and_follows_jack() -> void:
	Game.new_game(11)
	Game.sim.apply(TravelCommand.new(DayCycle.HOME))
	assert_eq(Game.save_game(TEST_SAVE), OK)
	Game.new_game(99)
	var title := (load(TITLE_SCENE) as PackedScene).instantiate() as TitleScreen
	add_child_autoqfree(title)
	await wait_process_frames(1)
	assert_false(_button(title, "Продолжить")[0].disabled)
	title._continue_game()
	await wait_until(func() -> bool: return not SceneRouter.is_busy(), 5.0)
	SceneRouter.take_spawn()
	var loaded := get_tree().current_scene as Level
	assert_not_null(loaded)
	assert_eq(loaded.place, DayCycle.HOME)
	assert_eq(Game.sim.day.place, DayCycle.HOME)
	await _free_loaded(loaded)


func _button(root: Node, text: String) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			found.append(node as Button)
	return found


func _free_loaded(loaded: Node) -> void:
	if loaded != null and is_instance_valid(loaded):
		loaded.queue_free()
		await wait_process_frames(1)
