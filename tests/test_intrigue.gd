extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY
const STEP_HOURS: float = 0.25

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 2000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	return config


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(STEP_HOURS, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		elapsed += step


## Jack already knows everyone on the list, so the hunt starts without introductions.
func _meet_suspects(state: SimState) -> void:
	for person: SuspectDef in state.config.intrigue.suspects:
		if not person.courier_id.is_empty() and not state.couriers.hired.has(person.courier_id):
			assert_true(state.apply(HireCourierCommand.new(person.courier_id)).ok, "courier suspects must be on the books")
		if person.intro_story != null and not state.stories.used.has(person.intro_story.id):
			state.stories.used.append(person.intro_story.id)


## The gang turns up and Jack pays them off: the raid is over and the questions begin.
func _raid(state: SimState) -> void:
	_meet_suspects(state)
	state.raids.pending = true
	state.raids.deadline = state.clock.elapsed_game_seconds + HOUR
	assert_true(state.apply(RaidCommand.new(Raids.PAY)).ok)


func _opening_id(state: SimState) -> String:
	return state.config.intrigue.opening_story.id


func _investigate_to_the_end(state: SimState) -> void:
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	_advance(state, state.config.intrigue.clue_interval_hours * float(state.intrigue.schedule.size()) + STEP_HOURS)


func test_content_lays_fair_clues() -> void:
	var def := _balance.intrigue
	assert_not_null(def, "balance.tres carries the rat hunt")
	assert_eq(def.opening_story.choices.size(), 3, "investigate, pay the boss, retaliate")
	assert_gte(def.suspects.size(), 3)
	for person: SuspectDef in def.suspects:
		assert_false(person.alibi_clue.is_empty(), "%s can be cleared" % person.id)
		assert_false(person.herring_clue.is_empty(), "%s looks bad either way" % person.id)
		assert_gte(person.guilty_clues.size(), 1, "%s leaves a harmless-looking trace with his name" % person.id)
		assert_gte(person.trail_clues.size(), 1, "%s leaves a nameless trace at the raid" % person.id)
		assert_false(person.guilty_reply.is_empty())
		assert_false(person.innocent_reply.is_empty())
	assert_string_contains(def.boss_name_line, "%s")


func test_the_first_raid_opens_the_question() -> void:
	var state := SimState.new(_config(), 2)
	assert_eq(state.intrigue.phase, Intrigue.Phase.WAITING)
	_raid(state)
	assert_eq(state.intrigue.phase, Intrigue.Phase.OPENING)
	assert_eq(state.stories.pending_id, _opening_id(state), "Reggie shows the dropped phone")
	assert_not_null(state.intrigue.rat_suspect())
	assert_eq(state.event_log.of_type(EventLog.INTRIGUE_STARTED).size(), 1)


func test_investigation_brings_true_clues_and_ends_in_an_accusation() -> void:
	var state := SimState.new(_config(), 2)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	var interval := state.config.intrigue.clue_interval_hours
	_advance(state, interval - STEP_HOURS)
	assert_eq(state.event_log.of_type(EventLog.INTRIGUE_CLUE).size(), 0)
	_advance(state, interval * float(state.intrigue.schedule.size()))
	var clues := state.event_log.of_type(EventLog.INTRIGUE_CLUE)
	assert_eq(clues.size(), state.intrigue.schedule.size())
	var rat := state.intrigue.rat_suspect()
	var guilty := 0
	var herrings := 0
	var cleared: Array[String] = []
	for clue: SimEvent in clues:
		var parts := Intrigue.clue_parts(String(clue.data["clue"]))
		match parts[1]:
			Intrigue.GUILTY, Intrigue.TRAIL:
				assert_eq(parts[0], rat.id, "only the rat leaves real traces")
				guilty += 1
			Intrigue.HERRING:
				herrings += 1
			_:
				assert_ne(parts[0], rat.id, "the rat never gets an alibi")
				cleared.append(parts[0])
	assert_eq(guilty, rat.guilty_clues.size() + rat.trail_clues.size())
	assert_eq(herrings, state.config.intrigue.suspects.size(), "everyone, the rat included, has something that looks bad")
	assert_eq(cleared.size(), state.config.intrigue.suspects.size() - 1, "everyone else is cleared: the answer can be worked out")
	assert_eq(state.stories.pending_id, Intrigue.ACCUSE_STORY_ID)
	var accusation := state.stories.pending()
	assert_eq(accusation.choices.size(), state.config.intrigue.suspects.size() + 1, "every suspect and «nobody yet»")
	var recap := "\n".join(accusation.lines.map(func(line: DialogueLineDef) -> String: return line.text))
	for clue: SimEvent in clues:
		assert_string_contains(recap, state.intrigue.clue_text(String(clue.data["clue"])), "the accusation recaps every clue")


func test_naming_the_rat_buys_quiet_nights() -> void:
	var state := SimState.new(_config(), 2)
	state.suspicion.level = 40.0
	_investigate_to_the_end(state)
	var before := state.suspicion.level
	assert_true(state.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, state.intrigue.rat)).ok)
	assert_eq(state.intrigue.phase, Intrigue.Phase.DONE)
	assert_almost_eq(state.suspicion.level, before - state.config.intrigue.caught_relief, 0.001)
	assert_eq(state.stories.relation(Stories.CREW), state.config.intrigue.caught_crew)
	assert_almost_eq(state.raids.calm_until, state.clock.elapsed_game_seconds + state.config.intrigue.caught_calm_days * DAY, 0.001)
	var resolved := state.event_log.of_type(EventLog.INTRIGUE_RESOLVED)
	assert_eq(String(resolved[0].data["outcome"]), Intrigue.CAUGHT)


func test_blaming_an_innocent_brings_the_gang_back() -> void:
	var state := SimState.new(_config(), 2)
	_investigate_to_the_end(state)
	var innocent := (state.intrigue.rat + 1) % state.config.intrigue.suspects.size()
	assert_true(state.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, innocent)).ok)
	assert_true(state.raids.expected, "the real rat tips them off again")
	assert_eq(state.stories.relation(Stories.VILLAGE), state.config.intrigue.wrong_village)
	assert_eq(String(state.event_log.of_type(EventLog.INTRIGUE_RESOLVED)[0].data["outcome"]), Intrigue.WRONG)


func test_paying_the_boss_names_the_rat_at_once() -> void:
	var state := SimState.new(_config(), 2)
	_raid(state)
	var money := state.economy.money
	assert_true(state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.PAY_BOSS)).ok)
	assert_eq(state.economy.money, money - 300)
	assert_eq(state.stories.pending_id, Intrigue.ACCUSE_STORY_ID, "no investigation needed")
	var lines := state.stories.pending().lines
	assert_string_contains(lines[lines.size() - 1].text, state.intrigue.rat_suspect().display_name)
	assert_almost_eq(state.raids.calm_until, state.clock.elapsed_game_seconds + state.config.intrigue.paid_calm_days * DAY, 0.001)


func test_a_proven_rat_who_drives_for_jack_loses_the_job() -> void:
	var state := SimState.new(_config(), 2)
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	_raid(state)
	var pete := 0
	for index: int in state.config.intrigue.suspects.size():
		if state.config.intrigue.suspects[index].courier_id == "pete":
			pete = index
	state.intrigue.rat = pete
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.PAY_BOSS))
	state.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, pete))
	assert_false(state.couriers.hired.has("pete"))


func test_retaliation_is_a_gamble_with_real_stakes() -> void:
	var outcomes: Array[String] = []
	for seed_value: int in range(1, 15):
		var state := SimState.new(_config(), seed_value)
		_raid(state)
		state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.RETALIATE))
		var outcome := String(state.event_log.of_type(EventLog.INTRIGUE_RESOLVED)[0].data["outcome"])
		if outcome == Intrigue.RETALIATED:
			assert_gt(state.raids.calm_until, state.clock.elapsed_game_seconds)
		else:
			assert_eq(outcome, Intrigue.RETALIATION_FAILED)
			assert_true(state.raids.expected, "the gang promised to come back")
		outcomes.append(outcome)
	assert_true(outcomes.has(Intrigue.RETALIATED) and outcomes.has(Intrigue.RETALIATION_FAILED))


func test_quiet_nights_hold_off_raids() -> void:
	var config := _config()
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 1.0
	var state := SimState.new(config, 2)
	state.inventory.create(state.config.strain.id, 50)
	state.raids.calm(3.0 * DAY)
	_advance(state, 3.0 * 24.0 - 1.0)
	assert_eq(state.event_log.of_type(EventLog.RAID_STARTED).size(), 0)
	_advance(state, 24.0)
	assert_eq(state.event_log.of_type(EventLog.RAID_STARTED).size(), 1)


func test_the_arc_runs_once() -> void:
	var state := SimState.new(_config(), 2)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.RETALIATE))
	_raid(state)
	assert_false(state.stories.is_pending())
	assert_eq(state.event_log.of_type(EventLog.INTRIGUE_STARTED).size(), 1)


func test_a_story_on_screen_goes_first() -> void:
	var config := _config()
	config.director = _balance.director.duplicate() as DirectorDef
	config.director.quiet_real_seconds = 1000000.0
	var state := SimState.new(config, 2)
	state.stories.start(state.stories.find("hiker"), 0.0, Director.ACTOR)
	_raid(state)
	assert_eq(state.stories.pending_id, "hiker")
	state.apply(ChooseCommand.new("hiker", 0))
	assert_eq(state.stories.pending_id, _opening_id(state), "the phone comes out right after")


func _hunt(state: SimState, big_steps: bool) -> void:
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	if big_steps:
		state.apply(AdvanceTimeCommand.new(30.0 * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
	else:
		_advance(state, 30.0)


func test_one_big_step_equals_many_small_steps() -> void:
	var big := SimState.new(_balance, 41)
	var small := SimState.new(_balance, 41)
	for state: SimState in [big, small]:
		state.first_day.skip()
	_hunt(big, true)
	_hunt(small, false)
	assert_gt(big.event_log.of_type(EventLog.INTRIGUE_CLUE).size(), 0)
	assert_eq(JSON.stringify(big.event_log.to_array()), JSON.stringify(small.event_log.to_array()))
	assert_eq(big.to_json(), small.to_json())


func test_save_and_load_mid_hunt_and_mid_accusation() -> void:
	var state := SimState.new(_config(), 6)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	_advance(state, state.config.intrigue.clue_interval_hours * 1.5)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(loaded.intrigue.phase, Intrigue.Phase.INVESTIGATING)
	for copy: SimState in [state, loaded]:
		_advance(copy, copy.config.intrigue.clue_interval_hours * float(copy.intrigue.schedule.size()))
	assert_eq(loaded.to_json(), state.to_json())
	var accusing := SimState.from_json(state.to_json(), state.config)
	assert_eq(accusing.stories.pending_id, Intrigue.ACCUSE_STORY_ID)
	assert_eq(accusing.stories.pending().choices.size(), state.config.intrigue.suspects.size() + 1, "the question is rebuilt after a load")
	assert_true(accusing.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, accusing.intrigue.rat)).ok)
	assert_eq(String(accusing.event_log.of_type(EventLog.INTRIGUE_RESOLVED)[0].data["outcome"]), Intrigue.CAUGHT)


func test_v9_saves_wait_for_the_next_raid() -> void:
	var state := SimState.new(_config(), 2)
	_advance(state, 1.0)
	var data := JSON.parse_string(state.to_json()) as Dictionary
	data.erase("intrigue")
	data["save_version"] = SimState.V9_VERSION
	var loaded := SimState.from_json(JSON.stringify(data), state.config)
	assert_not_null(loaded, "a v9 save still loads")
	assert_eq(loaded.intrigue.phase, Intrigue.Phase.WAITING)
	data["save_version"] = SimState.SAVE_VERSION
	assert_null(SimState.from_json(JSON.stringify(data), state.config), "a v10 save must carry the intrigue")
