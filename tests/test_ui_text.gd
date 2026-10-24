extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const FALLBACK_ERROR: String = "Не получилось."

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


## Finn's everyday guidance; the first-day script's own lines are checked in test_first_day.
func _new_state() -> SimState:
	var plain := _balance.duplicate() as BalanceConfig
	plain.first_day = null
	plain.director = null
	return SimState.new(plain, 1)


func _real_seconds_for_game_hours(hours: float) -> float:
	return hours * SimClock.GAME_SECONDS_PER_HOUR * _balance.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func test_every_stage_has_a_name() -> void:
	for stage: int in Plot.Stage.values():
		assert_ne(UiText.stage(stage as Plot.Stage), "?", "stage %d has no name" % stage)


func test_every_command_error_has_a_text() -> void:
	var script := CommandResult.new().get_script() as Script
	var constants: Dictionary = script.get_script_constant_map()
	assert_gt(constants.size(), 0)
	for code: Variant in constants.values():
		if code is String:
			assert_ne(UiText.error(code as String), FALLBACK_ERROR, "no text for %s" % code)


func test_clock_shows_day_from_one_and_minutes() -> void:
	var clock := SimClock.new(_balance.real_seconds_per_game_day)
	assert_eq(UiText.clock(clock), "День 1 · 00:00")
	clock.advance(SimClock.GAME_SECONDS_PER_DAY + 7.5 * SimClock.GAME_SECONDS_PER_HOUR)
	assert_eq(UiText.clock(clock), "День 2 · 07:30")


func test_capitalized_handles_cyrillic_and_empty() -> void:
	assert_eq(UiText.capitalized("готово к сбору"), "Готово к сбору")
	assert_eq(UiText.capitalized(""), "")


func test_worker_status_follows_the_worker() -> void:
	var state := _new_state()
	assert_eq(UiText.worker_status(state.workers), "Работника нет")
	state.apply(HireWorkerCommand.new())
	assert_string_contains(UiText.worker_status(state.workers), "ждёт работы")
	state.apply(AdvanceTimeCommand.new(0.0))
	assert_string_contains(UiText.worker_status(state.workers), "сажает")


func test_objective_walks_the_player_through_the_loop() -> void:
	var state := _new_state()
	assert_string_contains(UiText.objective(state), "посади")
	assert_string_contains(UiText.objective(state), "через контейнер")
	state.apply(PlantCommand.new(0))
	assert_string_contains(UiText.objective(state), "Полей")
	state.apply(WaterCommand.new(0))
	assert_string_contains(UiText.objective(state), "Найми")
	assert_string_contains(UiText.objective(state), "«Люди»")
	state.apply(HireWorkerCommand.new())
	assert_string_contains(UiText.objective(state), "закажите семена")
	assert_string_contains(UiText.objective(state), "(Tab)")


func test_objective_points_at_harvest_and_then_the_buyer() -> void:
	var state := _new_state()
	var strain := _balance.strain
	state.apply(PlantCommand.new(0))
	var hours_left := strain.seed_hours + strain.sprout_hours + strain.bush_hours
	while hours_left > 0.0:
		state.apply(WaterCommand.new(0))
		var step := minf(hours_left, strain.water_capacity_hours)
		state.apply(AdvanceTimeCommand.new(_real_seconds_for_game_hours(step)))
		hours_left -= step
	assert_string_contains(UiText.objective(state), "Собери")
	state.apply(HarvestCommand.new(0))
	assert_string_contains(UiText.objective(state), "Расфасуй", "fresh harvest has to be packed first")


func test_objective_skips_hiring_when_wage_is_unaffordable() -> void:
	var balance := _balance.duplicate() as BalanceConfig
	balance.starting_money = balance.worker.daily_wage - 1
	balance.first_day = null
	var state := SimState.new(balance, 1)
	state.apply(PlantCommand.new(0))
	state.apply(WaterCommand.new(0))
	assert_string_contains(UiText.objective(state), "закажите семена")


func test_announcements_cover_worker_and_plot_news() -> void:
	var state := _new_state()
	var event_log := state.event_log
	var quit := event_log.record(EventLog.WORKER_QUIT, 0.0, PackedStringArray([Workers.ACTOR]), {"reason": "unpaid", "money": 0})
	var paid := event_log.record(EventLog.WORKER_PAID, 0.0, PackedStringArray([Workers.ACTOR]), {"wage": 150, "money": 10})
	var dried := event_log.record(EventLog.PLOT_DRIED_OUT, 0.0, PackedStringArray(), {"plot_id": 2})
	var ripe := event_log.record(EventLog.PLOT_STAGE_CHANGED, 0.0, PackedStringArray(), {"plot_id": 0, "stage": "ready"})
	var sprout := event_log.record(EventLog.PLOT_STAGE_CHANGED, 0.0, PackedStringArray(), {"plot_id": 0, "stage": "sprout"})
	assert_string_contains(UiText.announcement(quit, state), "ушёл")
	assert_string_contains(UiText.announcement(paid, state), "£150")
	assert_string_contains(UiText.announcement(dried, state), "Грядка 3")
	assert_string_contains(UiText.announcement(ripe, state), "созрела")
	assert_eq(UiText.announcement(sprout, state), "")


func test_real_duration_shows_real_minutes_and_seconds() -> void:
	var state := _new_state()
	var one_real_minute := 60.0 * SimClock.GAME_SECONDS_PER_DAY / _balance.real_seconds_per_game_day
	assert_eq(UiText.real_duration(one_real_minute * 2.5, state), "2:30")
	assert_eq(UiText.real_duration(-5.0, state), "0:00")


func test_order_and_delivery_news() -> void:
	var state := _new_state()
	var event_log := state.event_log
	var received := event_log.record(EventLog.ORDER_RECEIVED, 0.0, PackedStringArray(), {"order_id": 4, "quantity": 3, "min_quality": 55, "reward": 420})
	var paid := event_log.record(EventLog.ORDER_PAID, 0.0, PackedStringArray(), {"order_id": 4, "courier_id": "frank", "reward": 420, "fee": 84, "money": 900})
	var expired := event_log.record(EventLog.ORDER_EXPIRED, 0.0, PackedStringArray(), {"order_id": 5})
	var delivered := event_log.record(EventLog.SUPPLY_DELIVERED, 0.0, PackedStringArray(), {"item": Supplies.FERTILIZER, "quantity": 2})
	assert_string_contains(UiText.announcement(received, state), "£420")
	assert_string_contains(UiText.announcement(paid, state), "доставлен")
	assert_string_contains(UiText.announcement(expired, state), "#5")
	assert_string_contains(UiText.announcement(delivered, state), "удобрение × 2")


func test_item_names() -> void:
	var state := _new_state()
	var premium := _balance.extra_strains[0]
	assert_eq(UiText.item_name(Supplies.FERTILIZER, state), "удобрение")
	assert_eq(UiText.item_name(Supplies.seed_item(premium.id), state), "семена «%s»" % premium.display_name)


func test_rent_news_is_announced() -> void:
	var state := _new_state()
	var event_log := state.event_log
	var paid := event_log.record(EventLog.RENT_PAID, 0.0, PackedStringArray([Rent.LORD_ACTOR]), {"amount": 1500, "money": 200})
	var missed := event_log.record(EventLog.RENT_MISSED, 0.0, PackedStringArray([Rent.LORD_ACTOR]), {"amount": 1500, "money": 300, "missed": 2, "evict_after": 3})
	var evicted := event_log.record(EventLog.RENT_EVICTED, 0.0, PackedStringArray([Rent.LORD_ACTOR]), {"missed": 3})
	assert_string_contains(UiText.announcement(paid, state), "£1500")
	assert_string_contains(UiText.announcement(missed, state), "2 из 3")
	assert_string_contains(UiText.announcement(evicted, state), "расторг")


func test_objective_warns_before_rent_the_player_cannot_pay() -> void:
	var state := _new_state()
	var rent_hours := _balance.rent.first_due_hours
	state.economy.money = 0
	state.apply(AdvanceTimeCommand.new(_real_seconds_for_game_hours(rent_hours - 2.0)))
	assert_string_contains(UiText.objective(state), "аренда")
	state.economy.money = _balance.rent.amount
	assert_false(UiText.objective(state).contains("аренда"), "no rent warning once the money is there")


func test_objective_says_the_farm_is_lost_after_eviction() -> void:
	var state := _new_state()
	state.rent.evicted = true
	assert_string_contains(UiText.objective(state), "расторг")


func test_lord_talks_about_the_next_payment() -> void:
	var state := _new_state()
	var lines := UiText.lord_lines(state)
	assert_gt(lines.size(), 0)
	assert_eq(lines[0].speaker, "Лорд Эшкомб")
	var all_text := "\n".join(lines.map(func(line: DialogueLineDef) -> String: return line.text))
	assert_string_contains(all_text, UiText.money(_balance.rent.amount))


func test_lord_complains_after_a_missed_payment_and_says_goodbye_after_eviction() -> void:
	var state := _new_state()
	state.rent.missed = 1
	var complaint := "\n".join(UiText.lord_lines(state).map(func(line: DialogueLineDef) -> String: return line.text))
	assert_string_contains(complaint, "1 из %d" % _balance.rent.evict_after_missed)
	state.rent.evicted = true
	var farewell := UiText.lord_lines(state)
	assert_gt(farewell.size(), 0)
	assert_false("\n".join(farewell.map(func(line: DialogueLineDef) -> String: return line.text)).contains("следующий платёж"), "no payment talk after eviction")
