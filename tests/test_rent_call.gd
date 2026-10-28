extends GutTest

## Playtest 5: the lord rings ahead of the rent. Jack pays on the phone there and then, or promises
## to bring it to the manor before it is due; a broken promise counts as a missed payment.

const BALANCE_PATH: String = "res://content/balance.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _balance: BalanceConfig
var _old_screen: Vector2i = Vector2i.ZERO


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func after_each() -> void:
	Game.is_running = false
	if _old_screen != Vector2i.ZERO:
		get_tree().root.size = _old_screen
		_old_screen = Vector2i.ZERO
	Game.new_game(42)


func _calm(money: int) -> BalanceConfig:
	var calm := _balance.duplicate() as BalanceConfig
	calm.shop = null
	calm.opportunities = null
	calm.starting_money = money
	calm.problems = _balance.problems.duplicate() as ProblemsDef
	calm.problems.chance_per_hour = 0.0
	calm.raids = _balance.raids.duplicate() as RaidsDef
	calm.raids.chance_per_night = 0.0
	calm.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	calm.suspicion.inspection_threshold = 1000.0
	calm.helper = null
	calm.day = null
	calm.first_day = null
	calm.director = null
	return calm


func _advance_hours(state: SimState, hours: float, step_hours: float = 0.25) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.0001:
		var step := minf(step_hours, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		elapsed += step


func _call_hour() -> float:
	return _balance.rent.first_due_hours - _balance.rent.call_ahead_hours


func _called(money: int) -> SimState:
	var state := SimState.new(_calm(money), 3)
	_advance_hours(state, _call_hour() + 0.25)
	return state


# --- the sim

func test_the_lord_calls_well_ahead_of_the_rent() -> void:
	var ahead := _balance.rent.call_ahead_hours
	assert_between(ahead, 6.0, _balance.rent.period_hours - 6.0, "time to pay or drive over, and never two calls at once")


func test_the_lord_rings_once_ahead_of_the_due_time() -> void:
	var state := SimState.new(_calm(5000), 3)
	_advance_hours(state, _call_hour() - 0.25)
	assert_eq(state.event_log.of_type(EventLog.RENT_CALLED).size(), 0)
	assert_false(state.rent.call_pending())
	_advance_hours(state, 0.5)
	var calls := state.event_log.of_type(EventLog.RENT_CALLED)
	assert_eq(calls.size(), 1)
	assert_almost_eq(calls[0].game_time, _call_hour() * HOUR, 0.001)
	assert_eq(int(calls[0].data["amount"]), _balance.rent.amount)
	assert_true(state.rent.call_pending())
	assert_true(Stories.is_beat(calls[0]), "the call drops the game back to normal speed")
	_advance_hours(state, 2.0)
	assert_eq(state.event_log.of_type(EventLog.RENT_CALLED).size(), 1, "one call per payment")


func test_paying_on_the_call_takes_the_money_at_once() -> void:
	var state := _called(5000)
	assert_eq(state.rent.can_pay(), "")
	var result := state.apply(RentCommand.new(Rent.PAY))
	assert_true(result.ok)
	assert_eq(state.economy.money, 5000 - _balance.rent.amount)
	var paid := state.event_log.of_type(EventLog.RENT_PAID)
	assert_eq(paid.size(), 1)
	assert_eq(int(paid[0].data["amount"]), _balance.rent.amount)
	assert_eq(String(paid[0].data["where"]), Rent.BY_PHONE)
	assert_false(state.rent.call_pending())
	assert_almost_eq(state.rent.next_due_at, (_balance.rent.first_due_hours + _balance.rent.period_hours) * HOUR, 0.001)
	_advance_hours(state, _balance.rent.call_ahead_hours + 1.0)
	assert_eq(state.event_log.of_type(EventLog.RENT_PAID).size(), 1, "the old due time takes nothing more")
	assert_eq(state.rent.missed, 0)


func test_paying_now_is_refused_when_the_money_is_short() -> void:
	var state := _called(_balance.rent.amount - 1)
	assert_eq(state.rent.can_pay(), CommandResult.NOT_ENOUGH_MONEY)
	assert_eq(state.apply(RentCommand.new(Rent.PAY)).error, CommandResult.NOT_ENOUGH_MONEY)
	assert_eq(state.economy.money, _balance.rent.amount - 1)
	assert_true(state.rent.call_pending(), "the question stays open")


func test_a_promise_to_visit_is_kept_by_paying_at_the_manor() -> void:
	var state := _called(5000)
	assert_true(state.apply(RentCommand.new(Rent.VISIT)).ok)
	assert_true(state.rent.visit_promised())
	assert_false(state.rent.call_pending())
	assert_eq(state.event_log.of_type(EventLog.RENT_VISIT_PROMISED).size(), 1)
	assert_eq(state.economy.money, 5000, "a promise costs nothing yet")
	assert_eq(state.apply(RentCommand.new(Rent.VISIT)).error, CommandResult.ALREADY_DONE)
	_advance_hours(state, 3.0)
	assert_true(state.apply(RentCommand.new(Rent.PAY)).ok)
	var paid := state.event_log.of_type(EventLog.RENT_PAID)
	assert_eq(String(paid[0].data["where"]), Rent.AT_MANOR)
	assert_false(state.rent.visit_promised())
	assert_eq(state.economy.money, 5000 - _balance.rent.amount)


func test_a_broken_promise_is_a_missed_payment_even_with_money() -> void:
	var state := _called(5000)
	state.apply(RentCommand.new(Rent.VISIT))
	_advance_hours(state, _balance.rent.call_ahead_hours)
	var missed := state.event_log.of_type(EventLog.RENT_MISSED)
	assert_eq(missed.size(), 1)
	assert_true(missed[0].data.get("promised", false) == true)
	assert_eq(state.rent.missed, 1)
	assert_eq(state.economy.money, 5000, "the lord waited at the manor; nobody took the money")
	assert_almost_eq(state.suspicion.level, _balance.rent.missed_suspicion, 0.001)
	assert_false(state.rent.visit_promised())
	_advance_hours(state, _balance.rent.period_hours)
	assert_eq(state.event_log.of_type(EventLog.RENT_CALLED).size(), 2, "the next rent brings the next call")


func test_an_unanswered_call_keeps_the_old_automatic_payment() -> void:
	var state := _called(5000)
	_advance_hours(state, _balance.rent.call_ahead_hours)
	assert_eq(state.event_log.of_type(EventLog.RENT_PAID).size(), 1)
	assert_eq(state.economy.money, 5000 - _balance.rent.amount)
	assert_false(state.rent.call_pending())


func test_answers_without_a_call_are_refused() -> void:
	var state := SimState.new(_calm(5000), 3)
	assert_eq(state.apply(RentCommand.new(Rent.PAY)).error, CommandResult.NO_STORY, "no call, nothing to answer")
	assert_eq(state.apply(RentCommand.new(Rent.VISIT)).error, CommandResult.NO_STORY)
	assert_eq(state.economy.money, 5000)
	var called := _called(5000)
	assert_eq(called.apply(RentCommand.new("later")).error, CommandResult.UNKNOWN_CHOICE)


func test_an_advance_lowers_what_the_lord_asks_for() -> void:
	var state := SimState.new(_calm(5000), 3)
	state.rent.add_credit(500)
	_advance_hours(state, _call_hour() + 0.25)
	assert_eq(state.rent.owed(), _balance.rent.amount - 500)
	assert_eq(int(state.event_log.of_type(EventLog.RENT_CALLED)[0].data["amount"]), _balance.rent.amount - 500)
	state.apply(RentCommand.new(Rent.PAY))
	assert_eq(state.economy.money, 5000 - _balance.rent.amount + 500)
	assert_eq(state.rent.credit, 0)


func test_the_promise_survives_save_and_load_and_old_saves_load() -> void:
	var state := _called(5000)
	state.apply(RentCommand.new(Rent.VISIT))
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), state.to_json())
	assert_true(loaded.rent.visit_promised())
	var old := state.to_dict()
	(old["rent"] as Dictionary).erase("call_stage")
	var migrated := SimState.from_json(JSON.stringify(old), state.config)
	assert_not_null(migrated, "a save from before the calls still loads")
	assert_false(migrated.rent.visit_promised())


func test_one_big_step_matches_many_small_steps_through_calls() -> void:
	var big := SimState.new(_calm(10000), 9)
	var small := SimState.new(_calm(10000), 9)
	var hours := _balance.rent.first_due_hours + _balance.rent.period_hours * 2.0
	_advance_hours(big, hours, hours)
	_advance_hours(small, hours, 0.25)
	assert_eq(big.to_json(), small.to_json())


func test_without_a_call_ahead_the_lord_never_rings() -> void:
	var config := _calm(5000)
	config.rent = _balance.rent.duplicate() as RentDef
	config.rent.call_ahead_hours = 0.0
	var state := SimState.new(config, 3)
	_advance_hours(state, config.rent.first_due_hours + 0.25, 1.0)
	assert_eq(state.event_log.of_type(EventLog.RENT_CALLED).size(), 0)
	assert_eq(state.event_log.of_type(EventLog.RENT_PAID).size(), 1)


# --- texts

func test_the_call_offers_both_answers_and_greys_out_paying_when_short() -> void:
	var rich := _called(5000)
	var labels := RentTalk.call_choices(rich)
	assert_eq(labels.size(), 2)
	assert_string_contains(labels[0], UiText.money(_balance.rent.amount))
	assert_string_contains(labels[1], "поместье")
	assert_eq(RentTalk.pay_flags(rich), [true, true] as Array[bool])
	var poor := _called(300)
	assert_eq(RentTalk.pay_flags(poor), [false, true] as Array[bool])
	assert_string_contains(RentTalk.call_choices(poor)[0], "в кассе только %s" % UiText.money(300), "the reason is on the button")


func test_a_promised_visit_shows_as_a_task_with_a_deadline() -> void:
	var state := _called(5000)
	state.apply(RentCommand.new(Rent.VISIT))
	assert_string_contains(StoryText.summons(state, false), "аренд")
	assert_string_contains(StoryText.summons(state, true), "Поднимитесь")
	assert_string_contains("\n".join(DayText.today(state)), "поместье")
	var missed := state.event_log.record(EventLog.RENT_MISSED, 0.0, PackedStringArray([Rent.LORD_ACTOR]), {"amount": 1500, "money": 0, "missed": 1, "evict_after": 3, "promised": true})
	assert_string_contains(UiText.announcement(missed, state), "прождал")


# --- the scenes

func _calm_game(money: int) -> void:
	var config := _calm(money)
	config.day = _balance.day
	Game.sim = SimState.new(config, 42)
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func _open_field() -> Level:
	var level := (load(FIELD_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _answer_rent_banner(level: Level) -> void:
	assert_true(level.hud.alert_banner.topics().has(Alert.RENT_CALL), "the lord rings first")
	level.hud._on_alert_action(Alert.RENT_CALL)
	await wait_process_frames(2)


func test_the_call_opens_by_itself_and_paying_now_reaches_the_sim() -> void:
	_calm_game(5000)
	_advance_hours(Game.sim, _call_hour() + 0.25)
	var level := await _open_field()
	await wait_process_frames(3)
	await _answer_rent_banner(level)
	var box := level.hud.dialogue_box
	assert_true(level.hud.is_dialogue_open(), "answering the banner opens the call")
	box.skip()
	assert_eq(box.choice_buttons().size(), 2)
	box.choice_buttons()[0].pressed.emit()
	assert_eq(Game.sim.event_log.of_type(EventLog.RENT_PAID).size(), 1)
	assert_eq(Game.sim.economy.money, 5000 - _balance.rent.amount)
	assert_true(level.hud.is_dialogue_open(), "the lord says thank you")


func test_short_of_money_jack_promises_to_visit_and_pays_at_the_manor() -> void:
	_calm_game(300)
	_advance_hours(Game.sim, _call_hour() + 0.25)
	var level := await _open_field()
	await wait_process_frames(3)
	await _answer_rent_banner(level)
	var box := level.hud.dialogue_box
	box.skip()
	assert_true(box.choice_buttons()[0].disabled, "paying now is greyed out")
	box.choice_buttons()[1].pressed.emit()
	assert_true(Game.sim.rent.visit_promised())
	box.skip()
	await wait_process_frames(2)
	assert_false(level.hud.is_dialogue_open())
	assert_string_contains(level.hud.objective_label.text, "поместье")
	Game.sim.economy.earn(_balance.rent.amount)
	(level.get_node("NavRegion/Lord") as LordAshcombe).interact(level)
	assert_true(level.hud.is_dialogue_open())
	box.skip()
	assert_false(box.choice_buttons()[0].disabled)
	box.choice_buttons()[0].pressed.emit()
	var paid := Game.sim.event_log.of_type(EventLog.RENT_PAID)
	assert_eq(paid.size(), 1)
	assert_eq(String(paid[0].data["where"]), Rent.AT_MANOR)
	assert_false(Game.sim.rent.visit_promised())
