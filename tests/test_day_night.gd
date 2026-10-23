extends GutTest


func test_noon_is_the_overcast_day_preset() -> void:
	var day_night := DayNight.new()
	var noon := day_night.preset_for_hour(12.0)
	assert_eq(noon["sun"], DayNight.DAY["sun"])
	assert_false(day_night.is_raining(12.0))
	day_night.free()


func test_it_rains_at_dusk_and_at_night() -> void:
	var day_night := DayNight.new()
	assert_true(day_night.is_raining(19.0))
	assert_true(day_night.is_raining(2.0))
	day_night.free()


func test_presets_blend_smoothly_through_the_day() -> void:
	var day_night := DayNight.new()
	var previous := float(day_night.preset_for_hour(0.0)["energy"])
	for step: int in range(1, 97):
		var energy := float(day_night.preset_for_hour(float(step) * 0.25)["energy"])
		assert_lt(absf(energy - previous), 0.1, "light jumps at hour %.2f" % (float(step) * 0.25))
		previous = energy
	day_night.free()
