extends GutTest

## Playtest 5: a longer day, Reggie's evening call that waits for an answer, and a night at home
## that is worth coming home for.

const BALANCE_PATH: String = "res://content/balance.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const HOME_SCENE: String = "res://scenes/home/home.tscn"
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


func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = 1000
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	config.suspicion.decay_per_hour = 0.0
	config.first_day = null
	config.director = null
	config.rent = null
	return config


func _advance_to_hour(state: SimState, hour: float) -> void:
	var target := float(state.clock.day()) * SimClock.GAME_SECONDS_PER_DAY + hour * HOUR
	if target <= state.clock.elapsed_game_seconds:
		target += SimClock.GAME_SECONDS_PER_DAY
	while state.clock.elapsed_game_seconds < target - 0.001:
		var hours := minf(0.25, (target - state.clock.elapsed_game_seconds) / HOUR)
		state.apply(AdvanceTimeCommand.new(hours * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


func _calm_game() -> void:
	Game.sim = SimState.new(_config(), 42)
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


## A home night after the first one: Jack is at home at 22:00 on day 1 and goes to bed.
func _night_at_home(state: SimState, suspicion: float) -> CommandResult:
	state.apply(TravelCommand.new(DayCycle.HOME))
	_advance_to_hour(state, 22.5)
	state.suspicion.add(suspicion)
	return state.apply(SleepCommand.new())


# --- task 2: a longer day and a later call

func test_the_working_day_is_longer_and_reggie_calls_later() -> void:
	var day := _balance.day
	assert_gte(day.evening_hour, 21.5, "playtest 5: the call came when the day had barely started")
	assert_gte(day.evening_hour - day.wake_hour, 15.0, "at least fifteen waking hours before the call")
	assert_gte(day.late_hour - day.evening_hour, 1.0, "an hour to get home before the night counts")


func test_reggies_evening_call_is_sticky() -> void:
	var sim := SimState.new(_config(), 1)
	var call := Alert.from_event(sim.event_log.record(EventLog.EVENING_CALL, 0.0, PackedStringArray(), {"place": DayCycle.FARM}), sim)
	assert_true(call.sticky, "the call stays until Jack answers or waves it away")
	assert_eq(call.action, Alert.GO_HOME)


func test_the_evening_banner_waits_until_dismissed() -> void:
	_calm_game()
	var level := await _open(FIELD_SCENE)
	_advance_to_hour(Game.sim, Game.sim.config.day.evening_hour + 0.1)
	await wait_process_frames(3)
	var banner := level.hud.alert_banner
	assert_true(banner.topics().has(Alert.HOME))
	banner._process(120.0)
	assert_true(banner.topics().has(Alert.HOME), "two real minutes later Reggie is still on the line")
	var dismiss: Button = null
	for node: Node in banner.find_child("Alert_" + Alert.HOME, true, false).find_children("*", "Button", true, false):
		if (node as Button).text == "Понял":
			dismiss = node as Button
	assert_not_null(dismiss)
	dismiss.pressed.emit()
	assert_false(banner.topics().has(Alert.HOME))


func test_the_evening_banner_goes_once_jack_is_on_the_way_home() -> void:
	_calm_game()
	var level := await _open(FIELD_SCENE)
	_advance_to_hour(Game.sim, Game.sim.config.day.evening_hour + 0.1)
	await wait_process_frames(3)
	assert_true(level.hud.alert_banner.topics().has(Alert.HOME))
	Game.sim.apply(TravelCommand.new(DayCycle.HOME))
	await wait_process_frames(2)
	assert_false(level.hud.alert_banner.topics().has(Alert.HOME))


# --- task 3: a night at home pays

func test_home_night_content_is_sane() -> void:
	var day := _balance.day
	assert_gt(day.home_night_suspicion_relief, 0.0)
	assert_lt(day.home_night_suspicion_relief, day.late_suspicion_per_hour * 6.0, "a bonus, not an amnesty")
	assert_gt(day.home_night_money, 0)
	assert_lt(float(day.home_night_money), _balance.rent.amount * 0.1, "pocket money, not a business")


func test_a_night_at_home_lowers_suspicion_and_brings_a_small_bonus() -> void:
	var config := _config()
	# Reggie's wage would blur the arithmetic.
	config.helper = null
	var state := SimState.new(config, 1)
	var money := state.economy.money
	assert_true(_night_at_home(state, 20.0).ok)
	var def := state.config.day
	var nights := state.event_log.of_type(EventLog.HOME_NIGHT)
	assert_eq(nights.size(), 1)
	assert_almost_eq(state.suspicion.level, 20.0 - def.home_night_suspicion_relief, 0.001)
	assert_eq(state.economy.money, money + def.home_night_money)
	assert_almost_eq(float(nights[0].data["suspicion_relief"]), def.home_night_suspicion_relief, 0.001)
	assert_eq(int(nights[0].data["bonus"]), def.home_night_money)
	assert_eq(int(nights[0].data["money"]), state.economy.money)
	assert_almost_eq(nights[0].game_time, state.clock.elapsed_game_seconds, 0.001, "it comes with the morning")


func test_relief_never_takes_suspicion_below_zero() -> void:
	var state := SimState.new(_config(), 1)
	_night_at_home(state, 1.0)
	assert_eq(state.suspicion.level, 0.0)
	assert_almost_eq(float(state.event_log.of_type(EventLog.HOME_NIGHT)[0].data["suspicion_relief"]), 1.0, 0.001)


func test_a_night_away_gets_no_bonus_and_keeps_its_penalty() -> void:
	var state := SimState.new(_config(), 1)
	_advance_to_hour(state, 22.5)
	_advance_to_hour(state, state.config.day.wake_hour + 0.5)
	assert_eq(state.event_log.of_type(EventLog.HOME_NIGHT).size(), 0)
	assert_gt(state.suspicion.level, 0.0, "the farm lights were noticed")


func test_the_prologue_night_is_not_a_night_at_home() -> void:
	var state := SimState.new(_config(), 1)
	state.apply(TravelCommand.new(DayCycle.HOME))
	assert_true(state.apply(SleepCommand.new()).ok)
	assert_eq(state.event_log.of_type(EventLog.HOME_NIGHT).size(), 0, "the game opens at midnight; that night is the prologue's")


func test_an_alarm_that_drags_jack_to_the_farm_spoils_the_night() -> void:
	var config := _config()
	config.raids.chance_per_night = 1.0
	var state := SimState.new(config, 2)
	state.inventory.create(config.strain.id, 60)
	state.apply(TravelCommand.new(DayCycle.HOME))
	_advance_to_hour(state, 22.5)
	var result := state.apply(SleepCommand.new())
	assert_ne(result.value, -1)
	state.apply(TravelCommand.new(DayCycle.FARM))
	_advance_to_hour(state, config.day.wake_hour + 0.5)
	assert_eq(state.event_log.of_type(EventLog.HOME_NIGHT).size(), 0)


func test_the_briefing_says_what_the_night_gave() -> void:
	var state := SimState.new(_config(), 1)
	var slept_from := state.clock.elapsed_game_seconds
	_night_at_home(state, 20.0)
	var lines := "\n".join(DayText.home_night(state, slept_from, state.clock.elapsed_game_seconds))
	assert_string_contains(lines, "одозрение −%d" % roundi(state.config.day.home_night_suspicion_relief))
	assert_string_contains(lines, UiText.money(state.config.day.home_night_money))
	var away := SimState.new(_config(), 1)
	assert_eq(DayText.home_night(away, 0.0, away.clock.elapsed_game_seconds).size(), 0)


func test_the_bonus_is_in_the_money_ledger() -> void:
	var state := SimState.new(_config(), 1)
	_night_at_home(state, 0.0)
	var night := state.event_log.of_type(EventLog.HOME_NIGHT)[0]
	var entries := MoneyLedger.of_event(night, state)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].amount, state.config.day.home_night_money)


func test_vivienne_has_a_different_word_on_different_mornings() -> void:
	var state := SimState.new(_config(), 1)
	Game.sim = state
	_night_at_home(state, 0.0)
	var first := Vivienne.morning_lines(state.event_log.of_type(EventLog.HOME_NIGHT)[0])
	assert_between(first.size(), 1, 2)
	assert_eq(first[0].speaker, UiText.VIVIENNE)
	_advance_to_hour(state, 22.5)
	state.apply(SleepCommand.new())
	var second := Vivienne.morning_lines(state.event_log.of_type(EventLog.HOME_NIGHT)[1])
	assert_ne(first[0].text, second[0].text, "gossip changes overnight")


func test_after_the_briefing_vivienne_has_a_word_over_breakfast() -> void:
	_calm_game()
	Game.sim.apply(TravelCommand.new(DayCycle.HOME))
	_advance_to_hour(Game.sim, 22.5)
	Game.sim.suspicion.add(20.0)
	var level := await _open(HOME_SCENE)
	(level.get_node("NavRegion/Bed") as Bed).interact(level)
	var night := level.hud.night
	assert_true(night.is_open())
	assert_eq(night.page(), NightFlow.PAGE_SUMMARY)
	while night.is_open() and night.page() != NightFlow.PAGE_BRIEFING:
		night.turn_page()
	assert_eq(night.page(), NightFlow.PAGE_BRIEFING)
	assert_string_contains(night.card.body_text(), "Ночь дома")
	assert_string_contains(night.card.body_text(), "одозрение −")
	night.turn_page()
	assert_false(night.is_open())
	assert_true(level.hud.is_dialogue_open(), "Vivienne speaks over breakfast")
	assert_eq(level.hud.dialogue_box.current_line().speaker, UiText.VIVIENNE)


func test_vivienne_keeps_to_the_rooms_by_the_clock() -> void:
	_calm_game()
	Game.sim.apply(TravelCommand.new(DayCycle.HOME))
	_advance_to_hour(Game.sim, 8.0)
	assert_eq(Vivienne.room_for(Game.sim), Vivienne.BREAKFAST)
	_advance_to_hour(Game.sim, 14.0)
	assert_eq(Vivienne.room_for(Game.sim), Vivienne.STUDY)
	_advance_to_hour(Game.sim, Game.sim.config.day.evening_hour + 0.1)
	assert_eq(Vivienne.room_for(Game.sim), Vivienne.FIRESIDE)
	_advance_to_hour(Game.sim, Game.sim.config.day.late_hour + 0.1)
	assert_eq(Vivienne.room_for(Game.sim), Vivienne.BEDROOM)
	var level := await _open(HOME_SCENE)
	var her := level.get_node("NavRegion/Vivienne") as Vivienne
	assert_not_null(her.spots)
	assert_not_null(her.spot(Vivienne.BEDROOM))
	assert_eq(her.room, Vivienne.BEDROOM)
	assert_not_null(level.find_child("ClueBoard", true, false), "the cork board hangs in the study")
