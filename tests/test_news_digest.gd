extends GutTest


func test_ripe_beds_compress_into_one_line() -> void:
	var state := SimState.new(load("res://content/balance.tres") as BalanceConfig, 1)
	var events: Array[SimEvent] = []
	for plot_id: int in [0, 2, 4]:
		events.append(SimEvent.new(EventLog.PLOT_STAGE_CHANGED, 0.0, PackedStringArray(), {
			"plot_id": plot_id,
			"stage": Plot.stage_name(Plot.Stage.READY),
		}))
	var lines := NewsDigest.compress(events, state)
	assert_eq(lines.size(), 1)
	assert_string_contains(lines[0], "Созрели грядки")
	assert_string_contains(lines[0], "1")
	assert_string_contains(lines[0], "3")
	assert_string_contains(lines[0], "5")


func test_non_routine_news_still_passes_through() -> void:
	var state := SimState.new(load("res://content/balance.tres") as BalanceConfig, 1)
	var events: Array[SimEvent] = [
		SimEvent.new(EventLog.PLOT_STAGE_CHANGED, 0.0, PackedStringArray(), {
			"plot_id": 0,
			"stage": Plot.stage_name(Plot.Stage.READY),
		}),
		SimEvent.new(EventLog.ORDER_PAID, 0.0, PackedStringArray(), {"order_id": 1, "reward": 100, "fee": 0}),
	]
	var lines := NewsDigest.compress(events, state)
	assert_gte(lines.size(), 2)
	assert_string_contains(lines[0], "созрел")


func test_manor_summons_rings_like_a_call() -> void:
	var state := SimState.new(load("res://content/balance.tres") as BalanceConfig, 1)
	var story := state.stories.find("lord_advance")
	assert_not_null(story)
	state.stories.start(story, 0.0, "director")
	var alert := Alert.from_event(state.event_log.last(), state)
	assert_not_null(alert)
	assert_eq(alert.topic, Alert.SUMMONS)
	assert_eq(alert.action, Alert.ANSWER)
	assert_true(alert.sticky)


func test_rent_call_rings_on_the_banner() -> void:
	var state := SimState.new(load("res://content/balance.tres") as BalanceConfig, 1)
	var event := state.event_log.record(EventLog.RENT_CALLED, 0.0, PackedStringArray(), {"amount": 100})
	var alert := Alert.from_event(event, state)
	assert_eq(alert.topic, Alert.RENT_CALL)
	assert_eq(alert.action, Alert.ANSWER)


func test_bribing_cancels_a_pending_inspection() -> void:
	var config := (load("res://content/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = 5000
	config.first_day = null
	var state := SimState.new(config, 1)
	state.suspicion.inspection_at = state.clock.elapsed_game_seconds + 1000.0
	var cost := state.config.suspicion.bribe_cost
	var money := state.economy.money
	assert_true(state.apply(PrepareInspectionCommand.new(PrepareInspectionCommand.BRIBE)).ok)
	assert_false(state.suspicion.inspection_pending())
	assert_eq(state.economy.money, money - cost)
	assert_eq(state.event_log.of_type(EventLog.INSPECTION_BRIBED).size(), 1)
