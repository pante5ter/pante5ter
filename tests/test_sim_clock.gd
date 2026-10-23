extends GutTest

const TEN_REAL_MINUTES: float = 600.0


func test_ten_real_minutes_is_one_game_day() -> void:
	var clock := SimClock.new(TEN_REAL_MINUTES)
	assert_almost_eq(clock.real_to_game(TEN_REAL_MINUTES), SimClock.GAME_SECONDS_PER_DAY, 0.001)


func test_one_real_second_is_144_game_seconds() -> void:
	var clock := SimClock.new(TEN_REAL_MINUTES)
	assert_almost_eq(clock.real_to_game(1.0), 144.0, 0.0001)


func test_negative_real_time_does_not_rewind() -> void:
	var clock := SimClock.new(TEN_REAL_MINUTES)
	assert_eq(clock.real_to_game(-5.0), 0.0)
	clock.advance(-100.0)
	assert_eq(clock.elapsed_game_seconds, 0.0)


func test_advance_to_moves_forward_only() -> void:
	var clock := SimClock.new(TEN_REAL_MINUTES)
	clock.advance_to(500.0)
	assert_eq(clock.elapsed_game_seconds, 500.0)
	clock.advance_to(100.0)
	assert_eq(clock.elapsed_game_seconds, 500.0)


func test_day_and_hour_of_day() -> void:
	var clock := SimClock.new(TEN_REAL_MINUTES)
	clock.advance(SimClock.GAME_SECONDS_PER_DAY * 2.0 + SimClock.GAME_SECONDS_PER_HOUR * 6.5)
	assert_eq(clock.day(), 2)
	assert_almost_eq(clock.hour_of_day(), 6.5, 0.0001)


func test_round_trip() -> void:
	var clock := SimClock.new(TEN_REAL_MINUTES)
	clock.advance(12345.678)
	var restored := SimClock.new(TEN_REAL_MINUTES)
	restored.load_dict(clock.to_dict())
	assert_eq(restored.elapsed_game_seconds, clock.elapsed_game_seconds)
