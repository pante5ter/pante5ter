extends GutTest


func test_round_trip_is_bit_exact() -> void:
	var values: Array[float] = [0.0, -0.0, 1.0, -3.5, 31.164320000000018, 1.0 / 3.0, 86400.0 * 365.0, 1e-300, 1.7976931348623157e308]
	for value: float in values:
		var restored := ExactFloat.decode(JSON.parse_string(JSON.stringify(ExactFloat.encode(value))))
		assert_eq(restored, value)


func test_encoding_is_sixteen_hex_digits() -> void:
	assert_eq(ExactFloat.encode(2.5).length(), ExactFloat.ENCODED_LENGTH)


func test_garbage_decodes_to_nan() -> void:
	assert_true(is_nan(ExactFloat.decode(12.0)))
	assert_true(is_nan(ExactFloat.decode("abc")))
	assert_true(is_nan(ExactFloat.decode(null)))
