extends GutTest

const BALANCE_PATH: String = "res://content/balance.tres"


func _balance() -> BalanceConfig:
	return load(BALANCE_PATH) as BalanceConfig


func test_balance_loads_with_strain() -> void:
	var balance := _balance()
	assert_not_null(balance)
	assert_not_null(balance.strain)
	assert_false(balance.strain.id.is_empty())


func test_game_day_is_ten_real_minutes() -> void:
	assert_eq(_balance().real_seconds_per_game_day, 600.0)


func test_balance_values_are_sane() -> void:
	var balance := _balance()
	var strain := balance.strain
	assert_gt(balance.plot_count, 0)
	assert_true(balance.starting_money >= 0)
	assert_gt(strain.seed_hours, 0.0)
	assert_gt(strain.sprout_hours, 0.0)
	assert_gt(strain.bush_hours, 0.0)
	assert_gt(strain.water_capacity_hours, 0.0)
	assert_between(strain.base_quality, 0, 100)
	assert_between(strain.quality_variance, 0, 100)
	assert_true(strain.dry_penalty_per_hour >= 0.0)
	assert_gt(strain.base_price, 0)
	assert_true(strain.price_mult_at_q100 > strain.price_mult_at_q0, "better quality must sell for more")
