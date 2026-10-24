extends GutTest

## Playtest round 4: "clues come too fast at x2/x4, I can't keep up" — a story beat drops the game to x1.

const FAST: int = 2


func before_each() -> void:
	Game.new_game(7)
	Game.sim.first_day.skip()
	Game.is_running = true
	Game.set_speed(FAST)


func after_each() -> void:
	Game.set_speed(0)
	Game.is_running = false
	Game.new_game(7)


func _story(story_id: String) -> StoryDef:
	var story := StoryDef.new()
	story.id = story_id
	var choice := StoryChoiceDef.new()
	choice.label = "ok"
	story.choices = [choice] as Array[StoryChoiceDef]
	Game.sim.stories.register(story)
	return story


func _frame() -> void:
	Game._process(0.016)


func test_quiet_frames_keep_the_chosen_speed() -> void:
	_frame()
	_frame()
	assert_eq(Game.time_scale, Game.SPEEDS[FAST])


func test_a_story_beat_drops_the_game_to_normal_speed() -> void:
	Game.sim.stories.start(_story("beat"), Game.sim.clock.elapsed_game_seconds, "test")
	_frame()
	assert_eq(Game.time_scale, Game.SPEEDS[0])


func test_a_clue_from_finn_is_a_beat() -> void:
	var clue := SimEvent.new()
	clue.type = EventLog.INTRIGUE_CLUE
	assert_true(Stories.is_beat(clue))
	for type: String in [EventLog.STORY_STARTED, EventLog.DIRECTOR_EVENT]:
		clue.type = type
		assert_true(Stories.is_beat(clue), type)
	for type: String in [EventLog.ORDER_PAID, EventLog.PLOT_WATERED, EventLog.STORY_RESOLVED]:
		clue.type = type
		assert_false(Stories.is_beat(clue), type)


func test_the_player_can_speed_up_again_after_the_beat() -> void:
	Game.sim.stories.start(_story("beat"), Game.sim.clock.elapsed_game_seconds, "test")
	_frame()
	Game.set_speed(FAST)
	_frame()
	assert_eq(Game.time_scale, Game.SPEEDS[FAST], "the same beat does not slow the game twice")


func test_routine_events_do_not_slow_the_game() -> void:
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.apply(WaterCommand.new(0))
	_frame()
	assert_eq(Game.time_scale, Game.SPEEDS[FAST])


func test_beats_from_before_a_new_game_or_load_are_old_news() -> void:
	Game.sim.stories.start(_story("beat"), Game.sim.clock.elapsed_game_seconds, "test")
	Game.new_game(8)
	Game.sim.first_day.skip()
	Game.set_speed(FAST)
	_frame()
	assert_eq(Game.time_scale, Game.SPEEDS[FAST])
