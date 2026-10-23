extends GutTest

const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const ACTOR: String = "jack"

var _event_log: EventLog
var _inventory: Inventory


func before_each() -> void:
	_event_log = EventLog.new()
	_inventory = Inventory.new()


func _strain(base_quality: int = 60, variance: int = 0, dry_penalty: float = 5.0) -> StrainDef:
	var strain := StrainDef.new()
	strain.id = "test"
	strain.seed_hours = 1.0
	strain.sprout_hours = 2.0
	strain.bush_hours = 3.0
	strain.water_capacity_hours = 4.0
	strain.base_quality = base_quality
	strain.quality_variance = variance
	strain.dry_penalty_per_hour = dry_penalty
	return strain


func _grow(strain: StrainDef = _strain(), plot_count: int = 2, seed_value: int = 1) -> Grow:
	return Grow.new(strain, plot_count, SimRng.new(seed_value), _event_log, _inventory)


func _grow_to_ready(grow: Grow, plot_id: int) -> void:
	grow.plant(plot_id, 0.0, ACTOR)
	grow.water(plot_id, 0.0, ACTOR)
	grow.advance(0.0, 4.0 * HOUR)
	grow.water(plot_id, 4.0 * HOUR, ACTOR)
	grow.advance(4.0 * HOUR, 2.0 * HOUR)


func test_plant_puts_seed_and_logs_event() -> void:
	var grow := _grow()
	var result := grow.plant(0, 10.0, ACTOR)
	assert_true(result.ok)
	assert_eq(grow.plot(0).stage, Plot.Stage.SEED)
	var event := _event_log.last()
	assert_eq(event.type, EventLog.PLOT_PLANTED)
	assert_eq(event.game_time, 10.0)
	assert_eq(event.actors, PackedStringArray([ACTOR, "plot:0"]))


func test_plant_on_occupied_plot_fails() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	var result := grow.plant(0, 0.0, ACTOR)
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.PLOT_OCCUPIED)
	assert_eq(_event_log.size(), 1)


func test_invalid_plot_id_fails() -> void:
	var grow := _grow()
	assert_eq(grow.plant(-1, 0.0, ACTOR).error, CommandResult.INVALID_PLOT)
	assert_eq(grow.water(2, 0.0, ACTOR).error, CommandResult.INVALID_PLOT)
	assert_eq(grow.harvest(99, 0.0, ACTOR).error, CommandResult.INVALID_PLOT)


func test_growth_without_water_stands_still() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	grow.advance(0.0, 100.0 * HOUR)
	var plot := grow.plot(0)
	assert_eq(plot.stage, Plot.Stage.SEED)
	assert_eq(plot.progress_seconds, 0.0)
	assert_eq(plot.dry_seconds, 100.0 * HOUR)
	assert_eq(_event_log.of_type(EventLog.PLOT_STAGE_CHANGED).size(), 0)


func test_growth_stops_exactly_when_water_runs_out() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	grow.water(0, 0.0, ACTOR)
	grow.advance(0.0, 10.0 * HOUR)
	var plot := grow.plot(0)
	assert_eq(plot.stage, Plot.Stage.BUSH)
	assert_eq(plot.progress_seconds, 1.0 * HOUR)
	assert_eq(plot.water_seconds, 0.0)
	assert_eq(plot.dry_seconds, 6.0 * HOUR)
	var dried := _event_log.of_type(EventLog.PLOT_DRIED_OUT)
	assert_eq(dried.size(), 1)
	assert_eq(dried[0].game_time, 4.0 * HOUR)


func test_watering_resumes_growth() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	grow.advance(0.0, 5.0 * HOUR)
	grow.water(0, 5.0 * HOUR, ACTOR)
	grow.advance(5.0 * HOUR, 1.0 * HOUR)
	assert_eq(grow.plot(0).stage, Plot.Stage.SPROUT)


func test_full_cycle_seed_sprout_bush_ready() -> void:
	var grow := _grow()
	_grow_to_ready(grow, 0)
	assert_eq(grow.plot(0).stage, Plot.Stage.READY)
	var stages: Array[String] = []
	var times: Array[float] = []
	for event: SimEvent in _event_log.of_type(EventLog.PLOT_STAGE_CHANGED):
		stages.append(String(event.data["stage"]))
		times.append(event.game_time)
	assert_eq(stages, ["sprout", "bush", "ready"])
	assert_eq(times, [1.0 * HOUR, 3.0 * HOUR, 6.0 * HOUR])


func test_ready_plot_does_not_keep_growing() -> void:
	var grow := _grow()
	_grow_to_ready(grow, 0)
	grow.advance(6.0 * HOUR, 50.0 * HOUR)
	assert_eq(grow.plot(0).stage, Plot.Stage.READY)
	assert_eq(grow.plot(0).dry_seconds, 0.0)


func test_one_big_step_equals_many_small_steps() -> void:
	var big := _grow()
	var small := _grow()
	for grow: Grow in [big, small]:
		grow.plant(0, 0.0, ACTOR)
		grow.water(0, 0.0, ACTOR)
	big.advance(0.0, 8.0 * HOUR)
	var now := 0.0
	for i: int in 480:
		small.advance(now, 60.0)
		now += 60.0
	assert_eq(JSON.stringify(small.to_array()), JSON.stringify(big.to_array()))


func test_water_requires_growing_plant() -> void:
	var grow := _grow()
	assert_eq(grow.water(0, 0.0, ACTOR).error, CommandResult.PLOT_NOT_GROWING)
	_grow_to_ready(grow, 0)
	assert_eq(grow.water(0, 0.0, ACTOR).error, CommandResult.PLOT_NOT_GROWING)


func test_harvest_before_ready_fails() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	var result := grow.harvest(0, 0.0, ACTOR)
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.PLOT_NOT_READY)
	assert_eq(_inventory.count(), 0)


func test_harvest_gives_product_and_empties_plot() -> void:
	var grow := _grow()
	_grow_to_ready(grow, 0)
	var result := grow.harvest(0, 6.0 * HOUR, ACTOR)
	assert_true(result.ok)
	var product := _inventory.find(result.value)
	assert_not_null(product)
	assert_eq(product.strain_id, "test")
	assert_eq(product.quality, 60)
	assert_eq(grow.plot(0).stage, Plot.Stage.EMPTY)
	assert_eq(_event_log.last().type, EventLog.PLOT_HARVESTED)


func test_dry_time_lowers_quality() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	grow.advance(0.0, 2.0 * HOUR)
	grow.water(0, 2.0 * HOUR, ACTOR)
	grow.advance(2.0 * HOUR, 4.0 * HOUR)
	grow.water(0, 6.0 * HOUR, ACTOR)
	grow.advance(6.0 * HOUR, 2.0 * HOUR)
	var product := _inventory.find(grow.harvest(0, 8.0 * HOUR, ACTOR).value)
	assert_eq(product.quality, 50)


func test_quality_is_clamped_to_zero() -> void:
	var grow := _grow(_strain(10, 0, 100.0))
	grow.plant(0, 0.0, ACTOR)
	grow.advance(0.0, 5.0 * HOUR)
	grow.water(0, 5.0 * HOUR, ACTOR)
	grow.advance(5.0 * HOUR, 4.0 * HOUR)
	grow.water(0, 9.0 * HOUR, ACTOR)
	grow.advance(9.0 * HOUR, 2.0 * HOUR)
	assert_eq(_inventory.find(grow.harvest(0, 11.0 * HOUR, ACTOR).value).quality, 0)


func test_quality_stays_within_variance_and_0_100() -> void:
	var grow := _grow(_strain(95, 10, 0.0))
	var qualities: Array[int] = []
	for i: int in 40:
		_grow_to_ready(grow, 0)
		qualities.append(_inventory.find(grow.harvest(0, 0.0, ACTOR).value).quality)
	assert_between(qualities.min() as int, 85, 100)
	assert_between(qualities.max() as int, 85, 100)
	assert_eq(qualities.max(), 100, "variance above 100 must clamp")


func test_round_trip_preserves_plots() -> void:
	var grow := _grow()
	grow.plant(0, 0.0, ACTOR)
	grow.water(0, 0.0, ACTOR)
	grow.advance(0.0, 2.5 * HOUR)
	var restored := _grow()
	restored.load_array(JSON.parse_string(JSON.stringify(grow.to_array(), "", true, true)) as Array)
	assert_eq(JSON.stringify(restored.to_array()), JSON.stringify(grow.to_array()))
	assert_eq(restored.plot(0).stage, Plot.Stage.SPROUT)
