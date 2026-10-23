extends GutTest

var _event_log: EventLog
var _inventory: Inventory
var _economy: Economy


func before_each() -> void:
	var strain := StrainDef.new()
	strain.id = "test"
	strain.base_price = 100
	strain.price_mult_at_q0 = 0.5
	strain.price_mult_at_q100 = 2.0
	_event_log = EventLog.new()
	_inventory = Inventory.new()
	_economy = Economy.new(strain, 500, _event_log, _inventory)


func test_starting_money() -> void:
	assert_eq(_economy.money, 500)


func test_price_at_quality_bounds() -> void:
	assert_eq(_economy.price_for(0), 50)
	assert_eq(_economy.price_for(100), 200)
	assert_eq(_economy.price_for(50), 125)


func test_price_grows_with_quality() -> void:
	var previous := _economy.price_for(0)
	var never_decreases := true
	for quality: int in range(1, 101):
		var price := _economy.price_for(quality)
		if price < previous:
			never_decreases = false
		previous = price
	assert_true(never_decreases)
	assert_gt(_economy.price_for(80), _economy.price_for(20))


func test_price_clamps_out_of_range_quality() -> void:
	assert_eq(_economy.price_for(-20), _economy.price_for(0))
	assert_eq(_economy.price_for(150), _economy.price_for(100))


func test_sell_adds_money_removes_product_and_logs() -> void:
	var product := _inventory.create("test", 100)
	var result := _economy.sell(product.id, 42.0, "jack")
	assert_true(result.ok)
	assert_eq(result.value, 200)
	assert_eq(_economy.money, 700)
	assert_eq(_inventory.count(), 0)
	var event := _event_log.last()
	assert_eq(event.type, EventLog.PRODUCT_SOLD)
	assert_eq(event.game_time, 42.0)
	assert_eq(event.actors, PackedStringArray(["jack", Economy.BUYER_ACTOR]))
	assert_eq(int(event.data["price"]), 200)


func test_sell_unknown_product_fails_without_side_effects() -> void:
	var result := _economy.sell(999, 0.0, "jack")
	assert_false(result.ok)
	assert_eq(result.error, CommandResult.UNKNOWN_PRODUCT)
	assert_eq(_economy.money, 500)
	assert_eq(_event_log.size(), 0)


func test_cannot_sell_same_product_twice() -> void:
	var product := _inventory.create("test", 50)
	assert_true(_economy.sell(product.id, 0.0, "jack").ok)
	assert_false(_economy.sell(product.id, 0.0, "jack").ok)
	assert_eq(_economy.money, 625)


func test_round_trip() -> void:
	_economy.money = 1234
	var data: Dictionary = JSON.parse_string(JSON.stringify(_economy.to_dict()))
	_economy.money = 0
	_economy.load_dict(data)
	assert_eq(_economy.money, 1234)
