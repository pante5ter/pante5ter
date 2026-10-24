extends GutTest

## v11 saves (bench and shelf in the bunker, one farmhand, Reggie with bed courses) load sensibly.

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.first_day = null
	config.director = null
	var helper := _balance.helper.duplicate() as WorkerDef
	helper.starting_skills = ["driving"] as Array[String]
	config.helper = helper
	return config


## A v12 game rewritten into the v11 shape.
func _as_v11(state: SimState, reggie_skills: Array[String]) -> String:
	var data := JSON.parse_string(state.to_json()) as Dictionary
	data["save_version"] = 11
	data.erase("day")
	data.erase("stash")
	var crew := (data["workers"] as Dictionary)["gardeners"] as Array
	var single := (crew[0] as Dictionary).duplicate() if not crew.is_empty() else {"worker_id": "tom", "task": "none", "task_plot_id": -1, "task_ends_at": ExactFloat.encode(0.0), "next_check_at": ExactFloat.encode(0.0), "next_wage_at": ExactFloat.encode(0.0)}
	single["hired"] = not crew.is_empty()
	data["workers"] = single
	for item: Variant in (data["inventory"] as Dictionary)["products"] as Array:
		(item as Dictionary).erase("at_stash")
	(data["helper"] as Dictionary)["skills"] = reggie_skills
	return JSON.stringify(data)


func _v11_game() -> SimState:
	var state := SimState.new(_config(), 3)
	state.apply(HireWorkerCommand.new("dave"))
	state.inventory.create(state.config.strain.id, 60)
	state.inventory.create(state.config.strain.id, 80).packed = true
	state.apply(AdvanceTimeCommand.new(30.0))
	return state


func test_version_is_twelve_and_eleven_still_loads() -> void:
	assert_eq(SimState.SAVE_VERSION, 12)
	var state := _v11_game()
	assert_not_null(SimState.from_json(_as_v11(state, ["driving"] as Array[String]), state.config))


func test_a_v12_save_must_carry_the_day_and_the_stash() -> void:
	var state := _v11_game()
	var data := JSON.parse_string(state.to_json()) as Dictionary
	data.erase("stash")
	assert_null(SimState.from_json(JSON.stringify(data), state.config))


func test_goods_from_the_bunker_move_to_the_stash() -> void:
	var state := _v11_game()
	var loaded := SimState.from_json(_as_v11(state, ["driving"] as Array[String]), state.config)
	assert_eq(loaded.inventory.count(), 2)
	assert_true(loaded.inventory.farm_crates().is_empty(), "the bench and the shelf stood where the stash is now")
	assert_eq(loaded.packing.unpacked_count(), 1)


func test_jack_is_on_the_farm_and_the_day_clock_starts_at_load() -> void:
	var state := _v11_game()
	var loaded := SimState.from_json(_as_v11(state, ["driving"] as Array[String]), state.config)
	assert_eq(loaded.day.place, DayCycle.FARM)
	assert_false(loaded.day.travelling())
	assert_gt(loaded.day.next_evening_at, loaded.clock.elapsed_game_seconds)
	assert_lt(loaded.day.next_evening_at, loaded.clock.elapsed_game_seconds + SimClock.GAME_SECONDS_PER_DAY + 0.001)
	assert_false(loaded.stash.on_the_road())


func test_the_old_farmhand_becomes_the_first_gardener() -> void:
	var state := _v11_game()
	var loaded := SimState.from_json(_as_v11(state, ["driving"] as Array[String]), state.config)
	assert_eq(loaded.workers.gardeners().size(), 1)
	assert_true(loaded.workers.is_hired("dave"))


func test_an_old_save_without_a_farmhand_has_no_crew() -> void:
	var state := SimState.new(_config(), 3)
	var loaded := SimState.from_json(_as_v11(state, [] as Array[String]), state.config)
	assert_false(loaded.workers.hired)


func test_reggie_keeps_the_skills_that_still_matter_and_is_refunded_for_the_rest() -> void:
	var state := _v11_game()
	var money := state.economy.money
	var loaded := SimState.from_json(_as_v11(state, ["care", "driving", "prune", "pack"] as Array[String]), state.config)
	assert_eq(loaded.helper.skills, ["driving", "pack"] as Array[String])
	var refund := _balance.retired_skills["care"] + _balance.retired_skills["prune"]
	assert_eq(loaded.economy.money, money + refund)
	var refunds := loaded.event_log.of_type(EventLog.HELPER_SKILLS_REFUNDED)
	assert_eq(refunds.size(), 1)
	assert_eq(int(refunds[0].data["refund"]), refund)


func test_a_retired_course_in_progress_is_refunded_and_he_still_comes_back() -> void:
	var state := _v11_game()
	var data := JSON.parse_string(_as_v11(state, ["driving"] as Array[String])) as Dictionary
	var helper := data["helper"] as Dictionary
	helper["away_reason"] = Helper.AWAY_TRAINING
	helper["away_until"] = ExactFloat.encode(state.clock.elapsed_game_seconds + 3600.0)
	helper["training_skill_id"] = "fertilize"
	var loaded := SimState.from_json(JSON.stringify(data), state.config)
	assert_eq(loaded.economy.money, state.economy.money + _balance.retired_skills["fertilize"])
	loaded.apply(AdvanceTimeCommand.new(30.0))
	assert_true(loaded.helper.present())
	assert_false(loaded.helper.skills.has("fertilize"))


func test_a_migrated_game_runs_on_like_a_fresh_one_after_reload() -> void:
	var state := _v11_game()
	var loaded := SimState.from_json(_as_v11(state, ["care"] as Array[String]), state.config)
	var reloaded := SimState.from_json(loaded.to_json(), state.config)
	assert_eq(reloaded.to_json(), loaded.to_json())
	loaded.apply(AdvanceTimeCommand.new(120.0))
	reloaded.apply(AdvanceTimeCommand.new(120.0))
	assert_eq(reloaded.to_json(), loaded.to_json())
