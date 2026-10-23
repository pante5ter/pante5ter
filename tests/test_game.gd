extends GutTest

const SAVE_PATH: String = "user://test_game_save.json"


func after_each() -> void:
	Game.is_running = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func test_autoload_provides_sim() -> void:
	assert_not_null(Game.sim)


func test_new_game_resets_state() -> void:
	Game.new_game(5)
	Game.sim.apply(PlantCommand.new(0))
	Game.new_game(5)
	assert_eq(Game.sim.event_log.size(), 0)
	assert_eq(Game.sim.grow.plot(0).stage, Plot.Stage.EMPTY)


func test_save_and_load_round_trip() -> void:
	Game.new_game(11)
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.apply(WaterCommand.new(0))
	Game.sim.apply(AdvanceTimeCommand.new(30.0))
	var saved_json := Game.sim.to_json()
	assert_eq(Game.save_game(SAVE_PATH), OK)

	Game.new_game(12)
	assert_eq(Game.load_game(SAVE_PATH), OK)
	assert_eq(Game.sim.to_json(), saved_json)


func test_load_missing_file_keeps_current_state() -> void:
	Game.new_game(3)
	var before := Game.sim
	assert_eq(Game.load_game("user://does_not_exist.json"), ERR_FILE_NOT_FOUND)
	assert_same(Game.sim, before)


func test_load_corrupt_file_keeps_current_state() -> void:
	Game.new_game(3)
	var before := Game.sim
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{ broken")
	file.close()
	assert_eq(Game.load_game(SAVE_PATH), ERR_PARSE_ERROR)
	assert_same(Game.sim, before)


func test_time_advances_only_while_running() -> void:
	Game.new_game(1)
	Game._process(1.0)
	assert_eq(Game.sim.clock.elapsed_game_seconds, 0.0)
	Game.is_running = true
	Game._process(1.0)
	assert_gt(Game.sim.clock.elapsed_game_seconds, 0.0)



func test_speed_multiplies_how_fast_time_runs() -> void:
	Game.new_game(1)
	Game.is_running = true
	Game.set_speed(0)
	Game._process(1.0)
	var normal := Game.sim.clock.elapsed_game_seconds
	Game.new_game(1)
	Game.set_speed(2)
	Game._process(1.0)
	assert_almost_eq(Game.sim.clock.elapsed_game_seconds, normal * Game.SPEEDS[2], 0.001)
	Game.set_speed(99)
	assert_eq(Game.time_scale, Game.SPEEDS[Game.SPEEDS.size() - 1])
	Game.set_speed(0)
