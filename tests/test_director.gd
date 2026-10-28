extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25
const EPSILON: float = 0.001

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


## The director alone; only_kind keeps a single kind of event in play.
func _config(only_kind: String = "", quiet_real_seconds: float = -1.0) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.first_day = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	var director := _balance.director.duplicate() as DirectorDef
	if quiet_real_seconds > 0.0:
		director.quiet_real_seconds = quiet_real_seconds
	if not only_kind.is_empty():
		director.urgent_order_weight = 1.0 if only_kind == Director.URGENT_ORDER else 0.0
		director.lord_visit_weight = 1.0 if only_kind == Director.LORD_VISIT else 0.0
		director.rumour_weight = 1.0 if only_kind == Director.RUMOUR else 0.0
		director.breakdown_weight = 1.0 if only_kind == Director.BREAKDOWN else 0.0
		director.courier_trouble_weight = 1.0 if only_kind == Director.COURIER_TROUBLE else 0.0
		director.story_weight = 1.0 if only_kind == Director.STORY else 0.0
	config.director = director
	return config


func _real(hours: float, state: SimState) -> float:
	return hours * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(STEP_HOURS, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(_real(step, state)))
		elapsed += step


func _quiet_hours(state: SimState) -> float:
	return state.director.quiet_seconds() / HOUR


func _director_events(state: SimState) -> Array[SimEvent]:
	return state.event_log.of_type(EventLog.DIRECTOR_EVENT)


func test_content_is_sane() -> void:
	var def := _balance.director
	assert_not_null(def, "balance.tres carries the director")
	assert_almost_eq(def.quiet_real_seconds, 90.0, 30.0, "about a minute and a half of quiet")
	for kind: String in Director.KINDS:
		assert_gt(def.weight(kind), 0.0, "%s can happen" % kind)
	var ids: Array[String] = []
	var village := 0
	for story: StoryDef in def.stories:
		assert_false(ids.has(story.id), "story ids are unique: %s" % story.id)
		ids.append(story.id)
		assert_ne(story.kind, StoryDef.SCRIPT, "script stories stay out of the director's pool")
		if story.kind == StoryDef.VILLAGE:
			village += 1
	assert_gte(def.stories.size(), 5)
	assert_gte(village, 4)
	assert_false(def.notable_events.has(EventLog.ORDER_RECEIVED), "routine calls do not count as something happening")
	assert_false(def.notable_events.has(EventLog.ORDER_MISSED), "neither do calls that ring out")


func test_a_quiet_farm_gets_an_event_after_the_quiet_spell() -> void:
	var state := SimState.new(_config(Director.URGENT_ORDER), 4)
	var quiet := _quiet_hours(state)
	_advance(state, quiet - STEP_HOURS)
	assert_eq(_director_events(state).size(), 0)
	_advance(state, STEP_HOURS * 2.0)
	assert_eq(_director_events(state).size(), 1)
	assert_almost_eq(_director_events(state)[0].game_time, quiet * HOUR, EPSILON)


## Over the first day, up to the quiet hours: an urgent caller at night waits for the morning (test_playtest6_sim).
func test_never_quiet_for_longer_than_the_spell() -> void:
	var state := SimState.new(_config(Director.URGENT_ORDER), 4)
	_advance(state, state.config.orders.quiet_from_hour)
	var director := state.config.director
	var times: Array[float] = [0.0]
	for event: SimEvent in state.event_log.entries():
		if Director.ALWAYS_NOTABLE.has(event.type) or director.notable_events.has(event.type):
			times.append(event.game_time)
	var quiet := state.director.quiet_seconds()
	for index: int in range(1, times.size()):
		assert_lte(times[index] - times[index - 1], quiet + EPSILON, "gap before event %d" % index)
	var events := _director_events(state)
	assert_gt(events.size(), 5)
	for index: int in range(1, events.size()):
		assert_gte(events[index].game_time - events[index - 1].game_time, quiet - EPSILON, "the director never fires twice in one quiet spell")


func test_something_notable_restarts_the_quiet_clock() -> void:
	var state := SimState.new(_config(Director.URGENT_ORDER), 4)
	var quiet := _quiet_hours(state)
	state.apply(PlantCommand.new(0))
	state.apply(WaterCommand.new(0))
	_advance(state, 2.0)
	state.problems.force(0, Problems.MOLD, state.clock.elapsed_game_seconds)
	_advance(state, quiet - 1.0)
	assert_eq(_director_events(state).size(), 0, "a bed problem counts as something happening")
	_advance(state, 2.0 + STEP_HOURS)
	assert_eq(_director_events(state).size(), 1)
	assert_almost_eq(_director_events(state)[0].game_time, (2.0 + quiet) * HOUR, EPSILON)


func test_it_waits_while_a_story_waits_for_an_answer() -> void:
	var state := SimState.new(_config(Director.STORY), 4)
	var quiet := _quiet_hours(state)
	_advance(state, quiet + STEP_HOURS)
	assert_true(state.stories.is_pending())
	_advance(state, quiet * 4.0)
	assert_eq(_director_events(state).size(), 1, "one story at a time")
	assert_true(state.apply(ChooseCommand.new(state.stories.pending_id, 1)).ok)
	_advance(state, quiet + STEP_HOURS)
	assert_eq(_director_events(state).size(), 2)
	assert_ne(String(_director_events(state)[1].data["story_id"]), String(_director_events(state)[0].data["story_id"]), "a story is told once")


func test_urgent_order_has_a_short_fuse_and_a_bonus() -> void:
	var state := SimState.new(_config(Director.URGENT_ORDER, 10.0), 4)
	_advance(state, _quiet_hours(state) + STEP_HOURS)
	var urgent := state.orders.all().filter(func(order: Order) -> bool: return order.urgent)
	assert_eq(urgent.size(), 1)
	var order := urgent[0] as Order
	var def := state.config.director
	var usual := float(order.quantity * Economy.price_with(state.orders.price_strain(order.strain_id), order.min_quality)) * state.config.orders.reward_multiplier
	assert_gt(float(order.reward), usual * 1.5)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	assert_almost_eq(order.deadline - state.clock.elapsed_game_seconds, def.urgent_deadline_hours * HOUR, EPSILON)


func test_lord_visit_and_village_story_start_a_choice() -> void:
	var lord := SimState.new(_config(Director.LORD_VISIT, 10.0), 4)
	_advance(lord, _quiet_hours(lord) + STEP_HOURS)
	assert_eq(lord.stories.pending().kind, StoryDef.LORD)
	var village := SimState.new(_config(Director.STORY, 10.0), 4)
	_advance(village, _quiet_hours(village) + STEP_HOURS)
	assert_eq(village.stories.pending().kind, StoryDef.VILLAGE)


func test_rumour_warns_of_an_inspection_when_the_farm_is_hot() -> void:
	var state := SimState.new(_config(Director.RUMOUR, 10.0), 4)
	state.suspicion.level = 50.0
	_advance(state, _quiet_hours(state) + STEP_HOURS)
	assert_true(state.suspicion.inspection_pending(), "the tip-off comes true")
	assert_eq(String(_director_events(state)[0].data["about"]), Director.ABOUT_INSPECTION)


func test_rumour_about_raiders_makes_the_next_night_certain() -> void:
	var state := SimState.new(_config(Director.RUMOUR, 10.0), 4)
	state.inventory.create(state.config.strain.id, 50)
	_advance(state, _quiet_hours(state) + STEP_HOURS)
	assert_true(state.raids.expected)
	assert_eq(String(_director_events(state)[0].data["about"]), Director.ABOUT_RAID)
	_advance(state, state.raids.next_roll_at / HOUR - state.clock.elapsed_game_seconds / HOUR + STEP_HOURS)
	assert_eq(state.event_log.of_type(EventLog.RAID_STARTED).size(), 1, "Reggie heard right")


func test_rumours_about_raiders_need_raids_in_the_game() -> void:
	var config := _config(Director.RUMOUR, 10.0)
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	var state := SimState.new(config, 4)
	_advance(state, _quiet_hours(state) * 3.0)
	assert_eq(_director_events(state).size(), 0, "nothing to whisper about")


func test_breakdown_burns_out_a_lamp_on_a_growing_bed() -> void:
	var state := SimState.new(_config(Director.BREAKDOWN, 10.0), 4)
	state.apply(PlantCommand.new(2))
	_advance(state, _quiet_hours(state) + STEP_HOURS)
	assert_eq(state.grow.plot(2).problem, Problems.LAMP)


func test_courier_trouble_holds_up_the_delivery_and_reggie() -> void:
	var state := SimState.new(_config(Director.COURIER_TROUBLE, 10.0), 4)
	var order := state.orders.inject(1, 0, 100, 5.0, 0.0, false, 0.0)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	state.inventory.create(state.config.strain.id, 50).packed = true
	assert_true(state.apply(DispatchCommand.new(order.id, Helper.ACTOR)).ok)
	var arrives := order.arrives_at
	_advance(state, _quiet_hours(state) + STEP_HOURS)
	var hours := state.config.director.courier_delay_hours
	assert_almost_eq(order.arrives_at, arrives + hours * HOUR, EPSILON)
	assert_gte(state.helper.away_until, order.arrives_at, "Reggie comes back after the parcel arrives")


func test_nothing_applicable_means_no_event() -> void:
	var state := SimState.new(_config(Director.COURIER_TROUBLE, 10.0), 4)
	_advance(state, _quiet_hours(state) * 3.0)
	assert_eq(_director_events(state).size(), 0)


func test_one_big_step_equals_many_small_steps() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.first_day = null
	var big := SimState.new(config, 31)
	var small := SimState.new(config, 31)
	for state: SimState in [big, small]:
		state.apply(PlantCommand.new(0))
		state.apply(PlantCommand.new(1))
		state.inventory.create(state.config.strain.id, 50)
	big.apply(AdvanceTimeCommand.new(_real(60.0, big)))
	_advance(small, 60.0)
	assert_gt(_director_events(big).size(), 0)
	assert_eq(JSON.stringify(big.event_log.to_array()), JSON.stringify(small.event_log.to_array()))
	assert_eq(big.to_json(), small.to_json())


func test_save_and_load_keep_the_cadence() -> void:
	var state := SimState.new(_config(Director.URGENT_ORDER), 6)
	_advance(state, 2.0)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	_advance(state, 20.0)
	_advance(loaded, 20.0)
	assert_eq(loaded.to_json(), state.to_json())
