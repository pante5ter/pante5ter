extends GutTest


func test_create_assigns_unique_increasing_ids() -> void:
	var inventory := Inventory.new()
	var first := inventory.create("basic", 50)
	var second := inventory.create("basic", 70)
	assert_ne(first.id, second.id)
	assert_gt(second.id, first.id)
	assert_eq(inventory.count(), 2)


func test_find_and_take() -> void:
	var inventory := Inventory.new()
	var product := inventory.create("basic", 55)
	assert_eq(inventory.find(product.id), product)
	assert_eq(inventory.take(product.id), product)
	assert_null(inventory.find(product.id))
	assert_null(inventory.take(product.id))
	assert_eq(inventory.count(), 0)


func test_ids_are_not_reused_after_take() -> void:
	var inventory := Inventory.new()
	var first := inventory.create("basic", 10)
	inventory.take(first.id)
	assert_ne(inventory.create("basic", 10).id, first.id)


func test_round_trip_keeps_products_and_next_id() -> void:
	var inventory := Inventory.new()
	inventory.create("basic", 40)
	inventory.take(inventory.create("basic", 60).id)
	inventory.create("basic", 80)
	var restored := Inventory.new()
	restored.load_dict(JSON.parse_string(JSON.stringify(inventory.to_dict())) as Dictionary)
	assert_eq(JSON.stringify(restored.to_dict()), JSON.stringify(inventory.to_dict()))
	assert_eq(restored.create("basic", 1).id, 4)
