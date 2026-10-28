extends GutTest

## Playtest round 3: unaffordable choices, the lord in the bunker, yield from care.

const BALANCE_PATH: String = "res://content/balance.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 4
const VIEWPORT_SIZE: Vector2i = Vector2i(1600, 900)
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func before_each() -> void:
	Game.new_game(7)
	Game.sim.first_day.skip()
	Game.is_running = false


func after_each() -> void:
	Game.set_speed(0)
	Game.is_running = false
	Game.new_game(7)


func _open(path: String) -> Level:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autoqfree(viewport)
	var level := (load(path) as PackedScene).instantiate() as Level
	viewport.add_child(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	return level


func _press_key(level: Level, keycode: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.pressed = true
	level.get_viewport().push_input(key, true)
	var release := key.duplicate() as InputEventKey
	release.pressed = false
	level.get_viewport().push_input(release, true)


func _plain(money: int = 1000) -> SimState:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = money
	config.first_day = null
	config.director = _balance.director.duplicate() as DirectorDef
	config.director.quiet_real_seconds = 1000000.0
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	return SimState.new(config, 1)


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(0.25, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		elapsed += step


# --- 1. "нажал оплатить 500 фунтов, а у меня их не было"

func test_sim_knows_which_choices_jack_can_pay_for() -> void:
	var state := _plain(100)
	var story := state.stories.find("lord_advance")
	assert_eq(state.stories.affordable(story), [false, true] as Array[bool])
	state.economy.money = 600
	assert_eq(state.stories.affordable(story), [true, true] as Array[bool])


func test_paying_when_affordable_takes_exactly_the_cost() -> void:
	var state := _plain(600)
	var story := state.stories.find("lord_advance")
	state.stories.start(story, 0.0, Director.ACTOR)
	assert_true(state.apply(ChooseCommand.new(story.id, 0)).ok)
	assert_eq(state.economy.money, 100)
	state.stories.start(state.stories.find("reporter"), 0.0, Director.ACTOR)
	assert_eq(state.apply(ChooseCommand.new("reporter", 1)).error, CommandResult.NOT_ENOUGH_MONEY, "broke again: £200 is refused")
	assert_eq(state.economy.money, 100)


func test_the_dialogue_shows_an_unaffordable_option_as_unavailable() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.economy.money = 100
	level.hud.play_dialogue([DialogueLineDef.make("Реджи", "Платим?")], PackedStringArray(["Заплатить £500", "Отказать"]))
	var box := level.hud.dialogue_box
	box.set_choices_enabled([false, true] as Array[bool])
	var buttons := box.choice_buttons()
	assert_true(buttons[0].disabled, "a choice Jack cannot pay for is greyed out")
	assert_false(buttons[1].disabled)
	watch_signals(box)
	_press_key(level, KEY_1)
	assert_signal_not_emitted(box, "chosen", "the number key cannot pick it either")
	box.choose(0)
	assert_signal_not_emitted(box, "chosen")
	_press_key(level, KEY_2)
	assert_signal_emitted_with_parameters(box, "chosen", [1])


func test_a_story_greys_out_what_jack_cannot_afford() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.economy.money = 100
	Game.sim.stories.start(Game.sim.stories.find("reporter"), 0.0, Director.ACTOR)
	await wait_process_frames(3)
	var box := level.hud.dialogue_box
	box.skip()
	assert_true(box.choice_buttons()[1].disabled, "the £200 advert is out of reach")
	assert_false(box.choice_buttons()[0].disabled)
	assert_string_contains(box.choice_buttons()[1].text, "£200")


# --- 2. "лорд спустился к нам"

func test_lord_stories_wait_for_jack_at_the_manor() -> void:
	for story_id: String in ["lord_advance", "lord_dinner"]:
		assert_eq(Game.sim.stories.find(story_id).place, StoryDef.MANOR, "%s happens at the manor" % story_id)
	assert_eq(_balance.first_day.lord_story.place, StoryDef.MANOR)


func test_the_lord_never_appears_in_the_bunker() -> void:
	var bunker := await _open(PLANTATION_SCENE)
	Game.sim.stories.start(Game.sim.stories.find("lord_advance"), 0.0, Director.ACTOR)
	await wait_process_frames(5)
	assert_false(bunker.hud.is_dialogue_open(), "no lord underground")
	assert_string_contains(bunker.hud.objective_label.text, "поместь", "Reggie says where to go")
	assert_true(Game.sim.stories.is_pending())


func test_the_summons_arrives_as_news_and_the_talk_happens_at_the_manor() -> void:
	var field := await _open(FIELD_SCENE)
	await wait_process_frames(2)
	var story := Game.sim.stories.find("lord_advance")
	Game.sim.stories.start(story, 0.0, Director.ACTOR)
	var started := Game.sim.event_log.last()
	assert_string_contains(UiText.announcement(started, Game.sim), "поместь", "the butler calls: the lord asks Jack over")
	await wait_process_frames(5)
	assert_false(field.hud.is_dialogue_open(), "the lord does not walk up to the container either")
	var lord := field.get_node("NavRegion/Lord") as LordAshcombe
	lord.interact(field)
	assert_true(field.hud.is_dialogue_open())
	assert_eq(field.hud.dialogue_box.current_line().text, story.lines[0].text)
	field.hud.dialogue_box.skip()
	assert_eq(field.hud.dialogue_box.choice_buttons().size(), 2)
	field.hud.dialogue_box.choice_buttons()[1].pressed.emit()
	assert_false(Game.sim.stories.is_pending())


func test_an_ignored_summons_expires_and_the_lord_takes_offence() -> void:
	var state := _plain()
	var story := state.stories.find("lord_dinner")
	state.stories.start(story, 0.0, Director.ACTOR)
	_advance(state, story.wait_hours - 0.25)
	assert_true(state.stories.is_pending())
	_advance(state, 0.5)
	assert_false(state.stories.is_pending(), "the lord does not wait forever")
	assert_eq(state.event_log.of_type(EventLog.STORY_EXPIRED).size(), 1)
	assert_eq(state.stories.relation(Stories.LORD), story.ignored_relation)


func test_the_first_day_moves_on_when_the_lord_is_ignored() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.director = null
	var state := SimState.new(config, 3)
	state.apply(PlantCommand.new(0))
	_advance(state, 3.0)
	state.apply(AnswerOrderCommand.new(state.first_day.script_order().id, Orders.DECLINE))
	_advance(state, config.first_day.lord_hour - 3.0 + 0.25)
	assert_eq(state.first_day.step, FirstDay.Step.LORD)
	_advance(state, config.first_day.lord_story.wait_hours + 0.25)
	assert_eq(state.first_day.step, FirstDay.Step.MORNING)


# --- 3. yield from care

func _ready_plot(state: SimState, plot_id: int, strain_id: String, fertilize: bool, prune: bool) -> void:
	assert_true(state.apply(PlantCommand.new(plot_id, strain_id)).ok)
	var strain := state.config.find_strain(strain_id)
	var hours := 0.0
	while state.grow.plot(plot_id).stage != Plot.Stage.READY and hours < strain.growth_hours() + 2.0:
		state.apply(WaterCommand.new(plot_id))
		if fertilize and not state.grow.plot(plot_id).fertilized:
			state.apply(FertilizeCommand.new(plot_id))
		if prune and state.grow.plot(plot_id).stage == Plot.Stage.BUSH and not state.grow.plot(plot_id).pruned:
			state.apply(PruneCommand.new(plot_id))
		_advance(state, 0.25)
		hours += 0.25


func _rich_grower() -> SimState:
	var config := _balance.duplicate() as BalanceConfig
	config.shop = null
	config.opportunities = null
	config.starting_money = 100000
	config.first_day = null
	config.director = null
	config.helper = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	var state := SimState.new(config, 5)
	state.supplies.fertilizer = 20
	return state


func _harvest_count(strain_id: String, fertilize: bool, prune: bool) -> int:
	var state := _rich_grower()
	_ready_plot(state, 0, strain_id, fertilize, prune)
	var before := state.inventory.count()
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	return state.inventory.count() - before


func test_every_strain_says_how_care_changes_its_yield() -> void:
	for strain: StrainDef in _balance.strains():
		assert_gte(strain.yield_min, 1, "%s yields at least one" % strain.id)
		assert_gt(strain.fertilizer_yield + strain.prune_yield, 0, "care pays off in volume for %s" % strain.id)
	var basic := _balance.find_strain("basic")
	var elite := _balance.find_strain("elite")
	assert_false(basic.fertilizer_yield == elite.fertilizer_yield and basic.prune_yield == elite.prune_yield, "strains react to care differently")


## The care bonus on top of the harvest's lucky extra, which the event reports.
func _care_units(strain_id: String, fertilize: bool, prune: bool) -> int:
	var state := _rich_grower()
	_ready_plot(state, 0, strain_id, fertilize, prune)
	var before := state.inventory.count()
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	var bonus := int((state.event_log.of_type(EventLog.PLOT_HARVESTED).back() as SimEvent).data["bonus"])
	return state.inventory.count() - before - bonus


func test_fertiliser_and_pruning_add_units_to_the_harvest() -> void:
	var strain := _balance.find_strain("basic")
	assert_eq(_care_units("basic", false, false), strain.yield_min)
	assert_eq(_care_units("basic", true, false), strain.yield_min + strain.fertilizer_yield)
	assert_eq(_care_units("basic", true, true), strain.yield_min + strain.fertilizer_yield + strain.prune_yield)
	var cared := strain.fertilizer_yield + strain.prune_yield
	assert_between(_harvest_count("basic", true, true), strain.yield_min + cared, strain.yield_max + cared)


func test_harvest_event_reports_the_amount() -> void:
	var state := _rich_grower()
	_ready_plot(state, 0, "basic", true, true)
	state.apply(HarvestCommand.new(0))
	var harvested := state.event_log.of_type(EventLog.PLOT_HARVESTED)
	var strain := state.config.find_strain("basic")
	assert_eq(int(harvested[0].data["quantity"]), strain.yield_min + strain.fertilizer_yield + strain.prune_yield + int(harvested[0].data["bonus"]))
	assert_eq((harvested[0].data["product_ids"] as Array).size(), int(harvested[0].data["quantity"]))
