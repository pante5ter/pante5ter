extends GutTest


func _sequence(rng: SimRng, length: int) -> Array[int]:
	var values: Array[int] = []
	for i: int in length:
		values.append(rng.randi_range(0, 1_000_000))
	return values


func test_same_seed_gives_same_sequence() -> void:
	assert_eq(_sequence(SimRng.new(42), 50), _sequence(SimRng.new(42), 50))


func test_different_seeds_give_different_sequences() -> void:
	assert_ne(_sequence(SimRng.new(1), 50), _sequence(SimRng.new(2), 50))


func test_randi_range_stays_in_bounds() -> void:
	var rng := SimRng.new(7)
	var out_of_bounds := 0
	for i: int in 500:
		var value := rng.randi_range(-3, 3)
		if value < -3 or value > 3:
			out_of_bounds += 1
	assert_eq(out_of_bounds, 0)


func test_reseed_restarts_sequence() -> void:
	var rng := SimRng.new(5)
	var first := _sequence(rng, 10)
	rng.reseed(5)
	assert_eq(_sequence(rng, 10), first)


func test_round_trip_continues_same_sequence() -> void:
	var original := SimRng.new(123456789)
	_sequence(original, 17)
	var restored := SimRng.new()
	restored.load_dict(original.to_dict())
	assert_eq(restored.get_seed(), 123456789)
	assert_eq(_sequence(restored, 30), _sequence(original, 30))


func test_round_trip_survives_json() -> void:
	var original := SimRng.new(-987654321987)
	_sequence(original, 3)
	var json_text := JSON.stringify(original.to_dict())
	var parsed: Dictionary = JSON.parse_string(json_text)
	var restored := SimRng.new()
	restored.load_dict(parsed)
	assert_eq(_sequence(restored, 30), _sequence(original, 30))
