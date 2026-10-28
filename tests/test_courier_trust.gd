extends GutTest

## Playtest round 4: who still drives for Jack after the rat hunt, and what a thief costs.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(pete_greed: float = -1.0) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = 5000
	config.first_day = null
	config.director = null
	config.helper = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.orders = _balance.orders.duplicate() as OrdersDef
	config.orders.base_trip_risk = 0.0
	if pete_greed >= 0.0:
		var couriers: Array[CourierDef] = []
		for courier: CourierDef in _balance.courier_candidates:
			var copy := courier.duplicate() as CourierDef
			if copy.id == "pete":
				copy.greed = pete_greed
			couriers.append(copy)
		config.courier_candidates = couriers
	return config


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(STEP_HOURS, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		elapsed += step


func _raid(state: SimState) -> void:
	for person: SuspectDef in state.config.intrigue.suspects:
		if not person.courier_id.is_empty() and not state.couriers.hired.has(person.courier_id):
			assert_true(state.apply(HireCourierCommand.new(person.courier_id)).ok)
		if person.intro_story != null and not state.stories.used.has(person.intro_story.id):
			state.stories.used.append(person.intro_story.id)
	state.raids.pending = true
	state.raids.deadline = state.clock.elapsed_game_seconds + HOUR
	assert_true(state.apply(RaidCommand.new(Raids.PAY)).ok)


func _pete_index(state: SimState) -> int:
	for index: int in state.config.intrigue.suspects.size():
		if state.config.intrigue.suspects[index].courier_id == "pete":
			return index
	return -1


## Straight to the accusation: Jack pays the gang's boss for the name.
func _accuse(state: SimState, rat: int, accused: int) -> void:
	_raid(state)
	state.intrigue.rat = rat
	assert_true(state.apply(ChooseCommand.new(state.config.intrigue.opening_story.id, IntrigueDef.PAY_BOSS)).ok)
	assert_true(state.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, accused)).ok)


## Pete takes an order and is on the road with it.
func _send_pete(state: SimState) -> Order:
	_advance(state, state.config.orders.first_order_hours + STEP_HOURS)
	var order := state.orders.all()[0]
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	var strain_id := order.strain_id if not order.strain_id.is_empty() else state.config.strain.id
	for unit: int in order.quantity:
		state.inventory.create(strain_id, 100).packed = true
	assert_true(state.apply(DispatchCommand.new(order.id, "pete")).ok)
	return order


func _theft_story_id() -> String:
	return CourierThefts.STORY_PREFIX + "pete"


# --- 2. "the news said Pete no longer works for us, but he still did"

func test_a_proven_rat_loses_the_job_even_while_out_on_a_delivery() -> void:
	var state := SimState.new(_config(0.0), 2)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	_send_pete(state)
	var pete := _pete_index(state)
	_accuse(state, pete, pete)
	assert_false(state.couriers.hired.has("pete"), "the reply says he no longer works for Jack")
	var fired := state.event_log.of_type(EventLog.COURIER_FIRED)
	assert_eq(fired.size(), 1)
	assert_eq(String(fired[0].data["reason"]), Couriers.REASON_RAT)
	assert_eq(state.apply(HireCourierCommand.new("pete")).error, CommandResult.COURIER_BANNED, "nobody hires the rat twice")


func test_a_proven_rat_who_never_drove_for_jack_is_still_never_hired() -> void:
	var state := SimState.new(_config(), 2)
	var pete := _pete_index(state)
	_accuse(state, pete, pete)
	assert_eq(state.event_log.of_type(EventLog.COURIER_FIRED).size(), 1, "hired for the hunt, fired as the rat — never drove a load")
	assert_eq(state.apply(HireCourierCommand.new("pete")).error, CommandResult.COURIER_BANNED)


func test_wrongly_accused_pete_walks_out_like_the_story_says() -> void:
	var state := SimState.new(_config(), 2)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	var pete := _pete_index(state)
	_accuse(state, (pete + 1) % state.config.intrigue.suspects.size(), pete)
	assert_false(state.couriers.hired.has("pete"), "«ушёл, хлопнув дверью» means he is gone")
	assert_eq(state.event_log.of_type(EventLog.COURIER_QUIT).size(), 1)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok, "offended, not banned: he can be begged back")


func test_accusing_someone_else_leaves_pete_at_work() -> void:
	var state := SimState.new(_config(), 2)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	var pete := _pete_index(state)
	var other := (pete + 1) % state.config.intrigue.suspects.size()
	_accuse(state, other, other)
	assert_true(state.couriers.hired.has("pete"))
	assert_eq(state.event_log.of_type(EventLog.COURIER_QUIT).size(), 0)
	assert_eq(state.event_log.of_type(EventLog.COURIER_FIRED).size(), 0)


func test_the_news_matches_who_still_drives() -> void:
	var state := SimState.new(_config(), 2)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	var pete := _pete_index(state)
	_accuse(state, pete, pete)
	var fired := state.event_log.of_type(EventLog.COURIER_FIRED)[0]
	assert_string_contains(UiText.announcement(fired, state), "Пит")
	assert_string_contains(UiText.announcement(fired, state), "больше не работает")


# --- 3. "a courier who stole is hired again like nothing happened"

func test_a_thief_is_never_hired_again() -> void:
	var state := SimState.new(_config(1.0), 3)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	_send_pete(state)
	_advance(state, state.couriers.trip_seconds("pete") / HOUR + STEP_HOURS)
	assert_eq(state.event_log.of_type(EventLog.COURIER_STOLE).size(), 1)
	assert_false(state.couriers.hired.has("pete"))
	assert_true(state.couriers.is_banned("pete"))
	assert_eq(state.apply(HireCourierCommand.new("pete")).error, CommandResult.COURIER_BANNED)


func test_reggie_calls_about_the_thief_and_jack_decides() -> void:
	var state := SimState.new(_config(1.0), 3)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	_send_pete(state)
	_advance(state, state.couriers.trip_seconds("pete") / HOUR + STEP_HOURS)
	assert_eq(state.stories.pending_id, _theft_story_id())
	var story := state.stories.pending()
	assert_eq(story.choices.size(), 2, "have a word, or let it go")
	assert_gt(story.choices[CourierThefts.HAVE_A_WORD].cost(), 0, "Reggie's word costs money")
	assert_gt(story.choices[CourierThefts.LET_GO].suspicion, 0.0, "a thief left alone talks")
	for line: DialogueLineDef in story.lines:
		assert_false(line.text.contains("%s"), "the thief's name is filled in")
	assert_string_contains(story.lines[0].text + story.lines[1].text, "Пит")


func test_letting_a_thief_go_raises_suspicion_and_having_a_word_does_not() -> void:
	for choice: int in [CourierThefts.HAVE_A_WORD, CourierThefts.LET_GO]:
		var state := SimState.new(_config(1.0), 3)
		assert_true(state.apply(HireCourierCommand.new("pete")).ok)
		_send_pete(state)
		_advance(state, state.couriers.trip_seconds("pete") / HOUR + STEP_HOURS)
		var money := state.economy.money
		var suspicion := state.suspicion.level
		assert_true(state.apply(ChooseCommand.new(_theft_story_id(), choice)).ok)
		if choice == CourierThefts.HAVE_A_WORD:
			assert_lt(state.economy.money, money)
			assert_almost_eq(state.suspicion.level, suspicion, 0.001)
		else:
			assert_eq(state.economy.money, money)
			assert_gt(state.suspicion.level, suspicion)


func test_reggie_waits_for_the_story_on_screen() -> void:
	var state := SimState.new(_config(1.0), 3)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	_send_pete(state)
	var other := StoryDef.new()
	other.id = "on_screen"
	var choice := StoryChoiceDef.new()
	choice.label = "ok"
	other.choices = [choice] as Array[StoryChoiceDef]
	state.stories.register(other)
	assert_true(state.stories.start(other, state.clock.elapsed_game_seconds, "test"))
	_advance(state, state.couriers.trip_seconds("pete") / HOUR + STEP_HOURS)
	assert_eq(state.stories.pending_id, "on_screen")
	assert_true(state.apply(ChooseCommand.new("on_screen", 0)).ok)
	assert_eq(state.stories.pending_id, _theft_story_id())


func test_save_and_load_keep_the_ban_and_the_call() -> void:
	var state := SimState.new(_config(1.0), 3)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	_send_pete(state)
	_advance(state, state.couriers.trip_seconds("pete") / HOUR + STEP_HOURS)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_true(loaded.couriers.is_banned("pete"))
	assert_eq(loaded.stories.pending_id, _theft_story_id())
	assert_not_null(loaded.stories.pending(), "the built story comes back")
	assert_true(loaded.apply(ChooseCommand.new(_theft_story_id(), CourierThefts.LET_GO)).ok)
	assert_eq(loaded.to_json(), _resolved_copy(state).to_json())


func _resolved_copy(state: SimState) -> SimState:
	state.apply(ChooseCommand.new(_theft_story_id(), CourierThefts.LET_GO))
	return state


func test_couriers_rarely_vanish_and_the_cheap_one_is_the_risk() -> void:
	var by_id: Dictionary[String, CourierDef] = {}
	for courier: CourierDef in _balance.courier_candidates:
		by_id[courier.id] = courier
		var vanish_in_ten := 1.0 - pow(1.0 - courier.greed, 10.0)
		assert_lt(vanish_in_ten, 0.3, "%s keeps most of ten parcels" % courier.id)
		var stopped := _balance.orders.base_trip_risk * (1.0 - courier.reliability)
		assert_lt(stopped, 0.06, "%s is rarely stopped on a quiet road" % courier.id)
	assert_gt(by_id["pete"].greed, by_id["harry"].greed, "the cheap one is the greedy one")
	assert_gt(by_id["harry"].greed, by_id["frank"].greed)
	assert_gt(by_id["frank"].reliability, by_id["harry"].reliability, "careful Frank is stopped less than fast Harry")
