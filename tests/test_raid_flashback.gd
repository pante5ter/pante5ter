extends GutTest

## A robbery Jack missed: Reggie's call, the flashback as one of the gang, and back — with the sim untouched.

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const HOME_SCENE: String = "res://scenes/home/home.tscn"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)
const CRATES: int = 3

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	_calm_game()
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	for node: Node in get_tree().root.get_children():
		if node is RaidFlashback:
			node.queue_free()
	Game.is_running = false
	get_tree().root.size = _old_screen
	Game.new_game(42)


func _calm_game() -> void:
	var config := (load("res://content/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.raids = config.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.problems = config.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.starting_money = 1000
	config.first_day = null
	config.director = null
	config.helper = null
	Game.sim = SimState.new(config, 42)


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


## The real thing: crates by the lift, the gang at the door, nobody answers before the deadline.
func _rob_the_farm() -> void:
	var sim := Game.sim
	for index: int in CRATES:
		sim.inventory.create(sim.config.strain.id, 60)
	sim.raids.pending = true
	sim.raids.deadline = sim.clock.elapsed_game_seconds + 60.0
	sim.apply(AdvanceTimeCommand.new(0.1 * sim.config.real_seconds_per_game_day / 24.0))
	assert_not_null(Raids.last_unattended_robbery_since(sim.event_log, 0), "the gang took the crates")


func _robbery(outcome: String, taken: int, at_hour: float = 4.0) -> SimEvent:
	var event := SimEvent.new()
	event.type = EventLog.RAID_RESOLVED
	event.game_time = SimClock.GAME_SECONDS_PER_DAY + at_hour * SimClock.GAME_SECONDS_PER_HOUR
	event.data = {"outcome": outcome, "taken": taken}
	return event


func _wait_for_call(level: Level) -> void:
	await wait_until(func() -> bool: return level.hud.raid_recap.stage == RaidRecap.Stage.CALLING, 3.0)


func _ask(level: Level) -> RaidFlashback:
	var box := level.hud.dialogue_box
	box.skip()
	assert_true(box.is_choosing())
	box.choose(RaidRecapText.ASK)
	box.skip()
	return level.hud.raid_recap.flashback


func _wait_for_closing(level: Level) -> void:
	await wait_until(func() -> bool: return level.hud.raid_recap.stage == RaidRecap.Stage.CLOSING and level.hud.is_dialogue_open(), 5.0)


# --- the sim's read-only questions

func test_only_robberies_behind_jacks_back_count() -> void:
	assert_true(Raids.is_unattended_robbery(_robbery("ignored", 2)))
	assert_true(Raids.is_unattended_robbery(_robbery("helper_failed", 1)))
	assert_false(Raids.is_unattended_robbery(_robbery("ignored", 0)), "nothing to take, nothing to tell")
	assert_false(Raids.is_unattended_robbery(_robbery("gave", 2)), "Jack handed them over himself")
	assert_false(Raids.is_unattended_robbery(_robbery("chase_failed", 2)), "Jack was there")
	assert_false(Raids.is_unattended_robbery(_robbery("paid", 0)))
	assert_false(Raids.is_unattended_robbery(null))
	var started := _robbery("ignored", 2)
	started.type = EventLog.RAID_STARTED
	assert_false(Raids.is_unattended_robbery(started))
	assert_eq(Raids.crates_taken(_robbery("ignored", 5)), 5)


func test_the_last_robbery_since_a_point_in_the_log() -> void:
	var log := EventLog.new()
	assert_null(Raids.last_unattended_robbery_since(log, 0))
	log.record(EventLog.RAID_RESOLVED, 10.0, PackedStringArray(), {"outcome": "ignored", "taken": 2})
	log.record(EventLog.RAID_RESOLVED, 20.0, PackedStringArray(), {"outcome": "paid", "paid": 200})
	log.record(EventLog.RAID_RESOLVED, 30.0, PackedStringArray(), {"outcome": "helper_failed", "taken": 4})
	assert_eq(Raids.crates_taken(Raids.last_unattended_robbery_since(log, 0)), 4)
	assert_null(Raids.last_unattended_robbery_since(log, 3))
	assert_eq(Raids.last_unattended_robbery_since(log, 0).game_time, 30.0)


func test_an_unanswered_raid_in_the_sim_is_a_robbery_with_its_crates() -> void:
	var sim := Game.sim
	for index: int in CRATES:
		sim.inventory.create(sim.config.strain.id, 60)
	sim.raids.pending = true
	sim.raids.deadline = sim.clock.elapsed_game_seconds + 60.0
	var before := sim.to_dict()
	var robbery := Raids.last_unattended_robbery_since(sim.event_log, 0)
	assert_null(robbery)
	assert_eq(sim.to_dict(), before, "asking changes nothing")
	sim.apply(AdvanceTimeCommand.new(0.1 * sim.config.real_seconds_per_game_day / 24.0))
	robbery = Raids.last_unattended_robbery_since(sim.event_log, 0)
	assert_not_null(robbery)
	assert_eq(Raids.crates_taken(robbery), CRATES)


# --- texts

func test_the_caption_and_the_call_tell_when_and_how_much() -> void:
	var robbery := _robbery("ignored", 3, 4.0)
	assert_eq(RaidRecapText.caption(robbery), "Той ночью, 04:00. «Молочные зубы».")
	var call := RaidRecapText.call_lines(robbery)
	assert_string_contains(call[1].text, "Мистер Кэллоуэй, ферму обнесли")
	assert_string_contains(call[2].text, "3 ящика")
	assert_eq(call[1].speaker, UiText.REGGIE)
	assert_eq(RaidRecapText.CALL_CHOICES[RaidRecapText.ASK], "Как это было?")
	assert_string_contains(RaidRecapText.caption(_robbery("ignored", 1, 14.5)), "Тем днём, 14:30")
	assert_eq(RaidRecapText.call_lines(_robbery("helper_failed", 1)).size(), call.size() + 1, "Reggie owns up to trying")


# --- the scenes

func test_reggie_calls_after_a_robbery_and_the_clock_stops() -> void:
	var level := await _open(HOME_SCENE)
	Game.is_running = true
	_rob_the_farm()
	await _wait_for_call(level)
	assert_true(level.hud.is_dialogue_open())
	assert_false(Game.is_running, "time waits for the call")
	level.hud.dialogue_box.skip()
	assert_eq(level.hud.dialogue_box.choice_buttons().size(), 2)


func test_a_paid_raid_brings_no_call() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.event_log.record(EventLog.RAID_RESOLVED, Game.sim.clock.elapsed_game_seconds, PackedStringArray([UiText.JACK]), {"outcome": "paid", "paid": 200})
	await wait_process_frames(5)
	assert_eq(level.hud.raid_recap.stage, RaidRecap.Stage.IDLE)
	assert_null(level.hud.raid_recap.flashback)


func test_the_flashback_plays_through_without_touching_the_sim() -> void:
	var level := await _open(FIELD_SCENE)
	Game.is_running = true
	_rob_the_farm()
	await _wait_for_call(level)
	var before := Game.sim.to_dict()
	var flashback := _ask(level)
	assert_not_null(flashback, "«Как это было?» cuts to the flashback")
	assert_eq(level.hud.raid_recap.stage, RaidRecap.Stage.FLASHBACK)
	assert_false(Game.is_running, "the clock stays stopped in the flashback")
	assert_eq(level.process_mode, Node.PROCESS_MODE_DISABLED, "Jack's scene waits behind it")
	assert_eq(flashback.total, CRATES, "as many crates as the sim says were taken")
	await wait_until(func() -> bool: return flashback.view.visible, 3.0)
	assert_string_contains(flashback.caption_label.text, "«Молочные зубы»")
	assert_false(level.visible, "one 3D world on screen at a time")
	await wait_until(func() -> bool: return flashback.is_playable(), 6.0)
	assert_true(flashback.subtitle_label.visible, "the gang films and talks")
	flashback.robber.speed = 200.0
	flashback.operator.speed = 200.0
	flashback.go_to_car()
	await wait_frames(5)
	assert_eq(flashback.phase, RaidFlashback.Phase.PLAYING, "no driving off before the crates are out")
	var trips := 0
	while flashback.carried < flashback.total and trips < 10:
		trips += 1
		var carried := flashback.carried
		flashback.go_to_container()
		await wait_until(func() -> bool: return flashback.carried > carried and flashback.is_playable(), 4.0)
	assert_eq(flashback.carried, CRATES)
	assert_true(flashback.container_entrance.is_open, "doors swung, the shelf slid: the clip's clue")
	flashback.go_to_car()
	await wait_until(func() -> bool: return flashback.phase == RaidFlashback.Phase.DRIVING, 3.0)
	await _wait_for_closing(level)
	assert_eq(Game.sim.to_dict(), before, "the flashback only replays what the sim decided")
	assert_false(Game.is_running, "still paused for Reggie's last word")
	assert_eq(level.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(level.visible)
	assert_eq(get_viewport().get_camera_3d(), level.camera_rig.camera, "back to Jack's view")
	level.hud.dialogue_box.skip()
	assert_eq(level.hud.raid_recap.stage, RaidRecap.Stage.IDLE)
	assert_true(Game.is_running, "the clock runs again as before the call")
	await wait_frames(30)
	assert_false(is_instance_valid(flashback), "the flashback is gone")


func test_the_flashback_can_be_skipped_with_the_button() -> void:
	var level := await _open(FIELD_SCENE)
	_rob_the_farm()
	await _wait_for_call(level)
	var before := Game.sim.to_dict()
	var flashback := _ask(level)
	await wait_until(func() -> bool: return flashback.skip_button.visible, 3.0)
	flashback.skip_button.pressed.emit()
	await _wait_for_closing(level)
	assert_eq(Game.sim.to_dict(), before)
	assert_eq(level.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_true(level.visible)
	level.hud.dialogue_box.skip()
	assert_false(Game.is_running, "the clock was stopped before the call and stays so")


func test_escape_skips_the_flashback() -> void:
	var level := await _open(HOME_SCENE)
	Game.is_running = true
	_rob_the_farm()
	await _wait_for_call(level)
	var before := Game.sim.to_dict()
	var flashback := _ask(level)
	await wait_until(func() -> bool: return flashback.view.visible, 3.0)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape)
	await _wait_for_closing(level)
	assert_false(level.hud.pause_menu.visible, "Esc skips, it does not open the menu")
	assert_eq(Game.sim.to_dict(), before)
	level.hud.dialogue_box.skip()
	assert_true(Game.is_running)
	assert_eq(level.place, DayCycle.HOME, "Jack is still where he was")


func test_no_details_skips_straight_to_reggies_last_word() -> void:
	var level := await _open(HOME_SCENE)
	Game.is_running = true
	_rob_the_farm()
	await _wait_for_call(level)
	var box := level.hud.dialogue_box
	box.skip()
	box.choose(RaidRecapText.NOT_NOW)
	assert_null(level.hud.raid_recap.flashback)
	assert_eq(level.hud.raid_recap.stage, RaidRecap.Stage.CLOSING)
	assert_false(Game.is_running)
	box.skip()
	assert_true(Game.is_running)
	await wait_process_frames(5)
	assert_eq(level.hud.raid_recap.stage, RaidRecap.Stage.IDLE, "one call per robbery")


func test_the_clip_story_waits_until_the_call_is_over() -> void:
	var level := await _open(HOME_SCENE)
	_rob_the_farm()
	await _wait_for_call(level)
	assert_eq(level.hud.raid_recap.stage, RaidRecap.Stage.CALLING, "Reggie's call comes first")
	assert_eq(level.hud.story_presenter.presenting(), "")
	var box := level.hud.dialogue_box
	box.skip()
	box.choose(RaidRecapText.NOT_NOW)
	box.skip()
	await wait_process_frames(3)
	assert_eq(level.hud.story_presenter.presenting(), "raid_clip", "then the clip and the shelf")
