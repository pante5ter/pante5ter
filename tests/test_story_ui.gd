extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 4
const VIEWPORT_SIZE: Vector2i = Vector2i(1600, 900)


func before_each() -> void:
	Game.new_game(7)
	Game.is_running = false


func after_each() -> void:
	Game.set_speed(0)
	Game.is_running = false
	Game.new_game(7)


func _open(path: String) -> Level:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autoqfree(viewport)
	var level := (load(path) as PackedScene).instantiate() as Level
	viewport.add_child(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	return level


func _press_key(level: Level, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	level.get_viewport().push_input(key, true)
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	level.get_viewport().push_input(release, true)


func _lines(count: int) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = []
	for index: int in count:
		lines.append(DialogueLineDef.make("Финн", "Строка %d." % index))
	return lines


func _plain_state() -> SimState:
	var plain := (load(BALANCE_PATH) as BalanceConfig).duplicate() as BalanceConfig
	plain.first_day = null
	plain.director = null
	return SimState.new(plain, 1)


func test_choices_wait_on_the_last_line_and_cannot_be_skipped() -> void:
	var level := await _open(FIELD_SCENE)
	var box := level.hud.dialogue_box
	watch_signals(box)
	level.hud.play_dialogue(_lines(2), PackedStringArray(["Да", "Нет"]))
	assert_false(box.is_choosing())
	assert_eq(box.choice_buttons().size(), 0, "no buttons before the last line")
	_press_key(level, KEY_ESCAPE)
	assert_true(box.is_open(), "Esc does not skip past a choice")
	assert_true(box.is_choosing(), "Esc jumps to the choice")
	assert_eq(box.choice_buttons().size(), 2)
	_press_key(level, KEY_SPACE)
	assert_true(box.is_choosing(), "Space does not pass a choice")
	_press_key(level, KEY_2)
	assert_signal_emitted_with_parameters(box, "chosen", [1])
	box.choice_buttons()[0].pressed.emit()
	assert_signal_emitted_with_parameters(box, "chosen", [0])
	level.hud.play_dialogue(_lines(1))
	assert_false(box.is_choosing())
	_press_key(level, KEY_SPACE)
	assert_false(level.hud.is_dialogue_open())


func test_a_pending_story_plays_and_the_choice_reaches_the_sim() -> void:
	Game.sim.first_day.skip()
	var level := await _open(FIELD_SCENE)
	Game.is_running = true
	var story := Game.sim.stories.find("vicar_roof")
	Game.sim.stories.start(story, Game.sim.clock.elapsed_game_seconds, Director.ACTOR)
	await wait_process_frames(3)
	var hud := level.hud
	assert_true(hud.is_dialogue_open(), "the story opens by itself")
	assert_false(Game.is_running, "time stops while Jack decides")
	assert_eq(hud.dialogue_box.current_line().text, story.lines[0].text)
	hud.dialogue_box.skip()
	assert_eq(hud.dialogue_box.choice_buttons().size(), 2)
	var money := Game.sim.economy.money
	hud.dialogue_box.choice_buttons()[0].pressed.emit()
	assert_false(Game.sim.stories.is_pending())
	assert_eq(Game.sim.economy.money, money + story.choices[0].money)
	assert_true(hud.is_dialogue_open(), "the answer comes back as a reply")
	assert_eq(hud.dialogue_box.current_line().text, story.choices[0].reply[0].text)
	hud.dialogue_box.skip()
	await wait_process_frames(2)
	assert_false(hud.is_dialogue_open())
	assert_true(Game.is_running, "time runs again after the reply")


func test_a_refused_choice_keeps_the_question_open() -> void:
	Game.sim.first_day.skip()
	var level := await _open(FIELD_SCENE)
	Game.sim.economy.money = 0
	Game.sim.stories.start(Game.sim.stories.find("lord_advance"), 0.0, Director.ACTOR)
	await wait_process_frames(3)
	var box := level.hud.dialogue_box
	box.skip()
	box.choice_buttons()[0].pressed.emit()
	assert_true(Game.sim.stories.is_pending())
	assert_true(box.is_choosing(), "Finn explains and the options stay")
	assert_string_contains(box.current_line().text, "£500")


func test_hud_shows_the_crew_and_finn_knows_where_jack_is() -> void:
	var field := await _open(FIELD_SCENE)
	await wait_process_frames(2)
	assert_string_contains(field.hud.worker_label.text, "Реджи")
	assert_string_contains(field.hud.objective_label.text, "контейнер", "on the field Finn sends Jack down")
	field.queue_free()
	var bunker := await _open(PLANTATION_SCENE)
	await wait_process_frames(2)
	assert_true(bunker.hud.underground)
	assert_false(bunker.hud.objective_label.text.contains("контейнер"), "in the bunker Finn does not send Jack down again")
	assert_string_contains(bunker.hud.objective_label.text, "Посадите")


func test_crew_status_lists_everyone_on_the_payroll() -> void:
	var state := _plain_state()
	assert_string_contains(StoryText.crew_status(state), "Реджи")
	state.apply(HireWorkerCommand.new())
	var crew := StoryText.crew_status(state)
	assert_string_contains(crew, "Реджи")
	assert_string_contains(crew, state.workers.definition().display_name)
	state.config.helper = null
	var alone := SimState.new(state.config, 1)
	assert_eq(StoryText.crew_status(alone), "Работника нет", "with nobody hired the old line stays")


func test_everyday_objective_is_location_aware() -> void:
	var state := _plain_state()
	assert_string_contains(UiText.objective(state, false), "через контейнер")
	assert_false(UiText.objective(state, true).contains("контейнер"))
	assert_string_contains(UiText.objective(state, true), "Посадите")


func test_finn_follows_the_script_and_announces_director_news() -> void:
	var state := SimState.new(load(BALANCE_PATH) as BalanceConfig, 1)
	var def := state.config.first_day
	assert_eq(UiText.objective(state, false), def.plant_field_line)
	assert_eq(UiText.objective(state, true), def.plant_bunker_line)
	state.apply(PlantCommand.new(0))
	assert_eq(UiText.objective(state, true), def.call_line)
	var rumour := state.event_log.record(EventLog.DIRECTOR_EVENT, 0.0, PackedStringArray([Director.ACTOR]), {"kind": Director.RUMOUR, "about": Director.ABOUT_INSPECTION, "hours": 3.0})
	assert_string_contains(UiText.announcement(rumour, state), "проверка")
	var raid := state.event_log.record(EventLog.DIRECTOR_EVENT, 0.0, PackedStringArray([Director.ACTOR]), {"kind": Director.RUMOUR, "about": Director.ABOUT_RAID})
	assert_string_contains(UiText.announcement(raid, state), "гопники")
	var delay := state.event_log.record(EventLog.DIRECTOR_EVENT, 0.0, PackedStringArray([Director.ACTOR]), {"kind": Director.COURIER_TROUBLE, "courier_id": Helper.ACTOR, "order_id": 1, "hours": 1.0})
	assert_string_contains(UiText.announcement(delay, state), "Реджи")
	var urgent := state.event_log.record(EventLog.ORDER_RECEIVED, 0.0, PackedStringArray(["order:9"]), {"order_id": 9, "quantity": 2, "min_quality": 40, "reward": 400, "urgent": true})
	assert_string_contains(UiText.announcement(urgent, state), "Срочный")
