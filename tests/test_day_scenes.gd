extends GutTest

## Home, the stash and the night in the scenes: travel, the bed, the summary and briefing cards,
## a night alarm, the crates in the bunker and watching the farm while Jack is away.

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const HOME_SCENE: String = "res://scenes/home/home.tscn"
const STASH_SCENE: String = "res://scenes/stash/stash.tscn"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


## No director or random trouble: a story popping up would cover the bed and the banner.
func before_each() -> void:
	_calm_game(0.0)
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	Game.is_running = false
	get_tree().root.size = _old_screen
	Game.new_game(42)


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


## A scene change started by the code under test: let it finish and drop the scene it loaded.
func _finish_route() -> Node:
	await wait_until(func() -> bool: return not SceneRouter.is_busy(), 5.0)
	SceneRouter.take_spawn()
	var loaded := get_tree().current_scene
	Game.is_running = false
	return loaded


func _free_loaded(loaded: Node) -> void:
	if loaded is Level and is_instance_valid(loaded):
		loaded.queue_free()
		await wait_process_frames(1)


func _go(place: String) -> void:
	assert_true(Game.sim.apply(TravelCommand.new(place)).ok)


func _advance_to_hour(hour: float) -> void:
	var sim := Game.sim
	var target := float(sim.clock.day()) * SimClock.GAME_SECONDS_PER_DAY + hour * SimClock.GAME_SECONDS_PER_HOUR
	if target <= sim.clock.elapsed_game_seconds:
		target += SimClock.GAME_SECONDS_PER_DAY
	while sim.clock.elapsed_game_seconds < target - 0.001:
		var hours := minf(0.25, (target - sim.clock.elapsed_game_seconds) / SimClock.GAME_SECONDS_PER_HOUR)
		sim.apply(AdvanceTimeCommand.new(hours * sim.config.real_seconds_per_game_day / 24.0))


func _calm_game(raid_chance: float) -> void:
	var config := (load("res://content/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	config.raids = config.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = raid_chance
	config.problems = config.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.starting_money = 1000
	config.first_day = null
	config.director = null
	Game.sim = SimState.new(config, 42)


func _raid_game() -> void:
	_calm_game(1.0)
	Game.sim.inventory.create(Game.sim.config.strain.id, 60)


func _buttons(root: Node, prefix: String) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with(prefix) and button.is_visible_in_tree():
			found.append(button)
	return found


# --- the places

func test_home_is_a_room_with_the_bed_vivienne_and_the_car() -> void:
	_go(DayCycle.HOME)
	var level := await _open(HOME_SCENE)
	assert_eq(level.place, DayCycle.HOME)
	assert_false(level.observing())
	assert_gt(level.nav_region.navigation_mesh.get_polygon_count(), 0)
	assert_not_null(level.get_node("NavRegion/Bed") as Bed)
	assert_not_null(level.get_node("NavRegion/Vivienne") as Vivienne)
	var car := level.get_node("NavRegion/Car") as TravelCar
	var labels := car.actions(level).map(func(action: UiAction) -> String: return action.label)
	assert_eq(labels.size(), 3, "the farm (container or manor) and the stash")
	assert_true(labels.any(func(label: String) -> bool: return label.contains("тайник")))
	await wait_physics_frames(2)
	assert_true(level.jack.visible)


func test_the_stash_holds_the_bench_the_shelf_the_computer_and_the_packer() -> void:
	_go(DayCycle.STASH)
	var level := await _open(STASH_SCENE)
	assert_eq(level.place, DayCycle.STASH)
	assert_not_null(level.get_node("NavRegion/Bench") as PackingBench)
	assert_not_null(level.get_node("NavRegion/Shelf/Stock") as StockShelf)
	assert_not_null(level.get_node("NavRegion/Computer") as ComputerDesk)
	var packer := level.get_node("Packer") as WorkerView
	await wait_physics_frames(2)
	assert_false(packer.visible, "no packer hired yet")
	Game.sim.economy.earn(1000)
	assert_true(Game.sim.apply(HireWorkerCommand.new("gladys")).ok)
	await wait_physics_frames(2)
	assert_true(packer.visible, "Gladys works at the stash")


func test_the_bunker_no_longer_has_a_bench_or_a_shelf() -> void:
	var level := await _open(PLANTATION_SCENE)
	assert_null(level.get_node_or_null("NavRegion/Bench"))
	assert_null(level.get_node_or_null("NavRegion/Shelf"))
	assert_not_null(level.get_node("NavRegion/Crates") as CrateStack)


func test_vivienne_has_a_word_for_the_hour() -> void:
	_go(DayCycle.HOME)
	var level := await _open(HOME_SCENE)
	(level.get_node("NavRegion/Vivienne") as Vivienne).interact(level)
	assert_true(level.hud.is_dialogue_open())
	assert_eq(Vivienne.lines(Game.sim)[0].speaker, UiText.VIVIENNE)


# --- crates

func test_crates_wait_in_the_bunker_and_reggie_drives_them_off() -> void:
	var level := await _open(PLANTATION_SCENE)
	var stack := level.get_node("NavRegion/Crates") as CrateStack
	for index: int in 3:
		Game.sim.inventory.create(Game.sim.config.strain.id, 60)
	await wait_process_frames(2)
	assert_eq(stack.shown_crates(), 3)
	stack.interact(level)
	assert_true(level.hud.action_menu.choose_label("Реджи отвезёт"))
	assert_true(Game.sim.stash.on_the_road())
	await wait_process_frames(2)
	assert_eq(stack.shown_crates(), 0)
	assert_string_contains(stack.count_label.text, "в пути")


func test_jack_can_drive_the_crates_himself_and_lands_at_the_stash() -> void:
	var level := await _open(PLANTATION_SCENE)
	var stack := level.get_node("NavRegion/Crates") as CrateStack
	Game.sim.inventory.create(Game.sim.config.strain.id, 60)
	stack.interact(level)
	assert_true(level.hud.action_menu.choose_label("Отвезти самому"))
	assert_eq(Game.sim.day.place, DayCycle.STASH)
	assert_eq(Game.sim.inventory.at_stash().size(), 1)
	assert_true(SceneRouter.is_busy(), "the view follows Jack")
	var loaded := await _finish_route()
	assert_eq((loaded as Level).place if loaded is Level else "", DayCycle.STASH)
	await _free_loaded(loaded)


# --- the night

func test_too_early_for_bed_says_so() -> void:
	_go(DayCycle.HOME)
	_advance_to_hour(12.0)
	var level := await _open(HOME_SCENE)
	(level.get_node("NavRegion/Bed") as Bed).interact(level)
	assert_false(level.hud.night.is_open())
	assert_string_contains(level.hud.message_label.text, "Рано")


func test_sleep_shows_the_day_then_the_morning_briefing() -> void:
	Game.sim.inventory.create(Game.sim.config.strain.id, 60)
	_go(DayCycle.HOME)
	_advance_to_hour(22.0)
	var level := await _open(HOME_SCENE)
	Game.is_running = true
	(level.get_node("NavRegion/Bed") as Bed).interact(level)
	var card := level.hud.night.card
	assert_true(level.hud.night.is_open())
	assert_false(Game.is_running, "time waits while the card is up")
	assert_eq(card.title_label.text, "День 1 окончен")
	assert_string_contains(card.body_text(), "Деньги")
	assert_almost_eq(Game.sim.clock.hour_of_day(), Game.sim.config.day.wake_hour, 0.001)
	card.next_pressed.emit()
	assert_string_contains(card.title_label.text, "Утро")
	assert_string_contains(card.body_text(), "За ночь")
	assert_string_contains(card.body_text(), "На ферме 1 ящик", "the briefing remembers the crate at the farm")
	card.next_pressed.emit()
	assert_false(level.hud.night.is_open())
	assert_true(Game.is_running)


func test_a_night_raid_wakes_jack_and_reggie_asks_what_to_do() -> void:
	_raid_game()
	_go(DayCycle.HOME)
	_advance_to_hour(22.0)
	var level := await _open(HOME_SCENE)
	(level.get_node("NavRegion/Bed") as Bed).interact(level)
	assert_true(level.hud.is_dialogue_open())
	assert_true(Game.sim.raids.pending)
	var box := level.hud.dialogue_box
	await wait_process_frames(2)
	if not box.is_choosing():
		box.skip()
	assert_true(box.is_choosing())
	assert_eq(box.choice_buttons().size(), 3)
	box.choose(NightFlow.SLEEP_ON)
	assert_eq(box.current_line().text, NightFlow.ALARM_REPLIES[NightFlow.SLEEP_ON], "Reggie answers first")
	box.skip()
	await wait_process_frames(2)
	assert_false(Game.sim.raids.pending, "Reggie dealt with them")
	assert_true(level.hud.night.is_open(), "the morning comes with its summary")
	level.hud.night.card.next_pressed.emit()
	assert_string_contains(level.hud.night.card.body_text(), "Молочные зубы", "the briefing tells of the raid")


func test_looking_at_the_farm_after_an_alarm_shows_it_without_jack() -> void:
	_raid_game()
	_go(DayCycle.HOME)
	_advance_to_hour(22.0)
	var level := await _open(HOME_SCENE)
	(level.get_node("NavRegion/Bed") as Bed).interact(level)
	var box := level.hud.dialogue_box
	await wait_process_frames(2)
	if not box.is_choosing():
		box.skip()
	box.choose(NightFlow.LOOK)
	box.skip()
	await wait_until(func() -> bool: return SceneRouter.is_busy(), 3.0)
	var loaded := await _finish_route()
	var field := loaded as Level
	assert_not_null(field)
	assert_eq(field.place, DayCycle.FARM)
	assert_eq(Game.sim.day.place, DayCycle.HOME, "only the view moved")
	assert_true(field.observing())
	await wait_physics_frames(2)
	assert_false(field.jack.visible)
	assert_true(field.hud.remote_bar.visible)
	assert_eq(_buttons(field.hud.remote_bar, "Поехать сюда").size(), 1)
	await _free_loaded(loaded)


# --- watching from afar

func test_a_farm_scene_without_jack_is_a_view_only() -> void:
	_go(DayCycle.HOME)
	var level := await _open(FIELD_SCENE)
	assert_true(level.observing())
	await wait_physics_frames(2)
	assert_false(level.jack.visible)
	assert_true(level.hud.remote_bar.visible)
	assert_string_contains(level.hud.remote_bar.text_label.text, "дом")


func test_reggies_evening_call_offers_a_lift_home() -> void:
	var level := await _open(FIELD_SCENE)
	_advance_to_hour(Game.sim.config.day.evening_hour + 0.1)
	await wait_process_frames(3)
	assert_true(level.hud.alert_banner.topics().has(Alert.HOME))
	assert_eq(_buttons(level.hud.alert_banner, Alert.GO_HOME).size(), 1)
	assert_string_contains(level.hud.objective_label.text, "домой")


func test_a_raid_seen_from_home_offers_the_farm_view() -> void:
	_go(DayCycle.HOME)
	var level := await _open(HOME_SCENE)
	Game.sim.inventory.create(Game.sim.config.strain.id, 60)
	Game.sim.raids.pending = true
	Game.sim.raids.deadline = Game.sim.clock.elapsed_game_seconds + 3600.0
	Game.sim.event_log.record(EventLog.RAID_STARTED, Game.sim.clock.elapsed_game_seconds, PackedStringArray([Raids.RAIDER_ACTOR]), {"bribe": 200})
	await wait_process_frames(3)
	assert_true(level.hud.alert_banner.topics().has(Alert.RAID))
	assert_eq(_buttons(level.hud.alert_banner, Alert.LOOK_AT_FARM).size(), 1)


func test_the_midnight_card_stays_away_after_a_night_in_bed() -> void:
	_go(DayCycle.HOME)
	_advance_to_hour(22.0)
	var level := await _open(HOME_SCENE)
	await wait_process_frames(2)
	(level.get_node("NavRegion/Bed") as Bed).interact(level)
	await wait_process_frames(3)
	assert_false(level.hud.day_card.is_waiting(), "the bedtime summary already told the day")
