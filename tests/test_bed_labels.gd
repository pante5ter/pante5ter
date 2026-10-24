extends GutTest

const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 3


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()
	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(42)


func _open() -> Level:
	var level := (load(PLANTATION_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _bed(level: Level, plot_id: int) -> PlotView:
	return (level.get_node("NavRegion/PlotsGrid") as PlotsGrid).view_for(plot_id)


func _hours_to_real(hours: float) -> float:
	return hours * Game.sim.config.real_seconds_per_game_day / 24.0


func test_a_bed_label_is_faint_and_short_until_hovered() -> void:
	var level := await _open()
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.apply(WaterCommand.new(0))
	var bed := _bed(level, 0)
	await wait_process_frames(2)
	assert_eq(bed.label.text, bed.title())
	assert_lt(bed.label.modulate.a, 0.6)
	assert_lt(bed.label.font_size, PlotView.FULL_FONT)
	bed.hovered = true
	await wait_process_frames(2)
	assert_string_contains(bed.label.text, "до сбора")
	assert_almost_eq(bed.label.modulate.a, 1.0, 0.001)
	assert_eq(bed.label.font_size, PlotView.FULL_FONT)
	bed.hovered = false
	await wait_process_frames(2)
	assert_eq(bed.label.text, bed.title())


func test_a_healthy_watered_bed_wears_no_badge() -> void:
	var level := await _open()
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.apply(WaterCommand.new(0))
	await wait_process_frames(2)
	assert_false(_bed(level, 0).badge.visible)
	assert_false(_bed(level, 1).badge.visible, "an empty bed needs nothing urgent")


func test_dry_sick_and_ripe_beds_keep_a_clear_badge() -> void:
	var level := await _open()
	Game.sim.apply(PlantCommand.new(0))
	Game.sim.apply(PlantCommand.new(1))
	Game.sim.apply(WaterCommand.new(1))
	Game.sim.grow.plot(1).problem = Problems.PESTS
	Game.sim.apply(PlantCommand.new(2))
	var guard := 0
	while Game.sim.grow.plot(2).stage != Plot.Stage.READY and guard < 200:
		Game.sim.apply(WaterCommand.new(2))
		Game.sim.grow.plot(1).problem = Problems.PESTS
		Game.sim.grow.plot(0).water_seconds = 0.0
		Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(0.25)))
		guard += 1
	Game.sim.grow.plot(0).water_seconds = 0.0
	await wait_process_frames(2)
	var dry := _bed(level, 0)
	var sick := _bed(level, 1)
	var ripe := _bed(level, 2)
	assert_true(dry.badge.visible)
	assert_eq(dry.badge.texture, BedBadge.texture(BedBadge.DRY))
	assert_true(sick.badge.visible)
	assert_eq(sick.badge.texture, BedBadge.texture(BedBadge.PROBLEM))
	assert_true(ripe.badge.visible)
	assert_eq(ripe.badge.texture, BedBadge.texture(BedBadge.READY))
	assert_almost_eq(dry.badge.modulate.a, 1.0, 0.001, "the badge is not faded with the label")
	assert_string_contains(ripe.label.text, "созрела", "the faint label keeps one word for a bed that needs a hand")
	assert_string_contains(dry.label.text, "СУХО")


func test_badges_are_distinct_round_pictograms() -> void:
	var dry := BedBadge.texture(BedBadge.DRY).get_image()
	var sick := BedBadge.texture(BedBadge.PROBLEM).get_image()
	assert_eq(dry.get_width(), BedBadge.SIZE)
	assert_almost_eq(dry.get_pixel(0, 0).a, 0.0, 0.01, "corners are transparent")
	assert_almost_eq(dry.get_pixel(32, 40).a, 1.0, 0.01)
	assert_ne(dry.get_pixel(32, 56), sick.get_pixel(32, 56), "each kind has its own colour")
	assert_eq(BedBadge.texture(BedBadge.DRY), BedBadge.texture(BedBadge.DRY), "drawn once and reused")
