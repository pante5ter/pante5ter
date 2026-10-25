extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"
const PROLOGUE_PATH: String = "res://content/prologue.tres"
const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const HOME_SCENE: String = "res://scenes/home/home.tscn"
const VIEWPORT_SIZE: Vector2i = Vector2i(1600, 900)
const SETTLE_FRAMES: int = 4

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func after_each() -> void:
	Game.set_speed(0)
	Game.is_running = false
	Game.new_game(7)


func _state() -> SimState:
	return SimState.new(_balance, 7)


## Past the opening night, as after the prologue.
func _opened_state() -> SimState:
	var state := _state()
	for character: CharacterDef in state.meetings.opening():
		assert_true(state.apply(MeetCommand.new(character.id)).ok)
	return state


func _met_events(state: SimState, character_id: String) -> int:
	var count := 0
	for event: SimEvent in state.event_log.of_type(EventLog.CHARACTER_MET):
		if String(event.data["character_id"]) == character_id:
			count += 1
	return count


func _record_and_update(state: SimState, type: String, data: Dictionary = {}) -> void:
	state.event_log.record(type, state.clock.elapsed_game_seconds, PackedStringArray(["test"]), data)
	state.meetings.update(state.clock.elapsed_game_seconds)


func _open(path: String) -> Level:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	add_child_autoqfree(viewport)
	var level := (load(path) as PackedScene).instantiate() as Level
	viewport.add_child(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	return level


## A real new game, past its opening night.
func _fresh_field() -> Level:
	Game.new_game(7, true)
	var level := await _open(FIELD_SCENE)
	level.hud.dialogue_box.skip()
	await wait_process_frames(2)
	return level


func test_the_cast_is_well_formed() -> void:
	var cast := _balance.cast
	assert_not_null(cast)
	var ids := PackedStringArray()
	var event_types: Array = EventLog.new().get_script().get_script_constant_map().values()
	for character: CharacterDef in cast.characters:
		assert_false(ids.has(character.id), "ids are unique: %s" % character.id)
		ids.append(character.id)
		assert_false(character.display_name.is_empty())
		assert_false(character.bio.strip_edges().is_empty(), "every character has a bible entry: %s" % character.id)
		for line: DialogueLineDef in character.intro:
			assert_false(line.text.strip_edges().is_empty())
		if character.meeting == CharacterDef.EVENT:
			assert_true(event_types.has(character.meet_event), "%s meets on a real event" % character.id)
			assert_between(character.intro.size(), 2, 4, "%s: a short intro" % character.id)
	for main_id: String in ["jack", "reggie", "ashcombe", "vivienne", "clients", "frank", "harry", "pete", "milk_teeth", "gaffer"]:
		assert_true(ids.has(main_id), "the bible covers %s" % main_id)


func test_a_new_game_has_met_nobody_and_the_opening_is_the_lord_then_reggie() -> void:
	var state := _state()
	assert_true(state.meetings.met.is_empty())
	assert_true(state.meetings.due.is_empty())
	var opening := state.meetings.opening()
	assert_eq(opening.size(), 2)
	assert_eq(opening[0].id, "ashcombe")
	assert_eq(opening[1].id, "reggie")
	assert_between(opening[1].intro.size(), 2, 4)


func test_nobody_is_introduced_before_the_opening_night() -> void:
	var state := _state()
	state.economy.earn(1000)
	state.orders.inject(1, 0, 100, 6.0, 0.0, false, 0.0)
	state.apply(HireCourierCommand.new("frank"))
	assert_true(state.meetings.due.is_empty())
	for character: CharacterDef in state.meetings.opening():
		state.apply(MeetCommand.new(character.id))
	state.apply(AdvanceTimeCommand.new(0.01))
	assert_true(state.meetings.due.is_empty(), "what happened before the prologue is not a meeting")


func test_the_first_call_brings_the_clients_intro_once() -> void:
	var state := _opened_state()
	state.orders.inject(1, 0, 100, 6.0, 0.0, false, 0.0)
	state.apply(AdvanceTimeCommand.new(0.01))
	assert_eq(state.meetings.next_due("").id, "clients")
	assert_true(state.apply(MeetCommand.new("clients")).ok)
	assert_true(state.meetings.has_met("clients"))
	assert_null(state.meetings.next_due(""))
	assert_eq(_met_events(state, "clients"), 1)
	var met := state.event_log.last()
	assert_eq(met.type, EventLog.CHARACTER_MET)
	assert_true(met.actors.has("clients"))
	state.orders.inject(1, 0, 100, 6.0, 0.0, false, state.clock.elapsed_game_seconds)
	state.apply(AdvanceTimeCommand.new(0.01))
	assert_null(state.meetings.next_due(""), "the second client is no news")


func test_each_courier_is_introduced_on_his_own_hiring() -> void:
	var state := _opened_state()
	state.economy.earn(1000)
	assert_true(state.apply(HireCourierCommand.new("frank")).ok)
	assert_eq(state.meetings.due, ["frank"] as Array[String])
	assert_true(state.apply(MeetCommand.new("frank")).ok)
	assert_true(state.apply(FireCourierCommand.new("frank")).ok)
	assert_true(state.apply(HireCourierCommand.new("frank")).ok)
	assert_true(state.meetings.due.is_empty(), "hired again, met already")
	assert_true(state.apply(HireCourierCommand.new("pete")).ok)
	assert_eq(state.meetings.due, ["pete"] as Array[String])


func test_vivienne_waits_for_jack_at_home() -> void:
	var state := _opened_state()
	assert_true(state.apply(TravelCommand.new(DayCycle.HOME)).ok)
	assert_true(state.day.is_home())
	assert_null(state.meetings.next_due(DayCycle.FARM))
	assert_null(state.meetings.next_due(""))
	assert_eq(state.meetings.next_due(DayCycle.HOME).id, "vivienne")
	assert_true(state.apply(MeetCommand.new("vivienne")).ok)
	assert_true(state.apply(TravelCommand.new(DayCycle.FARM)).ok)
	assert_true(state.apply(TravelCommand.new(DayCycle.HOME)).ok)
	assert_null(state.meetings.next_due(DayCycle.HOME), "the second evening at home is just an evening")


func test_the_gang_is_introduced_after_their_first_raid() -> void:
	var state := _opened_state()
	_record_and_update(state, EventLog.RAID_STARTED)
	assert_null(state.meetings.next_due(""), "not in the middle of the raid")
	_record_and_update(state, EventLog.RAID_RESOLVED)
	assert_eq(state.meetings.next_due("").id, "milk_teeth")


func test_meeting_twice_or_a_stranger_is_refused() -> void:
	var state := _state()
	assert_true(state.apply(MeetCommand.new("reggie")).ok)
	var again := state.apply(MeetCommand.new("reggie"))
	assert_false(again.ok)
	assert_eq(again.error, CommandResult.ALREADY_DONE)
	assert_false(state.apply(MeetCommand.new("nobody")).ok)
	assert_eq(_met_events(state, "reggie"), 1)


func test_met_and_due_survive_a_save() -> void:
	var state := _opened_state()
	state.economy.earn(1000)
	state.apply(HireCourierCommand.new("harry"))
	var loaded := SimState.from_json(state.to_json(), _balance)
	assert_not_null(loaded)
	assert_true(loaded.meetings.has_met("reggie"))
	assert_false(loaded.meetings.has_met("harry"))
	assert_eq(loaded.meetings.next_due("").id, "harry")
	loaded.apply(AdvanceTimeCommand.new(1.0))
	assert_eq(loaded.meetings.due, ["harry"] as Array[String], "no event is counted twice after loading")


func test_an_old_save_knows_everyone_and_springs_no_intro() -> void:
	var state := _state()
	state.economy.earn(1000)
	var data := JSON.parse_string(state.to_json()) as Dictionary
	data.erase("meetings")
	var loaded := SimState.from_json(JSON.stringify(data), _balance)
	assert_not_null(loaded)
	for character: CharacterDef in _balance.cast.characters:
		assert_true(loaded.meetings.has_met(character.id), "%s is an old acquaintance" % character.id)
	assert_true(loaded.meetings.opening().is_empty())
	loaded.apply(HireCourierCommand.new("frank"))
	loaded.apply(TravelCommand.new(DayCycle.HOME))
	assert_true(loaded.meetings.due.is_empty())
	assert_eq(loaded.event_log.of_type(EventLog.CHARACTER_MET).size(), 0, "nobody is met again on the record")


func test_the_opening_night_tells_reggies_story_after_the_lords_deal() -> void:
	Game.new_game(7, true)
	var level := await _open(FIELD_SCENE)
	var prologue := (load(PROLOGUE_PATH) as DialogueDef).lines
	var reggie := Game.sim.meetings.find("reggie")
	assert_true(level.hud.is_dialogue_open())
	assert_eq(level.hud.dialogue_box.current_line().text, prologue[0].text)
	for step: int in prologue.size():
		level.hud.dialogue_box.advance()
	assert_eq(level.hud.dialogue_box.current_line().text, reggie.intro[0].text)
	assert_true(Game.sim.meetings.has_met("reggie"))
	assert_true(Game.sim.meetings.has_met("ashcombe"))
	level.hud.dialogue_box.skip()
	await wait_process_frames(3)
	assert_false(level.hud.is_dialogue_open(), "nothing else queues behind the prologue")
	assert_eq(_met_events(Game.sim, "reggie"), 1)


func test_a_hired_courier_introduces_himself_once_the_phone_is_closed() -> void:
	var level := await _fresh_field()
	assert_false(level.hud.is_dialogue_open())
	Game.sim.economy.earn(1000)
	level.hud.phone.open()
	assert_true(Game.sim.apply(HireCourierCommand.new("frank")).ok)
	await wait_process_frames(3)
	assert_false(level.hud.is_dialogue_open(), "the intro does not cut into the phone")
	level.hud.phone.close()
	await wait_process_frames(3)
	assert_true(level.hud.is_dialogue_open())
	assert_eq(level.hud.dialogue_box.current_line().text, Game.sim.meetings.find("frank").intro[0].text)
	level.hud.dialogue_box.skip()
	await wait_process_frames(3)
	assert_false(level.hud.is_dialogue_open(), "told once")
	assert_eq(_met_events(Game.sim, "frank"), 1)


func test_vivienne_does_not_introduce_herself_in_the_field() -> void:
	var level := await _fresh_field()
	Game.sim.day.place = DayCycle.HOME
	_record_and_update(Game.sim, EventLog.JACK_ARRIVED, {"from": DayCycle.FARM, "to": DayCycle.HOME})
	await wait_process_frames(3)
	assert_false(level.hud.is_dialogue_open())
	level.get_parent().queue_free()
	await wait_process_frames(2)
	var home := await _open(HOME_SCENE)
	await wait_process_frames(3)
	assert_true(home.hud.is_dialogue_open())
	assert_eq(home.hud.dialogue_box.current_line().text, Game.sim.meetings.find("vivienne").intro[0].text)
