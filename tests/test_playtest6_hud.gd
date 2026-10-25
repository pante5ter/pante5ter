extends GutTest

## Playtest 6, the HUD: deadlines on the game clock, Jack's own tasks under the clock, suspicion that
## comes from a car leaving the field at night, messages that survive a trip, a short morning report
## and Vivienne who does not repeat herself.

const BALANCE_PATH: String = "res://content/balance.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const HOME_SCENE: String = "res://scenes/home/home.tscn"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _balance: BalanceConfig
var _old_screen: Vector2i = Vector2i.ZERO


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func before_each() -> void:
	Vivienne.forget()


func after_each() -> void:
	Game.is_running = false
	if _old_screen != Vector2i.ZERO:
		get_tree().root.size = _old_screen
		_old_screen = Vector2i.ZERO
	Vivienne.forget()
	Game.new_game(42)


func _calm() -> BalanceConfig:
	var calm := _balance.duplicate() as BalanceConfig
	calm.starting_money = 300
	calm.problems = _balance.problems.duplicate() as ProblemsDef
	calm.problems.chance_per_hour = 0.0
	calm.raids = _balance.raids.duplicate() as RaidsDef
	calm.raids.chance_per_night = 0.0
	calm.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	calm.suspicion.inspection_threshold = 1000.0
	calm.first_day = null
	calm.director = null
	return calm


func _state() -> SimState:
	return SimState.new(_calm(), 3)


func _advance_hours(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.0001:
		var step := minf(0.25, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / DAY))
		elapsed += step


func _promised_visit() -> SimState:
	var state := _state()
	_advance_hours(state, state.config.rent.first_due_hours - state.config.rent.call_ahead_hours + 0.25)
	assert_true(state.rent.call_pending(), "the lord has rung")
	assert_true(state.apply(RentCommand.new(Rent.VISIT)).ok)
	return state


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _use_screen() -> void:
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


# --- the game clock

func test_game_when_reads_like_the_hud_clock() -> void:
	var state := _state()
	state.clock.advance_to(DAY + 9.0 * HOUR)
	assert_eq(UiText.game_when(DAY + 18.0 * HOUR, state), "сегодня в 18:00")
	assert_eq(UiText.game_when(2.0 * DAY + 10.0 * HOUR, state), "завтра в 10:00")
	assert_eq(UiText.game_when(4.0 * DAY + 14.5 * HOUR, state), "в 14:30, день 5")
	assert_eq(UiText.game_when(DAY + 18.0 * HOUR, state, true), "до 18:00 сегодня")
	assert_eq(UiText.game_when(2.0 * DAY + 10.0 * HOUR, state, true), "до 10:00 завтра")


func test_midnight_always_names_the_day() -> void:
	var state := _state()
	state.clock.advance_to(DAY + 22.0 * HOUR)
	assert_eq(UiText.game_when(2.0 * DAY, state, true), "до 00:00, день 3", "the HUD clock reads «День 3 · 00:00» then")
	assert_eq(UiText.game_when(2.0 * DAY - 0.2, state, true), "до 00:00, день 3", "a hair short of midnight is still midnight")
	assert_eq(UiText.game_when(INF, state), "без срока")


func test_near_deadlines_stay_a_real_countdown() -> void:
	var state := _state()
	state.clock.advance_to(DAY + 9.0 * HOUR)
	var near := state.clock.elapsed_game_seconds + 0.5 * HOUR
	assert_eq(UiText.due_by(near, state), "через " + UiText.real_duration(0.5 * HOUR, state))
	var far := state.clock.elapsed_game_seconds + 5.0 * HOUR
	assert_eq(UiText.due_by(far, state), "до 14:00 сегодня")


func test_rent_texts_show_the_clock_not_real_minutes() -> void:
	var state := _state()
	state.clock.advance_to(state.rent.next_due_at - 6.0 * HOUR)
	var when := UiText.game_when(state.rent.next_due_at, state, true)
	assert_string_contains(UiText.objective(state), when, "rent short of money")
	assert_false(UiText.objective(state).contains(" мин"))
	assert_string_contains("\n".join(DayText.today(state)), when)
	var box := VBoxContainer.new()
	add_child_autofree(box)
	PhoneFinance.fill(box, state)
	var texts := "\n".join(box.find_children("*", "Label", true, false).map(func(node: Node) -> String: return (node as Label).text))
	assert_string_contains(texts, "Аренда, срок " + when)


func test_an_order_deadline_hours_away_reads_as_clock_time() -> void:
	var state := _state()
	state.clock.advance_to(DAY + 9.0 * HOUR)
	var order := state.orders.inject(1, 0, 300, 1.0, 6.0, false, state.clock.elapsed_game_seconds)
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	assert_string_contains("\n".join(DayText.today(state)), "Заказ #%d ждёт отправки, срок: до 15:00 сегодня" % order.id)


# --- Jack's own tasks

func test_a_promised_visit_is_a_task_with_money_and_the_hour() -> void:
	var state := _promised_visit()
	var tasks := JackTasks.text(state)
	assert_string_contains(tasks, "Лорд ждёт в поместье · %s · %s" % [UiText.money(state.rent.owed()), UiText.game_when(state.rent.next_due_at, state, true)])
	assert_false(tasks.contains(" мин"))


func test_no_tasks_on_a_quiet_day() -> void:
	assert_eq(JackTasks.lines(_state()).size(), 0)


func test_accepted_orders_are_tasks() -> void:
	var state := _state()
	var order := state.orders.inject(1, 0, 300, 6.0, 0.0, false, state.clock.elapsed_game_seconds)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	assert_string_contains(JackTasks.text(state), "Заказ #%d: отправить" % order.id)


func test_the_hud_keeps_the_lords_wait_under_the_clock() -> void:
	_use_screen()
	var state := _promised_visit()
	Game.sim = state
	Game.is_running = false
	var level := await _open(FIELD_SCENE)
	if level.hud.is_dialogue_open():
		level.hud.dialogue_box.skip()
	await wait_process_frames(2)
	assert_true(level.hud.tasks_label.visible)
	assert_string_contains(level.hud.tasks_label.text, "Лорд ждёт в поместье")
	assert_eq(level.hud.tasks_label.get_index(), level.hud.time_label.get_index() + 1, "right under the clock")


# --- suspicion comes from a car leaving the field at night

func test_night_texts_blame_the_car_leaving_the_field() -> void:
	var state := _state()
	var late := state.event_log.record(EventLog.JACK_OUT_LATE, 0.0, PackedStringArray(), {"place": DayCycle.FARM, "suspicion_per_hour": 2.0})
	var text := UiText.announcement(late, state)
	assert_string_contains(text, "с поля")
	assert_string_contains(text, "фары")
	assert_false(text.contains("Свет и машина"))
	assert_string_contains(DayText.evening_call(state), "фары")
	var home := state.event_log.record(EventLog.HOME_NIGHT, 0.0, PackedStringArray(), {"suspicion_relief": 5.0, "bonus": 0})
	assert_false(", ".join(DayText.home_night_gains(home)).contains("свет"))


func test_the_evening_nudge_explains_the_headlights() -> void:
	var state := SimState.new(_calm(), 3)
	_advance_hours(state, state.config.day.evening_hour + 0.25)
	var text := UiText.objective(state)
	assert_string_contains(text, "домой")
	assert_string_contains(text, "фары")
	assert_false(text.contains("видно издалека"))


# --- a message survives the trip

func test_a_message_outlives_the_scene_change() -> void:
	_use_screen()
	Game.sim = _state()
	var field := await _open(FIELD_SCENE)
	field.hud.show_message("Джек поехал домой.")
	remove_child(field)
	field.free()
	var home := await _open(HOME_SCENE)
	assert_string_contains(home.hud.message_label.text, "Джек поехал домой.")
	assert_gt(home.hud.message_label.modulate.a, 0.0, "still on screen after the fade")


func test_news_from_the_trip_shows_on_arrival() -> void:
	_use_screen()
	Game.sim = _state()
	var field := await _open(FIELD_SCENE)
	assert_true(Game.sim.apply(TravelCommand.new(DayCycle.HOME)).ok, "the trip runs in the sim at once")
	remove_child(field)
	field.free()
	var home := await _open(HOME_SCENE)
	assert_string_contains(home.hud.message_label.text, "Приехали")
	assert_gt(home.hud.message_label.modulate.a, 0.0)


func test_a_new_game_does_not_inherit_the_message() -> void:
	_use_screen()
	Game.sim = _state()
	var field := await _open(FIELD_SCENE)
	field.hud.show_message("Старое.")
	remove_child(field)
	field.free()
	Game.sim = _state()
	var again := await _open(FIELD_SCENE)
	assert_false(again.hud.message_label.text.contains("Старое."))


# --- the morning report

func test_the_summary_keeps_money_losses_and_situations_only() -> void:
	var state := _state()
	state.event_log.record(EventLog.PLOT_DRIED_OUT, 1.0, PackedStringArray(), {"plot_id": 0})
	state.event_log.record(EventLog.PLOT_PROBLEM, 1.0, PackedStringArray(), {"plot_id": 1, "problem": Problems.PESTS})
	state.event_log.record(EventLog.HAUL_STOPPED, 2.0, PackedStringArray([Helper.ACTOR]), {"driver": Helper.ACTOR, "units": 2})
	state.event_log.record(EventLog.PLOT_CROP_EATEN, 3.0, PackedStringArray(), {"plot_id": 2, "eaten": 3})
	state.event_log.record(EventLog.INSPECTION_FAILED, 4.0, PackedStringArray(["inspector"]), {"fine": 200, "money": 100, "level": 60})
	var text := "\n".join(DayText.summary(state, 0.0, 10.0))
	assert_string_contains(text, "Деньги:")
	assert_string_contains(text, "Потери: полиция забрала 2 ящика; вредители съели урожай грядок: 1; штрафы и откупные £200.")
	assert_string_contains(text, "Проверка нашла, к чему придраться")
	assert_false(text.contains("пересохла"), "a dry bed is not news for the morning")
	assert_false(text.contains("вредители. Пока"), "nor is a bed with pests")
	assert_false(text.contains("Урожай:"))


func test_new_clues_get_one_line_pointing_at_the_wall() -> void:
	var state := _state()
	for number: int in 3:
		state.event_log.record(EventLog.INTRIGUE_CLUE, 5.0, PackedStringArray(), {"clue": "x%d" % number, "number": number + 1, "of": 4})
	var night := DayText.night(state, 0.0, 10.0)
	var clue_lines := Array(night).filter(func(line: String) -> bool: return line.contains("зацепка"))
	assert_eq(clue_lines.size(), 1)
	assert_eq(clue_lines[0], "Новая зацепка — на стене в контейнере.")


func test_the_morning_report_is_short() -> void:
	var state := _state()
	for index: int in 9:
		state.event_log.record(EventLog.WORKER_UNPAID, float(index), PackedStringArray(), {"worker_id": "tom", "debt": 10 * (index + 1), "days_left": 1})
	assert_lte(DayText.night(state, 0.0, 20.0).size(), DayText.MAX_NEWS + 1)
	for index: int in 8:
		var order := state.orders.inject(1, 0, 300, 6.0, 0.0, false, state.clock.elapsed_game_seconds)
		state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	assert_lte(DayText.today(state).size(), DayText.MAX_TODAY + 1)


# --- Vivienne

func test_vivienne_has_enough_to_say() -> void:
	assert_gte(Vivienne.GOSSIP.size(), 8)
	assert_gte(Vivienne.EVENING.size(), 6)
	for line: String in Vivienne.GOSSIP:
		assert_false(Vivienne.EVENING.has(line), "evening and morning pools differ")
	var dobson := Array(Vivienne.GOSSIP).filter(func(line: String) -> bool: return line.contains("Добсон"))
	assert_eq(dobson.size(), 1)
	assert_false(String(dobson[0]).contains("надоел"))
	assert_string_contains(String(dobson[0]), "продаёт")


func test_vivienne_never_repeats_herself_in_a_day() -> void:
	var heard: Array[String] = []
	for talk: int in Vivienne.EVENING.size():
		var line := Vivienne.say(Vivienne.EVENING, 4)
		assert_false(heard.has(line), "talk %d is new" % talk)
		heard.append(line)
	var spent := Vivienne.say(Vivienne.EVENING, 4)
	assert_false(Vivienne.EVENING.has(spent), "out of evening lines she says so")
	assert_ne(Vivienne.say(Vivienne.EVENING, 4), spent, "and not twice running")


func test_vivienne_does_not_open_the_day_with_yesterdays_last_line() -> void:
	var last := ""
	for day: int in 12:
		var line := Vivienne.say(Vivienne.GOSSIP, day)
		assert_ne(line, last, "day %d" % day)
		last = line


func test_breakfast_and_a_morning_chat_say_different_things() -> void:
	var state := _state()
	state.clock.advance_to(2.0 * DAY + 7.0 * HOUR)
	var night := state.event_log.record(EventLog.HOME_NIGHT, state.clock.elapsed_game_seconds, PackedStringArray(), {"suspicion_relief": 5.0, "bonus": 0})
	var breakfast := Vivienne.morning_lines(night)[0].text
	assert_true(Vivienne.GOSSIP.has(breakfast))
	var chat := Vivienne.lines(state)[0].text
	assert_true(Vivienne.GOSSIP.has(chat), "in the morning she talks village news")
	assert_ne(chat, breakfast)
	var again := Vivienne.lines(state)[0].text
	assert_ne(again, chat)
	assert_ne(again, breakfast)


func test_the_evening_pool_at_evening() -> void:
	var state := _state()
	state.clock.advance_to(DAY + (state.config.day.evening_hour + 0.5) * HOUR)
	assert_true(Vivienne.EVENING.has(Vivienne.lines(state)[0].text))
