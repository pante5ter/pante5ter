extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	Game.is_running = false
	get_tree().root.size = _old_screen
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


## The director may open a village story at the same moment; these tests look at the card alone.
func _past_midnight() -> void:
	var elapsed := Game.sim.clock.elapsed_game_seconds
	_advance_game_seconds(SimClock.GAME_SECONDS_PER_DAY - fmod(elapsed, SimClock.GAME_SECONDS_PER_DAY) + 60.0)
	Game.sim.stories.pending_id = ""


func _texts(root: Node) -> String:
	var lines := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	return "\n".join(lines)


func test_midnight_brings_up_the_day_card_with_the_days_money() -> void:
	var level := await _open()
	var product := Game.sim.inventory.create(Game.sim.config.strain.id, 80)
	var price := Game.sim.economy.price_of(product)
	Game.sim.apply(SellCommand.new(product.id))
	await wait_process_frames(2)
	assert_false(level.hud.day_card.is_showing(), "no card during the day")
	_past_midnight()
	await wait_process_frames(2)
	var card := level.hud.day_card
	assert_true(card.is_showing())
	var text := _texts(card)
	assert_string_contains(text, "День 1 окончен")
	assert_string_contains(text, "Начинается день 2")
	assert_string_contains(text, "Заработано %s" % UiText.money(price))
	assert_true(Rect2(Vector2.ZERO, Vector2(SCREEN)).encloses(card.get_global_rect()), "the card fits on screen: %s" % card.get_global_rect())


func test_the_card_fades_away_by_itself() -> void:
	var level := await _open()
	_past_midnight()
	await wait_process_frames(2)
	assert_true(level.hud.day_card.is_showing())
	await wait_seconds(DayCard.SHOW_SECONDS + 0.3)
	assert_false(level.hud.day_card.visible)


func test_a_dialogue_at_midnight_holds_the_card_until_it_closes() -> void:
	var level := await _open()
	_past_midnight()
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, "Босс, полночь.")]
	level.hud.play_dialogue(lines)
	await wait_seconds(DayCard.SHOW_SECONDS + 0.3)
	assert_false(level.hud.day_card.visible, "hidden under the dialogue")
	assert_true(level.hud.day_card.is_waiting())
	level.hud.dialogue_box.skip()
	await wait_process_frames(2)
	assert_true(level.hud.day_card.is_showing(), "shown once the dialogue is over")
	await wait_seconds(DayCard.SHOW_SECONDS + 0.3)
	assert_false(level.hud.day_card.visible, "and gone after its own time")


func test_opening_a_level_late_in_the_game_does_not_replay_old_days() -> void:
	_advance_game_seconds(SimClock.GAME_SECONDS_PER_DAY * 2.0)
	var level := await _open()
	await wait_process_frames(2)
	assert_false(level.hud.day_card.is_showing())


func test_a_quiet_day_still_says_it_is_over() -> void:
	var summary := DayCard.summary(Game.sim, 5)
	assert_string_contains(summary, "не пришло")
	assert_eq(DayCard.title(0), "День 1 окончен")


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
