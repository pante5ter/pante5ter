extends GutTest

## Day-end summary (all-nighter at the morning hour) and the finance app.

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()
	DayEndWatch.forget()
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	Game.is_running = false
	get_tree().root.size = _old_screen
	DayEndWatch.forget()
	Game.new_game(42)


func _open() -> Level:
	var level := (load(FIELD_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _advance_game_seconds(game_seconds: float) -> void:
	Game.sim.apply(AdvanceTimeCommand.new(game_seconds * Game.sim.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


## Past the first morning that closes a day (the prologue night does not count).
func _past_morning() -> void:
	var target := DayEndWatch.next_morning(Game.sim) + 60.0
	_advance_game_seconds(target - Game.sim.clock.elapsed_game_seconds)
	Game.sim.stories.pending_id = ""


func _texts(root: Node) -> String:
	var lines := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func test_staying_up_past_morning_brings_the_day_summary_with_the_days_money() -> void:
	var level := await _open()
	var product := Game.sim.inventory.create(Game.sim.config.strain.id, 80)
	var price := Game.sim.economy.price_of(product)
	Game.sim.apply(SellCommand.new(product.id))
	await wait_process_frames(2)
	assert_false(level.hud.night.is_open(), "no summary during the day")
	_past_morning()
	await wait_process_frames(3)
	assert_true(level.hud.night.is_open())
	assert_eq(level.hud.night.page(), NightFlow.PAGE_SUMMARY)
	var panel := level.hud.night.summary
	assert_eq(panel.title_label.text, "День 1 окончен")
	var text := _texts(panel)
	assert_string_contains(text, "Заработано")
	assert_string_contains(text, UiText.money(price))
	assert_true(Rect2(Vector2.ZERO, Vector2(SCREEN)).encloses(panel.get_global_rect()), "the panel fits on screen: %s" % panel.get_global_rect())


func test_a_dialogue_at_morning_holds_the_summary_until_it_closes() -> void:
	var level := await _open()
	_past_morning()
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, "Босс, утро.")]
	level.hud.play_dialogue(lines)
	await wait_process_frames(3)
	assert_false(level.hud.night.is_open(), "held under the dialogue")
	level.hud.dialogue_box.skip()
	await wait_process_frames(3)
	assert_true(level.hud.night.is_open(), "shown once the dialogue is over")
	assert_eq(level.hud.night.page(), NightFlow.PAGE_SUMMARY)


func test_opening_a_level_late_in_the_game_does_not_replay_old_days() -> void:
	_advance_game_seconds(SimClock.GAME_SECONDS_PER_DAY * 2.0)
	var level := await _open()
	await wait_process_frames(3)
	assert_false(level.hud.night.is_open())


func test_a_quiet_day_still_says_it_is_over() -> void:
	var day := SimClock.GAME_SECONDS_PER_DAY
	var summary := DaySummary.build(Game.sim, 0.0, day)
	assert_string_contains("\n".join(summary.lines()), "не пришло")
	assert_eq(summary.title(), "День 1 окончен")
	assert_eq(DayEndWatch.day_number(0.0), 1)


func test_the_finance_app_lists_spending_with_reasons() -> void:
	var level := await _open()
	Game.sim.economy.earn(Game.sim.config.plot_price)
	Game.sim.apply(BuyPlotCommand.new())
	Game.sim.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	var phone := level.hud.phone
	phone.open()
	assert_eq(phone.app_icon(Phone.APP_FINANCE).title, "Финансы")
	phone.open_app(Phone.APP_FINANCE)
	await wait_process_frames(2)
	var text := _texts(phone)
	assert_string_contains(text, "Новая грядка")
	assert_string_contains(text, "−%s" % UiText.money(Game.sim.config.plot_price))
	assert_string_contains(text, "Покупка: ")
	assert_string_contains(text, "Сегодня, день 1")
	assert_string_contains(text, UiText.money(Game.sim.economy.money))
