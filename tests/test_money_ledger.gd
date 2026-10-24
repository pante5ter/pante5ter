extends GutTest

const EXTRA: int = 20000


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()
	Game.is_running = false


func after_each() -> void:
	Game.new_game(42)


func _sum(sim: SimState) -> int:
	var total := 0
	for entry: MoneyLedger.Entry in MoneyLedger.entries(sim):
		total += entry.amount
	return total


func _reasons(sim: SimState) -> String:
	var lines := PackedStringArray()
	for entry: MoneyLedger.Entry in MoneyLedger.entries(sim):
		lines.append("%d %s" % [entry.amount, entry.reason])
	return "\n".join(lines)


func _hours(sim: SimState, hours: float) -> void:
	sim.apply(AdvanceTimeCommand.new(hours * sim.config.real_seconds_per_game_day / 24.0))


func test_the_ledger_accounts_for_every_pound_over_a_busy_stretch() -> void:
	var sim := Game.sim
	var base := sim.economy.money - _sum(sim)
	sim.economy.earn(EXTRA)
	sim.progress.reached = sim.config.milestones.size()
	assert_true(sim.apply(BuyPlotCommand.new()).ok)
	assert_true(sim.apply(BuyCommand.new(Supplies.FERTILIZER, 2)).ok)
	assert_true(sim.apply(HireWorkerCommand.new("dave")).ok)
	assert_true(sim.apply(HireCourierCommand.new(sim.config.courier_candidates[0].id)).ok)
	var product := sim.inventory.create(sim.config.strain.id, 70)
	assert_true(sim.apply(SellCommand.new(product.id)).ok)
	sim.raids.pending = true
	sim.raids.deadline = sim.clock.elapsed_game_seconds + SimClock.GAME_SECONDS_PER_HOUR
	assert_true(sim.apply(RaidCommand.new(Raids.PAY)).ok)
	if not sim.config.skills.is_empty():
		sim.apply(LearnSkillCommand.new(sim.config.skills[0].id))
	for hour: int in 24 * 4:
		_hours(sim, 1.0)
		var story := sim.stories.pending()
		if story != null:
			sim.apply(ChooseCommand.new(story.id, 0))
	assert_eq(sim.economy.money, base + EXTRA + _sum(sim), "ledger and purse disagree:\n%s" % _reasons(sim))
	var text := _reasons(sim)
	for reason: String in ["Новая грядка", "Покупка:", "Найм:", "Найм курьера", "Продажа", "Откуп", "Зарплата"]:
		assert_string_contains(text, reason)


func test_reasons_name_who_was_paid_and_why() -> void:
	var sim := Game.sim
	sim.economy.earn(EXTRA)
	sim.apply(HireWorkerCommand.new("dave"))
	sim.apply(BuyPlotCommand.new())
	_hours(sim, 24.0 * 3.0)
	var text := _reasons(sim)
	var dave := sim.config.find_worker("dave")
	assert_string_contains(text, "Зарплата: %s" % dave.display_name)
	assert_string_contains(text, "Найм: %s" % dave.display_name)
	assert_string_contains(text, "Новая грядка")
	if sim.rent.amount() > 0:
		assert_string_contains(text, "Аренда лорду")


func test_a_paid_order_shows_the_reward_and_the_couriers_cut_apart() -> void:
	var sim := Game.sim
	var courier := sim.config.courier_candidates[0]
	var event := sim.event_log.record(EventLog.ORDER_PAID, 10.0, PackedStringArray([courier.id, "order:4"]), {
		"order_id": 4, "courier_id": courier.id, "reward": 500, "fee": 75, "money": 1000,
	})
	var found := MoneyLedger.of_event(event, sim)
	assert_eq(found.size(), 2)
	assert_eq(found[0].amount, 500)
	assert_string_contains(found[0].reason, "#4")
	assert_eq(found[1].amount, -75)
	assert_string_contains(found[1].reason, courier.display_name)


func test_totals_split_income_and_spending_by_time() -> void:
	var sim := Game.sim
	var day := SimClock.GAME_SECONDS_PER_DAY
	sim.event_log.record(EventLog.PRODUCT_SOLD, day + 10.0, PackedStringArray(["jack"]), {"price": 300, "quality": 50})
	sim.event_log.record(EventLog.PLOT_BOUGHT, day + 20.0, PackedStringArray(["jack"]), {"cost": 400, "plot_id": 6})
	sim.event_log.record(EventLog.PRODUCT_SOLD, day * 2.0 + 5.0, PackedStringArray(["jack"]), {"price": 900, "quality": 90})
	var second_day := MoneyLedger.totals(sim, day, day * 2.0)
	assert_eq(second_day, Vector2i(300, 400))
	var third_day := MoneyLedger.totals(sim, day * 2.0, day * 3.0)
	assert_eq(third_day, Vector2i(900, 0))
