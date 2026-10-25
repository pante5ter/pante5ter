extends GutTest

## Playtest round 4: untreated pests eat the harvest, not only the time.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const STEP_HOURS: float = 0.25

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _config() -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = 5000
	config.first_day = null
	config.director = null
	config.helper = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.suspicion = _balance.suspicion.duplicate() as SuspicionDef
	config.suspicion.inspection_threshold = 1000.0
	# Flat yield, so what the pests ate is the only thing that changes the count.
	config.strain = _balance.strain.duplicate() as StrainDef
	config.strain.bonus_yield_max = 0
	return config


func _advance(state: SimState, hours: float) -> void:
	state.apply(AdvanceTimeCommand.new(hours * HOUR * state.config.real_seconds_per_game_day / SimClock.GAME_SECONDS_PER_DAY))


## A fertilized basic bed: two units when nothing goes wrong.
func _bed(state: SimState) -> Plot:
	state.supplies.fertilizer = 1
	assert_true(state.apply(PlantCommand.new(0)).ok)
	assert_true(state.apply(FertilizeCommand.new(0)).ok)
	return state.grow.plot(0)


func _pests_for(state: SimState, bed: Plot, hours: float) -> void:
	bed.problem = Problems.PESTS
	var done := 0.0
	while done < hours - 0.000001:
		_advance(state, minf(STEP_HOURS, hours - done))
		done += STEP_HOURS
	bed.problem = ""


func _grow_to_ready(state: SimState, bed: Plot) -> void:
	for step: int in 200:
		if bed.stage == Plot.Stage.READY:
			return
		state.apply(WaterCommand.new(bed.id))
		_advance(state, STEP_HOURS)
	fail_test("the bed never ripened")


func _harvested(state: SimState) -> int:
	var harvests := state.event_log.of_type(EventLog.PLOT_HARVESTED)
	return int(harvests[harvests.size() - 1].data["quantity"]) if not harvests.is_empty() else 0


func test_content_lets_pests_eat() -> void:
	assert_gt(_balance.problems.pest_hours_per_lost_unit, 0.0)


func test_a_clean_bed_gives_its_full_yield() -> void:
	var state := SimState.new(_config(), 1)
	var bed := _bed(state)
	_grow_to_ready(state, bed)
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_eq(_harvested(state), 2)


func test_untreated_pests_take_units_off_the_harvest() -> void:
	var state := SimState.new(_config(), 1)
	var bed := _bed(state)
	_pests_for(state, bed, state.config.problems.pest_hours_per_lost_unit + STEP_HOURS)
	_grow_to_ready(state, bed)
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_eq(_harvested(state), 1, "one unit eaten")
	assert_eq(int(state.event_log.of_type(EventLog.PLOT_HARVESTED)[0].data["eaten"]), 1)


func test_pests_left_long_enough_eat_everything() -> void:
	var state := SimState.new(_config(), 1)
	var bed := _bed(state)
	_pests_for(state, bed, state.config.problems.pest_hours_per_lost_unit * 2.0 + STEP_HOURS)
	_grow_to_ready(state, bed)
	var products := state.inventory.count()
	assert_eq(state.apply(HarvestCommand.new(0)).error, CommandResult.CROP_EATEN)
	assert_eq(bed.stage, Plot.Stage.EMPTY, "the bed is cleared for a new planting")
	assert_eq(state.inventory.count(), products)
	assert_eq(state.event_log.of_type(EventLog.PLOT_CROP_EATEN).size(), 1)


func test_other_problems_do_not_eat() -> void:
	var state := SimState.new(_config(), 1)
	var bed := _bed(state)
	bed.problem = Problems.MOLD
	_advance(state, state.config.problems.pest_hours_per_lost_unit * 3.0)
	bed.problem = ""
	_grow_to_ready(state, bed)
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_eq(_harvested(state), 2)


func test_one_big_step_eats_as_much_as_many_small_ones() -> void:
	var big := SimState.new(_config(), 1)
	var small := SimState.new(_config(), 1)
	var big_bed := _bed(big)
	var small_bed := _bed(small)
	big_bed.problem = Problems.PESTS
	small_bed.problem = Problems.PESTS
	_advance(big, 5.0)
	for step: int in 20:
		_advance(small, STEP_HOURS)
	assert_eq(big_bed.to_dict(), small_bed.to_dict())


func test_eaten_time_survives_a_save() -> void:
	var state := SimState.new(_config(), 1)
	var bed := _bed(state)
	_pests_for(state, bed, 2.0)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.grow.plot(0).to_dict(), bed.to_dict())
	assert_gt(loaded.grow.plot(0).pest_seconds, 0.0)
