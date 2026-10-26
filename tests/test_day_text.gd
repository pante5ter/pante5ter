extends GutTest

## Words for the day: crates, the bedtime summary, the morning briefing, Reggie's lines and the crew in «Люди».

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _state() -> SimState:
	var config := _balance.duplicate() as BalanceConfig
	config.first_day = null
	config.director = null
	config.stash = _balance.stash.duplicate() as StashDef
	config.stash.base_risk = 0.0
	return SimState.new(config, 1)


func test_crates_agree_with_the_number() -> void:
	assert_eq(DayText.crates(1), "1 ящик")
	assert_eq(DayText.crates(3), "3 ящика")
	assert_eq(DayText.crates(5), "5 ящиков")
	assert_eq(DayText.crates(11), "11 ящиков")
	assert_eq(DayText.crates(22), "22 ящика")


## Playtest 6: the summary keeps money, losses and situations; harvest counts were noise.
func test_the_summary_counts_the_money_and_the_losses() -> void:
	var state := _state()
	state.apply(PlantCommand.new(0))
	state.grow.plot(0).stage = Plot.Stage.READY
	state.apply(HarvestCommand.new(0))
	state.apply(HaulCommand.new(Helper.ACTOR))
	state.apply(AdvanceTimeCommand.new(20.0))
	state.event_log.record(EventLog.HAUL_STOPPED, state.clock.elapsed_game_seconds, PackedStringArray([Helper.ACTOR]), {"driver": Helper.ACTOR, "units": 3})
	var lines := "\n".join(DayText.summary(state, 0.0, state.clock.elapsed_game_seconds))
	assert_string_contains(lines, "Деньги:")
	assert_string_contains(lines, "Потери: полиция забрала %s." % DayText.crates(3))
	assert_false(lines.contains(".."), "no double stops")
	assert_false(lines.contains("собрано"), "harvest counts are not in the summary")
	assert_string_contains(lines, "В кассе")


func test_a_quiet_day_says_so() -> void:
	var state := _state()
	var lines := DayText.summary(state, 0.0, 0.0)
	assert_string_contains(lines[0], "не пришло и не ушло")
	assert_eq(lines.size(), 2, "money and the till, nothing else")


func test_the_briefing_lists_what_waits_today() -> void:
	var state := _state()
	state.inventory.create(state.config.strain.id, 60)
	var order := state.orders.inject(1, 0, 300, 6.0, 0.0, false, state.clock.elapsed_game_seconds)
	var lines := "\n".join(DayText.today(state))
	assert_string_contains(lines, "Ждут ответа звонков: 1")
	assert_string_contains(lines, "На ферме 1 ящик")
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	assert_string_contains("\n".join(DayText.today(state)), "Заказ #%d ждёт отправки" % order.id)


func test_a_calm_night_and_a_busy_one() -> void:
	var state := _state()
	assert_string_contains(DayText.night(state, 0.0, 10.0)[0], "спокойно")
	state.event_log.record(EventLog.HAUL_STOPPED, 5.0, PackedStringArray([Helper.ACTOR]), {"driver": Helper.ACTOR, "units": 2})
	assert_string_contains(DayText.night(state, 0.0, 10.0)[0], "полиция")


func test_long_nights_keep_the_last_news() -> void:
	var state := _state()
	for index: int in 7:
		state.event_log.record(EventLog.WORKER_UNPAID, float(index), PackedStringArray(), {"worker_id": "tom", "debt": 10 * (index + 1), "days_left": 1})
	var news := DayText.news_between(state, 0.0, 10.0, DayText.SITUATIONS)
	assert_eq(news.size(), DayText.MAX_NEWS + 1)
	assert_string_contains(news[0], "ещё 3")


func test_reggie_wakes_jack_with_the_time_and_the_trouble() -> void:
	var state := _state()
	var raid := state.event_log.record(EventLog.RAID_STARTED, 0.0, PackedStringArray(), {"bribe": 200})
	var inspection := state.event_log.record(EventLog.INSPECTION_WARNED, 0.0, PackedStringArray(), {"level": 70, "warning_hours": 1.5})
	assert_string_contains(NightFlow.alarm_line(raid, state), "Молочные зубы")
	assert_string_contains(NightFlow.alarm_line(inspection, state), "проверка")
	assert_true(NightFlow.alarm_line(raid, state).begins_with("00:00"))


func test_day_events_have_words() -> void:
	var state := _state()
	for event: SimEvent in [
		state.event_log.record(EventLog.HAUL_STARTED, 0.0, PackedStringArray(), {"driver": Helper.ACTOR, "units": 2, "arrives_at": 1.0}),
		state.event_log.record(EventLog.HAUL_ARRIVED, 0.0, PackedStringArray(), {"driver": DayCycle.JACK, "units": 2}),
		state.event_log.record(EventLog.EVENING_CALL, 0.0, PackedStringArray(), {"place": DayCycle.FARM}),
		state.event_log.record(EventLog.JACK_OUT_LATE, 0.0, PackedStringArray(), {"place": DayCycle.FARM, "suspicion_per_hour": 2.0}),
		state.event_log.record(EventLog.HELPER_SKILLS_REFUNDED, 0.0, PackedStringArray(), {"skill_ids": ["care"], "refund": 200, "money": 700}),
	]:
		assert_false(UiText.announcement(event, state).is_empty(), event.type)
	assert_string_contains(DayText.evening_call(state), "%d:00" % floori(state.config.day.evening_hour))


func test_the_refund_shows_in_the_ledger() -> void:
	var state := _state()
	var event := state.event_log.record(EventLog.HELPER_SKILLS_REFUNDED, 0.0, PackedStringArray([Helper.ACTOR]), {"skill_ids": ["care"], "refund": 200, "money": 700})
	var entries := MoneyLedger.of_event(event, state)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].amount, 200)


func test_the_objective_sends_jack_home_in_the_evening_and_to_bed_at_home() -> void:
	var state := _state()
	assert_false(UiText.objective(state).contains("домой"), "a new game starts at midnight without a night to pay for")
	state.apply(AdvanceTimeCommand.new(state.config.day.evening_hour / 24.0 * state.config.real_seconds_per_game_day + 1.0))
	assert_string_contains(UiText.objective(state), "домой")
	state.apply(TravelCommand.new(DayCycle.HOME))
	assert_string_contains(UiText.objective(state), "спать")


func test_reggie_tells_where_he_is_with_the_crates() -> void:
	var state := _state()
	state.inventory.create(state.config.strain.id, 60)
	state.apply(HaulCommand.new(Helper.ACTOR))
	assert_string_contains(PeopleText.helper_status(state), "ящики в тайник")


func test_the_crew_in_the_people_app() -> void:
	var state := _state()
	state.economy.earn(5000)
	for id: String in ["tom", "dave", "barry"]:
		state.apply(HireWorkerCommand.new(id))
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var phone := Phone.new()
	add_child_autofree(phone)
	PhonePeople.fill(box, state, phone)
	var texts := box.find_children("*", "Label", true, false).map(func(node: Node) -> String: return (node as Label).text)
	assert_true(texts.any(func(text: String) -> bool: return text.contains("3 из 3")))
	var fires := box.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return (node as Button).text == "Уволить")
	assert_eq(fires.size(), 3)
	state.apply(FireWorkerCommand.new("dave"))
	var again := VBoxContainer.new()
	add_child_autofree(again)
	PhonePeople.fill(again, state, phone)
	var crew_hires := again.find_children("*", "Button", true, false).filter(func(node: Node) -> bool:
		var text := (node as Button).text
		return text.begins_with("Нанять") and not text.begins_with("Нанять за")
	)
	assert_eq(crew_hires.size(), 2, "Dave's place is free, and the packer")
