extends GutTest

## Playtest round 4: "Reggie fixed a burned lamp without any lamp, and the lamp I bought won't go in".

const BALANCE_PATH: String = "res://content/balance.tres"

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config(skills: Array[String] = []) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = 5000
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	var helper := _balance.helper.duplicate() as WorkerDef
	helper.starting_skills = skills
	config.helper = helper
	config.first_day = null
	config.director = null
	return config


func _advance(state: SimState, hours: float) -> void:
	var done := 0.0
	while done < hours - 0.0001:
		var step := minf(0.25, hours - done)
		state.apply(AdvanceTimeCommand.new(step * SimClock.GAME_SECONDS_PER_HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))
		done += step


func _bring_lamp(state: SimState) -> void:
	assert_true(state.apply(BuyCommand.new(Supplies.LAMP, 1)).ok)
	_advance(state, state.config.delivery_hours + 0.25)
	assert_true(state.apply(PickUpParcelCommand.new()).ok)


func _burned_bed(state: SimState) -> Plot:
	assert_true(state.apply(PlantCommand.new(0)).ok)
	var bed := state.grow.plot(0)
	bed.problem = Problems.LAMP
	return bed


func test_there_is_a_course_that_teaches_lamp_work() -> void:
	var found := false
	for skill: SkillDef in _balance.skills:
		found = found or skill.kind == SkillDef.ELECTRICS
	assert_true(found)


func test_reggie_without_the_course_leaves_a_burned_lamp_alone_even_with_a_spare() -> void:
	var state := SimState.new(_config(), 1)
	_bring_lamp(state)
	var bed := _burned_bed(state)
	_advance(state, 2.0)
	assert_eq(bed.problem, Problems.LAMP, "lamps are not his trade yet")
	assert_eq(state.supplies.count(Supplies.LAMP), 1, "the spare is still on the shelf")


func test_reggie_with_the_course_needs_a_lamp_from_stock() -> void:
	var state := SimState.new(_config(["electrics"] as Array[String]), 1)
	var bed := _burned_bed(state)
	_advance(state, 1.0)
	assert_eq(bed.problem, Problems.LAMP, "no spare lamp, nothing to put in")
	_bring_lamp(state)
	_advance(state, 1.0)
	assert_eq(bed.problem, "")
	assert_eq(state.supplies.count(Supplies.LAMP), 0, "he used the spare")
	var treated := state.event_log.of_type(EventLog.PLOT_TREATED)
	assert_eq(treated.size(), 1)
	assert_true(treated[0].actors.has(Helper.ACTOR))


func test_jack_puts_a_bought_lamp_in_himself() -> void:
	var state := SimState.new(_config(), 1)
	var bed := _burned_bed(state)
	assert_eq(state.apply(TreatCommand.new(0)).error, CommandResult.NO_SUPPLY)
	_bring_lamp(state)
	assert_eq(state.supplies.count(Supplies.LAMP), 1)
	assert_true(state.apply(TreatCommand.new(0)).ok)
	assert_eq(bed.problem, "")
	assert_eq(state.supplies.count(Supplies.LAMP), 0)


func test_a_bed_jack_fixed_while_reggie_walked_over_costs_one_lamp() -> void:
	var state := SimState.new(_config(["electrics"] as Array[String]), 1)
	_bring_lamp(state)
	var bed := _burned_bed(state)
	_advance(state, 0.25)
	if state.helper.task == Workers.Task.TREAT:
		assert_true(state.apply(TreatCommand.new(0)).ok)
	_advance(state, 1.0)
	assert_eq(bed.problem, "")
	assert_eq(state.supplies.count(Supplies.LAMP), 0)
	assert_eq(state.event_log.of_type(EventLog.PLOT_TREATED).size(), 1, "one lamp, one fix")


func test_the_objective_says_where_a_missing_lamp_comes_from() -> void:
	var state := SimState.new(_config(), 1)
	_burned_bed(state)
	assert_string_contains(UiText.objective(state), "На складе нет: запасная лампа")
	_bring_lamp(state)
	assert_string_contains(UiText.objective(state), "вылечите её на плантации")
