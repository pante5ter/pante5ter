extends GutTest

const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const QUALITY: int = 60


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()
	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(42)


func _accepted_order(quantity: int = 2) -> Order:
	var sim := Game.sim
	var order := sim.orders.inject(quantity, QUALITY, 600, 2.0, 24.0, false, sim.clock.elapsed_game_seconds)
	assert_true(sim.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	return order


func _stock(count: int, quality: int, packed: bool) -> void:
	for index: int in count:
		Game.sim.inventory.create(Game.sim.config.strain.id, quality).packed = packed


func test_without_boxes_the_reason_names_the_quality_needed() -> void:
	var order := _accepted_order()
	var reason := DispatchText.blocked_reason(order, Helper.ACTOR, Game.sim)
	assert_string_contains(reason, "нет расфасованного товара качества %d+" % QUALITY)
	assert_string_contains(reason, "коробок 0 из 2")
	_stock(1, QUALITY - 5, true)
	assert_string_contains(DispatchText.blocked_reason(order, Helper.ACTOR, Game.sim), "коробок 0 из 2", "weaker boxes do not count")


func test_unpacked_harvest_is_pointed_at_the_bench() -> void:
	var order := _accepted_order()
	_stock(1, QUALITY, true)
	_stock(3, QUALITY + 10, false)
	var reason := DispatchText.blocked_reason(order, Helper.ACTOR, Game.sim)
	assert_string_contains(reason, "коробок 1 из 2")
	assert_string_contains(reason, "ещё 3 шт. ждут фасовки")


func test_a_ready_order_has_no_reason() -> void:
	var order := _accepted_order()
	_stock(2, QUALITY, true)
	assert_eq(DispatchText.blocked_reason(order, Helper.ACTOR, Game.sim), "")


func test_lying_low_comes_first() -> void:
	var order := _accepted_order()
	Game.sim.apply(LieLowCommand.new(true))
	assert_string_contains(DispatchText.blocked_reason(order, Helper.ACTOR, Game.sim), "ферма затихла")


func test_a_courier_on_the_road_says_when_he_is_back() -> void:
	var sim := Game.sim
	var order := _accepted_order()
	_stock(2, QUALITY, true)
	var courier := sim.config.courier_candidates[0].id
	sim.economy.earn(10000)
	assert_true(sim.apply(HireCourierCommand.new(courier)).ok)
	sim.couriers.busy_until[courier] = sim.clock.elapsed_game_seconds + SimClock.GAME_SECONDS_PER_HOUR
	assert_string_contains(DispatchText.blocked_reason(order, courier, sim), "в дороге, вернётся через")


func test_the_disabled_buttons_on_the_computer_say_why() -> void:
	var level := (load(PLANTATION_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	Game.is_running = false
	var order := _accepted_order()
	level.hud.open_computer()
	var buttons := level.hud.computer.dispatch_buttons(order.id)
	assert_gt(buttons.size(), 0)
	for button: Button in buttons:
		assert_true(button.disabled)
		assert_string_contains(button.text, "нет расфасованного товара качества %d+" % QUALITY)
		assert_string_contains(button.tooltip_text, "коробок 0 из 2")
	_stock(2, QUALITY, true)
	level.hud.computer.refresh()
	buttons = level.hud.computer.dispatch_buttons(order.id)
	assert_false(buttons[0].disabled)
	assert_false(buttons[0].text.contains(" — "), "an enabled button needs no excuse")
