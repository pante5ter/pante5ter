extends GutTest

## Playtest round 5, balance: no money to hire at the start, clients who hang up too soon,
## the same harvest every time, every client wanting the same thing, gardeners who plant whatever.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func before_each() -> void:
	Game.new_game(7)
	Game.sim.first_day.skip()
	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(7)


## Little enough money that the empire stays below the level that unlocks elite.
func _calm(money: int = 1000, seed_value: int = 3) -> SimState:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	return SimState.new(config, seed_value)


func _advance(state: SimState, hours: float) -> void:
	var elapsed := 0.0
	while elapsed < hours - 0.000001:
		var step := minf(0.25, hours - elapsed)
		state.apply(AdvanceTimeCommand.new(step * HOUR * state.config.real_seconds_per_game_day / DAY))
		elapsed += step


func _real_seconds(game_hours: float) -> float:
	return game_hours * HOUR * _balance.real_seconds_per_game_day / DAY


func _texts(root: Node) -> String:
	var parts := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


func _strain_name(strain_id: String) -> String:
	return _balance.find_strain(strain_id).display_name


# --- 1. «Не на что нанять людей»

## Playtest 6 trimmed the purse: the first day is covered, the second is paid from the first sales.
func test_starting_money_hires_a_gardener_and_stocks_up_for_the_first_day() -> void:
	var dearest := 0
	for candidate: WorkerDef in _balance.candidates():
		dearest = maxi(dearest, candidate.daily_wage)
	var state := _calm(_balance.starting_money)
	var basket := state.supplies.basket_cost()
	var first_day := dearest + _balance.helper.daily_wage + basket
	assert_gte(_balance.starting_money, first_day, "the dearest gardener, Reggie and the usual basket")


func test_the_bigger_purse_does_not_hand_out_the_first_level() -> void:
	var state := _calm(_balance.starting_money)
	assert_eq(state.progress.reached, 0)
	assert_lt(state.empire_value(), _balance.milestones[0].value)


func test_at_the_start_jack_can_hire_and_restock_on_the_same_morning() -> void:
	var state := _calm(_balance.starting_money)
	assert_true(state.apply(HireWorkerCommand.new("tom")).ok)
	assert_true(state.apply(RestockCommand.new()).ok)
	assert_eq(state.supplies.basket_cost(), 0, "the whole basket was affordable")
	assert_gte(state.economy.money, _balance.helper.daily_wage, "Reggie's wage is still there")


# --- 2. «Клиент не дождался»

func test_a_caller_holds_the_line_for_at_least_a_real_minute() -> void:
	assert_gte(_real_seconds(_balance.orders.answer_hours), 60.0)


func test_the_deadline_covers_growing_hauling_packing_and_the_drive() -> void:
	var classic := _balance.find_strain("classic")
	var travel := _balance.day.travel_minutes / 60.0
	var packing := _balance.orders.pack_minutes_per_unit * float(_balance.orders.quantity_max) / 60.0
	var needed := classic.growth_hours() + travel + _balance.stash.haul_hours + packing + _balance.orders.trip_hours
	assert_gt(_balance.orders.deadline_hours, needed, "a fresh bed of «%s» makes it in time" % classic.display_name)


func test_urgent_calls_keep_their_share_of_the_longer_windows() -> void:
	var director := _balance.director
	assert_almost_eq(director.urgent_deadline_hours / _balance.orders.deadline_hours, 0.5, 0.001)
	assert_gte(_real_seconds(director.urgent_answer_hours), 30.0, "still time to pick up the phone")
	assert_lt(director.urgent_answer_hours, _balance.orders.answer_hours, "urgent is still shorter")


# --- 3. «Урожай всегда одинаковый»

func _ripe(state: SimState, plot_id: int, strain_id: String) -> void:
	var plot := state.grow.plot(plot_id)
	plot.reset()
	plot.stage = Plot.Stage.READY
	plot.strain_id = strain_id


func _harvests(state: SimState, strain_id: String, times: int) -> Array[int]:
	var amounts: Array[int] = []
	for index: int in times:
		_ripe(state, 0, strain_id)
		assert_true(state.apply(HarvestCommand.new(0)).ok)
		amounts.append(int(_last_harvest(state).data["quantity"]))
	return amounts


## Selling value can cross a milestone right after a harvest, so the harvest is not always the last event.
func _last_harvest(state: SimState) -> SimEvent:
	return state.event_log.of_type(EventLog.PLOT_HARVESTED).back() as SimEvent


func test_every_strain_has_a_harvest_range_in_content() -> void:
	for strain: StrainDef in _balance.strains():
		assert_gt(strain.yield_max, strain.yield_min, "%s yields a varying amount" % strain.id)


func test_harvest_amount_varies_and_beats_the_old_flat_yield() -> void:
	var state := _calm()
	for strain: StrainDef in _balance.strains():
		var amounts := _harvests(state, strain.id, 60)
		var total := 0
		for amount: int in amounts:
			total += amount
			assert_between(amount, strain.yield_min, strain.yield_max)
		assert_gt(amounts.max(), amounts.min(), "%s harvests differ" % strain.id)
		assert_gt(float(total) / float(amounts.size()), float(strain.yield_min) + 0.5, "%s yields more on average" % strain.id)


func test_harvest_amount_is_seeded() -> void:
	var first := _harvests(_calm(1000, 11), "basic", 10)
	var second := _harvests(_calm(1000, 11), "basic", 10)
	assert_eq(first, second)


func test_harvest_event_records_the_amount_and_the_lucky_extra() -> void:
	var state := _calm()
	_ripe(state, 0, "basic")
	state.apply(HarvestCommand.new(0))
	var event := _last_harvest(state)
	assert_eq(int(event.data["quantity"]), (event.data["product_ids"] as Array).size())
	assert_eq(int(event.data["quantity"]), _balance.find_strain("basic").yield_min + int(event.data["bonus"]))
	assert_eq(String(event.data["strain_id"]), "basic")


func test_a_strain_without_a_range_harvests_flat() -> void:
	var strain := StrainDef.new()
	strain.id = "test"
	strain.yield_min = 2
	strain.yield_max = 2
	var event_log := EventLog.new()
	var grow := Grow.new(strain, 1, SimRng.new(1), event_log, Inventory.new())
	for index: int in 5:
		var plot := grow.plot(0)
		plot.stage = Plot.Stage.READY
		plot.strain_id = ""
		assert_true(grow.harvest(0, 0.0, "jack").ok)
		assert_eq(int(event_log.last().data["quantity"]), 2)
		assert_eq(int(event_log.last().data["bonus"]), 0)


func test_harvest_message_names_amount_strain_and_quality() -> void:
	var state := _calm()
	_ripe(state, 0, "classic")
	var result := state.apply(HarvestCommand.new(0))
	var event := _last_harvest(state)
	var text := PlotView.harvest_text(event, state)
	assert_string_contains(text, "Собрано %d шт." % int(event.data["quantity"]))
	assert_string_contains(text, _strain_name("classic"))
	assert_string_contains(text, "качество %d" % state.inventory.find(result.value).quality)


# --- 4. «Все клиенты хотят одно и то же»

func _spawned_strains(state: SimState, calls: int) -> Dictionary:
	var seen := {}
	for index: int in calls:
		state.orders._spawn(0.0)
	for order: Order in state.orders.all():
		seen[order.strain_id] = int(seen.get(order.strain_id, 0)) + 1
	return seen


func test_clients_ask_for_different_unlocked_strains() -> void:
	var seen := _spawned_strains(_calm(), 60)
	assert_true(seen.has("basic"), str(seen))
	assert_true(seen.has("classic"), str(seen))
	assert_false(seen.has("elite"), "elite is locked at the start: %s" % seen)
	assert_false(seen.has(""), "regular calls always name a strain")


func test_elite_is_asked_for_once_it_is_unlocked() -> void:
	var state := _calm()
	state.progress.reached = 2
	assert_true(_spawned_strains(state, 80).has("elite"))


func test_the_reward_is_priced_by_the_strain_asked_for() -> void:
	var state := _calm()
	_spawned_strains(state, 30)
	for order: Order in state.orders.all():
		var strain := _balance.find_strain(order.strain_id)
		var kind_multiplier := _balance.orders.retail_price_multiplier if order.kind == Order.RETAIL else _balance.orders.wholesale_price_multiplier
		assert_eq(order.reward, roundi(float(order.quantity * Economy.price_with(strain, order.min_quality)) * _balance.orders.reward_multiplier * kind_multiplier))


func test_order_received_event_carries_the_strain() -> void:
	var state := _calm()
	state.orders._spawn(0.0)
	var order := state.orders.all()[0]
	assert_eq(String(state.event_log.last().data["strain_id"]), order.strain_id)


func test_only_the_requested_strain_fills_an_order() -> void:
	var state := _calm()
	var order := state.orders.inject(2, 40, 500, 2.0, 0.0, false, 0.0, "classic")
	assert_true(state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT)).ok)
	for index: int in 3:
		state.inventory.create("basic", 90).packed = true
	assert_false(state.orders.can_fill(order), "basic boxes do not do for a classic order")
	assert_eq(state.orders.matching_products(order).size(), 0)
	var wanted: Array[int] = []
	for index: int in 2:
		var product := state.inventory.create("classic", 60)
		product.packed = true
		wanted.append(product.id)
	assert_true(state.orders.can_fill(order))
	var shipped := state.orders.start_transit(order, Helper.ACTOR, 1.0)
	shipped.sort()
	assert_eq(shipped, wanted, "only the classic boxes went")
	assert_eq(state.inventory.count(), 3, "the basic boxes stay on the shelf")


func test_an_order_without_a_strain_takes_any() -> void:
	var state := _calm()
	var order := state.orders.inject(2, 40, 500, 2.0, 0.0, false, 0.0)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	state.inventory.create("basic", 60).packed = true
	state.inventory.create("classic", 60).packed = true
	assert_true(state.orders.can_fill(order))


func test_urgent_calls_name_a_strain_too() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.first_day = null
	var state := SimState.new(config, 5)
	state.director._trigger(Director.URGENT_ORDER, 0.0)
	var order := state.orders.all()[0]
	assert_true(order.urgent)
	assert_true(["basic", "classic"].has(order.strain_id), order.strain_id)


func test_order_strain_survives_save_and_old_orders_take_any() -> void:
	var state := _calm()
	var order := state.orders.inject(2, 40, 500, 2.0, 0.0, false, 0.0, "classic")
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.orders.find(order.id).strain_id, "classic")
	var old := order.to_dict()
	old.erase("strain_id")
	assert_eq(Order.from_dict(old).strain_id, "")


func _call_event(state: SimState, strain_id: String, urgent: bool = false) -> SimEvent:
	state.orders.inject(3, 55, 420, 2.0, 0.0, urgent, 0.0, strain_id)
	return state.event_log.last()


func test_call_texts_name_the_strain() -> void:
	var state := _calm()
	var name := _strain_name("classic")
	var call := _call_event(state, "classic")
	assert_string_contains(UiText.announcement(call, state), name)
	assert_string_contains(Alert.from_event(call, state).body, name)
	var urgent := _call_event(state, "classic", true)
	assert_string_contains(UiText.announcement(urgent, state), name)


func test_a_call_for_any_strain_reads_as_before() -> void:
	var state := _calm()
	var text := UiText.announcement(_call_event(state, ""), state)
	assert_string_contains(text, "нужно 3 шт., качество 55+")


func test_phone_calls_name_the_strain() -> void:
	var state := _calm()
	state.orders.inject(3, 55, 420, 2.0, 0.0, false, 0.0, "classic")
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var phone := Phone.new()
	autofree(phone)
	PhoneCalls.fill(box, state, phone)
	assert_string_contains(_texts(box), _strain_name("classic"))


func test_computer_order_list_names_the_strain() -> void:
	var state := _calm()
	var order := state.orders.inject(3, 55, 420, 2.0, 0.0, false, 0.0, "classic")
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	var screen := ComputerScreen.new()
	autofree(screen)
	var row := screen._order_row(order, state, 0.0)
	add_child_autofree(row)
	var text := _texts(row)
	assert_string_contains(text, _strain_name("classic"))
	state.inventory.create("basic", 90).packed = true
	assert_string_contains(DispatchText.blocked_reason(order, Helper.ACTOR, state), _strain_name("classic"))


# --- 5. «Сажают что попало»

func _give_seeds(state: SimState, strain_id: String, count: int) -> void:
	state.supplies._stock(Supplies.seed_item(strain_id), count)


func _planted(state: SimState) -> Dictionary:
	var counts := {}
	for plot: Plot in state.grow.plots():
		if plot.stage != Plot.Stage.EMPTY:
			counts[plot.strain_id] = int(counts.get(plot.strain_id, 0)) + 1
	return counts


func test_jack_plants_the_best_seeds_in_stock_first() -> void:
	var state := _calm()
	_give_seeds(state, "classic", 1)
	assert_true(state.apply(PlantCommand.new(0)).ok)
	assert_eq(state.grow.plot(0).strain_id, "classic")
	assert_true(state.apply(PlantCommand.new(1)).ok)
	assert_eq(state.grow.plot(1).strain_id, "basic", "out of classic: the free seeds")


func test_elite_comes_before_classic_once_unlocked() -> void:
	var state := _calm()
	state.progress.reached = 2
	_give_seeds(state, "classic", 1)
	_give_seeds(state, "elite", 1)
	state.apply(PlantCommand.new(0))
	state.apply(PlantCommand.new(1))
	assert_eq(state.grow.plot(0).strain_id, "elite")
	assert_eq(state.grow.plot(1).strain_id, "classic")


func test_locked_seeds_are_not_planted_by_the_rule() -> void:
	var state := _calm()
	_give_seeds(state, "elite", 1)
	state.apply(PlantCommand.new(0))
	assert_eq(state.grow.plot(0).strain_id, "basic")


func test_an_explicit_strain_is_still_obeyed() -> void:
	var state := _calm()
	_give_seeds(state, "classic", 3)
	assert_true(state.apply(PlantCommand.new(0, "basic")).ok)
	assert_eq(state.grow.plot(0).strain_id, "basic")


func test_the_plan_caps_a_strain_and_the_rest_follow_the_rule() -> void:
	var state := _calm()
	_give_seeds(state, "classic", 10)
	assert_true(state.apply(SetPlantingPlanCommand.new("classic", 2)).ok)
	for plot: Plot in state.grow.plots():
		assert_true(state.apply(PlantCommand.new(plot.id)).ok)
	assert_eq(_planted(state), {"classic": 2, "basic": state.grow.plots().size() - 2})
	assert_eq(state.supplies.seeds("classic"), 8)


func test_the_plan_fills_cheaper_beds_before_the_best_seeds_take_the_rest() -> void:
	var state := _calm()
	_give_seeds(state, "classic", 10)
	state.apply(SetPlantingPlanCommand.new("basic", 3))
	for plot: Plot in state.grow.plots():
		state.apply(PlantCommand.new(plot.id))
	assert_eq(_planted(state), {"basic": 3, "classic": state.grow.plots().size() - 3})


func test_a_planned_strain_without_seeds_falls_back_to_the_free_ones() -> void:
	var state := _calm()
	state.apply(SetPlantingPlanCommand.new("classic", 2))
	state.apply(PlantCommand.new(0))
	assert_eq(state.grow.plot(0).strain_id, "basic")


func test_gardeners_replant_by_the_plan() -> void:
	var state := _calm()
	_give_seeds(state, "classic", 10)
	state.apply(SetPlantingPlanCommand.new("classic", 1))
	assert_true(state.apply(HireWorkerCommand.new("tom")).ok)
	_advance(state, 2.0)
	var counts := _planted(state)
	assert_eq(int(counts.get("classic", 0)), 1, str(counts))
	assert_eq(int(counts.get("basic", 0)), state.grow.plots().size() - 1, str(counts))


func test_setting_the_plan_is_validated_and_logged() -> void:
	var state := _calm()
	assert_eq(state.apply(SetPlantingPlanCommand.new("nope", 1)).error, CommandResult.UNKNOWN_STRAIN)
	assert_eq(state.apply(SetPlantingPlanCommand.new("classic", -2)).error, CommandResult.INVALID_QUANTITY)
	assert_eq(state.apply(SetPlantingPlanCommand.new("classic", _balance.max_plots + 1)).error, CommandResult.INVALID_QUANTITY)
	assert_eq(state.apply(SetPlantingPlanCommand.new("elite", 1)).error, CommandResult.STRAIN_LOCKED)
	assert_true(state.apply(SetPlantingPlanCommand.new("classic", 2)).ok)
	assert_eq(state.planting.beds_for("classic"), 2)
	var event := state.event_log.last()
	assert_eq(event.type, EventLog.PLANTING_PLAN_SET)
	assert_eq(String(event.data["strain_id"]), "classic")
	assert_eq(int(event.data["beds"]), 2)
	assert_true(state.apply(SetPlantingPlanCommand.new("classic", PlantingPlan.AUTO)).ok)
	assert_eq(state.planting.beds_for("classic"), PlantingPlan.AUTO)
	assert_true(state.planting.is_empty())


func test_the_plan_survives_save_and_old_saves_have_none() -> void:
	var state := _calm()
	state.apply(SetPlantingPlanCommand.new("classic", 2))
	state.apply(SetPlantingPlanCommand.new("basic", 0))
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.planting.beds_for("classic"), 2)
	assert_eq(loaded.planting.beds_for("basic"), 0)
	var data := JSON.parse_string(state.to_json()) as Dictionary
	data.erase("planting_plan")
	var old := SimState.from_json(JSON.stringify(data), state.config)
	assert_not_null(old)
	assert_true(old.planting.is_empty())


func test_the_shop_has_a_small_planting_plan() -> void:
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var phone := Phone.new()
	autofree(phone)
	PhoneShop.fill(box, Game.sim, phone)
	assert_string_contains(_texts(box), "План посадок")
	var more: Button = null
	for node: Node in box.find_children("*", "Button", true, false):
		if (node as Button).tooltip_text == PhonePlan.more_tooltip(_strain_name("classic")):
			more = node as Button
	assert_not_null(more, "a «+» for the classic beds")
	more.pressed.emit()
	assert_eq(Game.sim.planting.beds_for("classic"), 1)


func test_the_bed_menu_offers_the_rule_first() -> void:
	_give_seeds(Game.sim, "classic", 1)
	var view := PlotView.new()
	autofree(view)
	view.plot_id = 0
	var actions := view.actions(null)
	assert_string_contains(actions[0].label, _strain_name("classic"))
	assert_string_contains(actions[0].label, "лучш")
