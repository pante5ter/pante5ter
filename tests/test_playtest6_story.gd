extends GutTest

## Playtest round 6: the clue board, fairer clues, no strangers in the line-up, a slower reporter.

const BALANCE_PATH: String = "res://content/balance.tres"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25
const VERDICT_WORDS: Array[String] = ["крыс", "сдал", "наводчик", "предател", "это он"]

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(with_director: bool = false) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = 5000
	config.first_day = null
	config.director = null
	if with_director:
		config.director = _balance.director.duplicate() as DirectorDef
		config.director.quiet_real_seconds = 1000000.0
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	return config


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(STEP_HOURS, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		elapsed += step


func _hire_courier_suspects(state: SimState) -> void:
	for person: SuspectDef in state.config.intrigue.suspects:
		if person.courier_id.is_empty() or state.couriers.hired.has(person.courier_id):
			continue
		assert_true(state.apply(HireCourierCommand.new(person.courier_id)).ok)


func _meet_suspects(state: SimState) -> void:
	_hire_courier_suspects(state)
	for person: SuspectDef in state.config.intrigue.suspects:
		if person.intro_story != null and not state.stories.used.has(person.intro_story.id):
			state.stories.used.append(person.intro_story.id)


func _raid(state: SimState) -> void:
	_hire_courier_suspects(state)
	state.raids.pending = true
	state.raids.deadline = state.clock.elapsed_game_seconds + HOUR
	assert_true(state.apply(RaidCommand.new(Raids.PAY)).ok)


func _opening_id(state: SimState) -> String:
	return state.config.intrigue.opening_story.id


func _investigate_all(state: SimState) -> void:
	_meet_suspects(state)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	_advance(state, state.config.intrigue.clue_interval_hours * float(state.intrigue.schedule.size()) + STEP_HOURS)


static func _surname(person: SuspectDef) -> String:
	var words := person.display_name.split(" ")
	return words[words.size() - 1]


# --- 1. The clue board

func test_the_board_lists_every_clue_with_where_and_when() -> void:
	var state := SimState.new(_config(), 3)
	_meet_suspects(state)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	_advance(state, state.config.intrigue.clue_interval_hours * 2.0 + STEP_HOURS)
	var pinned := IntrigueBoard.pinned(state.config.intrigue, state.event_log)
	assert_eq(pinned.size(), 2, "two clues so far")
	var events := state.event_log.of_type(EventLog.INTRIGUE_CLUE)
	for index: int in pinned.size():
		var clue := pinned[index]
		assert_eq(clue.text, state.intrigue.clue_text(clue.key))
		assert_false(clue.place.is_empty(), "%s says where Reggie found it" % clue.key)
		assert_eq(clue.found_at, events[index].game_time)
		assert_eq(clue.number, index + 1)


func test_nameless_traces_hang_under_the_raid_not_under_the_rat() -> void:
	var state := SimState.new(_config(), 5)
	_investigate_all(state)
	var pinned := IntrigueBoard.pinned(state.config.intrigue, state.event_log)
	assert_eq(pinned.size(), state.intrigue.schedule.size())
	var trails := 0
	for clue: IntrigueClue in pinned:
		if IntrigueBoard.parts(clue.key)[1] == Intrigue.TRAIL:
			trails += 1
			assert_eq(clue.suspect_id, "", "a trail never names its card")
		else:
			assert_eq(clue.suspect_id, IntrigueBoard.parts(clue.key)[0])
	assert_gt(trails, 0)
	for event: SimEvent in state.event_log.of_type(EventLog.INTRIGUE_CLUE):
		if IntrigueBoard.parts(String(event.data["clue"]))[1] == Intrigue.TRAIL:
			assert_eq(event.actors.size(), 1, "the log does not tie a trail to the rat either")
	var cases := IntrigueBoard.cases(state.config.intrigue, pinned)
	assert_eq(cases[0], "", "the raid comes first")
	assert_eq(cases.size(), state.config.intrigue.suspects.size() + 1, "one card per suspect and one for the raid")


func test_the_news_says_the_clue_went_on_the_board() -> void:
	var state := SimState.new(_config(), 3)
	_investigate_all(state)
	var event := state.event_log.of_type(EventLog.INTRIGUE_CLUE)[0]
	var line := UiText.announcement(event, state)
	assert_string_contains(line, "доску")
	assert_string_contains(line, state.intrigue.clue_text(String(event.data["clue"])))


func test_the_board_text_marks_the_newest_clue() -> void:
	var state := SimState.new(_config(), 3)
	_meet_suspects(state)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	_advance(state, state.config.intrigue.clue_interval_hours * 2.0 + STEP_HOURS)
	var box := VBoxContainer.new()
	ClueBoardText.fill(box, state)
	var texts := PackedStringArray()
	for child: Node in box.get_children():
		texts.append((child as Label).text)
	box.free()
	var joined := "\n".join(texts)
	var newest := IntrigueBoard.pinned(state.config.intrigue, state.event_log)[1]
	assert_string_contains(joined, "%s · %s" % [ClueBoardText.NEW_MARK, newest.text])
	assert_eq(joined.count(ClueBoardText.NEW_MARK), 1, "only the latest one is new")
	assert_string_contains(joined, "Где: ")
	assert_string_contains(joined, "2 из %d" % state.intrigue.schedule.size())


func test_an_empty_board_says_so() -> void:
	var state := SimState.new(_config(), 3)
	var box := VBoxContainer.new()
	ClueBoardText.fill(box, state)
	assert_eq(box.get_child_count(), 1)
	assert_string_contains((box.get_child(0) as Label).text, "пуста")
	box.free()


func test_the_bunker_board_opens_the_clues_on_the_computer() -> void:
	Game.new_game(31)
	Game.sim.first_day.skip()
	Game.is_running = false
	var level := (load(PLANTATION_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_process_frames(2)
	var board := level.find_child("ClueBoard", true, false) as ClueBoard
	assert_not_null(board, "the cork board hangs in the bunker")
	assert_string_contains(board.hover_text(), "Пробковая доска")
	board.interact(level)
	assert_true(level.hud.computer.visible)
	assert_eq(level.hud.computer.current_tab(), ComputerScreen.TAB_CLUES)
	level.hud.computer.close()
	Game.new_game(31)


# --- 2. Fairer clues

func test_no_clue_gives_the_rat_away_on_its_own() -> void:
	var def := _balance.intrigue
	for person: SuspectDef in def.suspects:
		var all_clues := PackedStringArray([person.alibi_clue, person.herring_clue])
		all_clues.append_array(person.guilty_clues)
		all_clues.append_array(person.trail_clues)
		for text: String in all_clues:
			for word: String in VERDICT_WORDS:
				assert_false(text.to_lower().contains(word), "%s: «%s» passes a verdict" % [person.id, text])
		for text: String in person.trail_clues:
			for anyone: SuspectDef in def.suspects:
				assert_false(text.contains(_surname(anyone)), "a trail names nobody: «%s»" % text)
		for text: String in person.guilty_clues:
			assert_string_contains(text, _surname(person), "the other half ties it to him by name")
		assert_string_contains(person.herring_clue, _surname(person))
		assert_eq(person.guilty_places.size(), person.guilty_clues.size())
		assert_eq(person.trail_places.size(), person.trail_clues.size())


func test_choice_labels_are_names_not_verdicts() -> void:
	for person: SuspectDef in _balance.intrigue.suspects:
		assert_true(person.accuse_label.contains(_surname(person)), person.accuse_label)
		assert_false(person.accuse_label.begins_with("Это"), "«%s» reads like an answer" % person.accuse_label)
	assert_eq(_balance.intrigue.wait_label, "Пока никого — нужно больше")
	assert_false(_balance.intrigue.wait_reply.is_empty())


func test_the_rat_follows_the_seed() -> void:
	var rats: Array[String] = []
	for seed_value: int in range(1, 13):
		var first := SimState.new(_config(), seed_value)
		var second := SimState.new(_config(), seed_value)
		for state: SimState in [first, second]:
			_meet_suspects(state)
			_raid(state)
		assert_eq(first.intrigue.rat_suspect().id, second.intrigue.rat_suspect().id, "same seed, same rat")
		assert_eq(first.intrigue.schedule, second.intrigue.schedule)
		if not rats.has(first.intrigue.rat_suspect().id):
			rats.append(first.intrigue.rat_suspect().id)
	assert_gt(rats.size(), 1, "the seed decides, not the content")


func test_nobody_yet_asks_again_later_and_the_rat_keeps_talking() -> void:
	var config := _config()
	config.raids.chance_per_night = 0.000001
	var state := SimState.new(config, 4)
	_investigate_all(state)
	assert_eq(state.stories.pending_id, Intrigue.ACCUSE_STORY_ID)
	var story := state.stories.pending()
	var wait := IntrigueAccusation.wait_choice(state.intrigue)
	assert_eq(story.choices[wait].label, state.config.intrigue.wait_label, "«nobody yet» is the last choice")
	assert_true(state.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, wait)).ok)
	assert_eq(state.intrigue.phase, Intrigue.Phase.ACCUSING, "the case stays open")
	assert_false(state.stories.is_pending())
	assert_true(state.raids.expected, "the rat tips the gang off again meanwhile")
	var steps := state.event_log.of_type(EventLog.INTRIGUE_STEP)
	assert_eq(String(steps[steps.size() - 1].data["path"]), Intrigue.WAITED)
	assert_eq(state.event_log.of_type(EventLog.INTRIGUE_RESOLVED).size(), 0)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	for copy: SimState in [state, loaded]:
		_advance(copy, state.config.intrigue.wait_hours - 1.0)
		assert_false(copy.stories.is_pending(), "not before the wait is over")
		_advance(copy, 1.0 + STEP_HOURS)
		assert_eq(copy.stories.pending_id, Intrigue.ACCUSE_STORY_ID, "Reggie asks again")
	assert_eq(loaded.to_json(), state.to_json())
	var rat_choice := IntrigueAccusation.choice_for(state.intrigue, state.intrigue.rat_suspect().id)
	assert_true(state.apply(ChooseCommand.new(Intrigue.ACCUSE_STORY_ID, rat_choice)).ok)
	assert_eq(String(state.event_log.of_type(EventLog.INTRIGUE_RESOLVED)[0].data["outcome"]), Intrigue.CAUGHT)


func test_saves_from_before_trails_still_read_their_clues() -> void:
	var state := SimState.new(_config(), 3)
	var def := state.config.intrigue
	for person: SuspectDef in def.suspects:
		assert_eq(state.intrigue.clue_text("%s:guilty:%d" % [person.id, person.guilty_clues.size()]), person.trail_clues[0], "old «guilty:1» is the first trail")
	var data := state.intrigue.to_dict()
	data.erase("accuse_at")
	state.intrigue.load_dict(data)
	assert_eq(state.intrigue.accuse_at, 0.0)


# --- 3. No strangers in the line-up

func test_nobody_is_accusable_before_jack_has_heard_of_him() -> void:
	var state := SimState.new(_config(), 2)
	var liam := state.config.intrigue.suspect("liam")
	assert_not_null(liam.intro_story, "Liam comes with Reggie's cousin story")
	assert_eq(liam.intro_story.id, "reggie_cousin")
	var names: Array[String] = []
	for person: SuspectDef in state.intrigue.accusable():
		names.append(person.id)
	assert_false(names.has("liam"), "a stranger is not on the list")
	assert_false(names.has("pete"), "Pete is not a suspect until hired")
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	assert_true(state.intrigue.is_introduced(state.config.intrigue.suspect("pete")))
	state.stories.used.append("reggie_cousin")
	assert_true(state.intrigue.is_introduced(liam))


func test_every_suspect_but_the_courier_has_an_introduction() -> void:
	for person: SuspectDef in _balance.intrigue.suspects:
		if person.courier_id.is_empty():
			assert_not_null(person.intro_story, "%s must be met before he can be suspected" % person.id)
		if person.intro_story != null:
			assert_false(person.intro_story.choices.is_empty(), "%s's introduction can be told" % person.id)
			assert_true(_balance.director.stories.has(person.intro_story), "the director can tell %s's introduction on its own" % person.id)


func test_untold_introductions_come_before_any_clue_about_them() -> void:
	var state := SimState.new(_config(), 2)
	_raid(state)
	assert_true(state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE)).ok)
	var told: Array[String] = []
	for attempt: int in 4:
		if not state.stories.is_pending():
			break
		var story_id := state.stories.pending_id
		assert_eq(state.event_log.of_type(EventLog.INTRIGUE_CLUE).size(), 0, "no clue while %s is told" % story_id)
		told.append(story_id)
		assert_true(state.apply(ChooseCommand.new(story_id, 1)).ok)
	assert_eq(told, ["reggie_cousin", "neighbour_smell"] as Array[String], "Liam, then Hobbs, in content order")
	_advance(state, state.config.intrigue.clue_interval_hours * float(state.intrigue.schedule.size()) + STEP_HOURS)
	assert_eq(state.event_log.of_type(EventLog.INTRIGUE_CLUE).size(), state.intrigue.schedule.size())
	assert_eq(state.stories.pending_id, Intrigue.ACCUSE_STORY_ID)
	assert_eq(state.stories.pending().choices.size(), state.config.intrigue.suspects.size() + 1)


func test_a_story_the_director_already_told_counts_as_an_introduction() -> void:
	var state := SimState.new(_config(true), 2)
	state.stories.start(state.stories.find("reggie_cousin"), 0.0, Director.ACTOR)
	state.apply(ChooseCommand.new("reggie_cousin", 0))
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.INVESTIGATE))
	assert_eq(state.stories.pending_id, "neighbour_smell", "only Hobbs still needs meeting")
	state.apply(ChooseCommand.new("neighbour_smell", 1))
	assert_false(state.stories.is_pending())
	assert_eq(state.event_log.of_type(EventLog.STORY_STARTED).filter(func(event: SimEvent) -> bool: return String(event.data["story_id"]) == "reggie_cousin").size(), 1, "told once")


func test_paying_the_boss_still_introduces_everyone_first() -> void:
	var state := SimState.new(_config(), 2)
	_raid(state)
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.PAY_BOSS))
	assert_eq(state.stories.pending_id, "reggie_cousin")
	state.apply(ChooseCommand.new("reggie_cousin", 1))
	assert_eq(state.stories.pending_id, "neighbour_smell")
	state.apply(ChooseCommand.new("neighbour_smell", 1))
	assert_eq(state.stories.pending_id, Intrigue.ACCUSE_STORY_ID)
	var labels := state.stories.pending().choice_labels()
	for person: SuspectDef in state.config.intrigue.suspects:
		assert_true(labels.has(person.accuse_label))


func test_a_suspect_whose_introduction_cannot_be_told_is_left_out() -> void:
	var config := _config()
	config.intrigue = _balance.intrigue.duplicate() as IntrigueDef
	var suspects: Array[SuspectDef] = []
	for person: SuspectDef in _balance.intrigue.suspects:
		var copy := person.duplicate() as SuspectDef
		if copy.id == "liam":
			copy.intro_story = StoryDef.new()
			copy.intro_story.id = "no_such_talk"
		suspects.append(copy)
	config.intrigue.suspects = suspects
	var state := SimState.new(config, 2)
	_raid(state)
	for key: String in state.intrigue.schedule:
		assert_false(key.begins_with("liam:"), "no clues about someone Jack will never meet")
	assert_ne(state.intrigue.rat_suspect().id, "liam")
	state.intrigue.rat = 0
	state.apply(ChooseCommand.new(_opening_id(state), IntrigueDef.PAY_BOSS))
	state.apply(ChooseCommand.new("neighbour_smell", 1))
	assert_eq(state.stories.pending_id, Intrigue.ACCUSE_STORY_ID, "the hunt does not hang on a story that cannot be told")
	var labels := state.stories.pending().choice_labels()
	assert_eq(labels.size(), suspects.size(), "two names and «nobody yet»")
	for label: String in labels:
		assert_false(label.contains("Лиам"))


# --- 4. The reporter takes his time

func test_the_reporter_first_calls_about_the_harvest_festival() -> void:
	var state := SimState.new(_config(true), 1)
	var first := state.stories.find("reporter")
	var texts := PackedStringArray()
	for line: DialogueLineDef in first.lines:
		texts.append(line.text.to_lower())
	var joined := " ".join(texts)
	assert_string_contains(joined, "праздник")
	for word: String in ["фургон", "ночн", "тело", "по ночам"]:
		assert_false(joined.contains(word), "the first call is small talk, not «%s»" % word)


func test_the_night_traffic_beat_waits_for_the_first_call_and_for_suspicion() -> void:
	var state := SimState.new(_config(true), 1)
	var vans := state.stories.find("reporter_vans")
	assert_not_null(vans)
	assert_true(vans.after_stories.has("reporter"))
	assert_gt(vans.min_suspicion, 0.0)
	state.suspicion.level = vans.min_suspicion + 10.0
	assert_false(state.stories.untold(StoryDef.VILLAGE).has(vans), "not before the first call")
	assert_true(state.stories.untold(StoryDef.VILLAGE).has(state.stories.find("reporter")))
	state.stories.start(state.stories.find("reporter"), 0.0, Director.ACTOR)
	state.apply(ChooseCommand.new("reporter", 1))
	state.suspicion.level = vans.min_suspicion - 1.0
	assert_false(state.stories.untold(StoryDef.VILLAGE).has(vans), "the village is not talking yet")
	state.suspicion.level = vans.min_suspicion
	assert_true(state.stories.untold(StoryDef.VILLAGE).has(vans), "now the reporter calls back")


func test_the_night_traffic_beat_hints_instead_of_stating() -> void:
	var vans := SimState.new(_config(true), 1).stories.find("reporter_vans")
	var joined := ""
	for line: DialogueLineDef in vans.lines:
		joined += line.text.to_lower() + " "
	assert_false(joined.contains("фургон"), "he counts cars through a neighbour; he does not say «vans»")
	assert_false(joined.contains("тело"))
	assert_string_contains(joined, "звон")


func test_the_director_skips_a_beat_that_is_not_ready() -> void:
	var config := _config(true)
	config.director.quiet_real_seconds = 10.0
	config.director.stories = [_balance.director.stories.filter(func(story: StoryDef) -> bool: return story.id == "reporter_vans")[0]] as Array[StoryDef]
	var state := SimState.new(config, 1)
	assert_false(state.director.applicable(Director.STORY), "the only story left needs the first call")
