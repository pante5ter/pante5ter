extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(money: int = 1000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = money
	config.first_day = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	# Stories are started by hand here; the director would start its own.
	config.director = _balance.director.duplicate() as DirectorDef
	config.director.quiet_real_seconds = 1000000.0
	return config


func _start(state: SimState, story_id: String) -> StoryDef:
	var story := state.stories.find(story_id)
	assert_not_null(story, "story %s exists" % story_id)
	assert_true(state.stories.start(story, state.clock.elapsed_game_seconds, Director.ACTOR))
	return story


func _all_stories() -> Array[StoryDef]:
	return SimState.new(_config(), 1).stories.all()


func test_every_story_is_a_two_way_choice_with_answers() -> void:
	var stories := _all_stories()
	assert_gte(stories.size(), 7, "five or six village stories, the lord's and the first-day call")
	for story: StoryDef in stories:
		assert_false(story.lines.is_empty(), "%s has lines" % story.id)
		var options := 3 if story.kind == StoryDef.SCRIPT else 2
		assert_between(story.choices.size(), 2, options, "%s offers two options (three for a script beat)" % story.id)
		for choice: StoryChoiceDef in story.choices:
			assert_false(choice.label.is_empty())
			assert_false(choice.reply.is_empty(), "%s / %s has a reply" % [story.id, choice.label])
			if choice.chance < 1.0:
				assert_false(choice.fail_reply.is_empty(), "%s / %s says what went wrong" % [story.id, choice.label])
			if not choice.relation.is_empty():
				assert_true([Stories.LORD, Stories.VILLAGE, Stories.CREW].has(choice.relation), "known relation %s" % choice.relation)


func test_paying_moves_money_suspicion_and_relations() -> void:
	var state := SimState.new(_config(), 1)
	state.suspicion.level = 30.0
	var story := _start(state, "neighbour_smell")
	var pay := story.choices[0]
	var result := state.apply(ChooseCommand.new(story.id, 0))
	assert_true(result.ok)
	assert_eq(result.value, 1)
	assert_eq(state.economy.money, 1000 + pay.money)
	assert_almost_eq(state.suspicion.level, 30.0 + pay.suspicion, 0.001)
	assert_eq(state.stories.relation(Stories.VILLAGE), pay.relation_change)
	assert_false(state.stories.is_pending())
	var resolved := state.event_log.of_type(EventLog.STORY_RESOLVED)
	assert_eq(resolved.size(), 1)
	assert_eq(String(resolved[0].data["story_id"]), story.id)


func test_a_choice_jack_cannot_afford_is_refused() -> void:
	var state := SimState.new(_config(10), 1)
	var story := _start(state, "reporter")
	var result := state.apply(ChooseCommand.new(story.id, 1))
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.NOT_ENOUGH_MONEY)
	assert_true(state.stories.is_pending(), "the story still waits for an answer")
	assert_eq(state.economy.money, 10)
	assert_true(state.apply(ChooseCommand.new(story.id, 0)).ok, "the free option still works")


func test_a_gamble_follows_the_seed_and_applies_its_side() -> void:
	var outcomes: Array[bool] = []
	for seed_value: int in range(1, 13):
		var first := SimState.new(_config(), seed_value)
		var second := SimState.new(_config(), seed_value)
		var results: Array[int] = []
		for state: SimState in [first, second]:
			state.suspicion.level = 50.0
			var story := _start(state, "reporter")
			var result := state.apply(ChooseCommand.new(story.id, 0))
			results.append(result.value)
			var choice := story.choices[0]
			var expected := choice.suspicion if result.value == 1 else choice.fail_suspicion
			assert_almost_eq(state.suspicion.level, 50.0 + expected, 0.001)
		assert_eq(results[0], results[1], "same seed, same luck")
		outcomes.append(results[0] == 1)
	assert_true(outcomes.has(true) and outcomes.has(false), "an interview can go either way")


func test_answers_need_the_pending_story_and_a_real_option() -> void:
	var state := SimState.new(_config(), 1)
	assert_eq(state.apply(ChooseCommand.new("hiker", 0)).error, CommandResult.NO_STORY)
	_start(state, "hiker")
	assert_eq(state.apply(ChooseCommand.new("reporter", 0)).error, CommandResult.NO_STORY)
	assert_eq(state.apply(ChooseCommand.new("hiker", 2)).error, CommandResult.UNKNOWN_CHOICE)
	assert_false(state.stories.start(state.stories.find("reporter"), 0.0, Director.ACTOR), "one story at a time")
	assert_true(state.apply(ChooseCommand.new("hiker", 1)).ok)
	assert_false(state.stories.start(state.stories.find("hiker"), 0.0, Director.ACTOR), "a story is told once")


func test_an_advance_to_the_lord_comes_off_the_next_rent() -> void:
	var state := SimState.new(_config(5000), 1)
	var story := _start(state, "lord_advance")
	assert_true(state.apply(ChooseCommand.new(story.id, 0)).ok)
	assert_eq(state.rent.credit, 500)
	assert_eq(state.stories.relation(Stories.LORD), 2)
	var before := state.economy.money
	state.helper.next_wage_at = INF
	state.apply(AdvanceTimeCommand.new(_balance.rent.first_due_hours * HOUR * _balance.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY + 1.0))
	var paid := state.event_log.of_type(EventLog.RENT_PAID)
	assert_eq(paid.size(), 1)
	assert_eq(int(paid[0].data["amount"]), _balance.rent.amount - 500)
	assert_eq(state.rent.credit, 0)
	assert_eq(before - state.economy.money, _balance.rent.amount - 500)


func test_pending_story_and_relations_survive_save_and_load() -> void:
	var state := SimState.new(_config(), 1)
	var first := _start(state, "vicar_roof")
	state.apply(ChooseCommand.new(first.id, 0))
	_start(state, "reggie_cousin")
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(loaded.stories.pending_id, "reggie_cousin")
	assert_eq(loaded.stories.relation(Stories.VILLAGE), first.choices[0].relation_change)
	assert_true(loaded.stories.used.has("vicar_roof"))
	assert_eq(loaded.to_json(), state.to_json())
