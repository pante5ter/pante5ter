extends GutTest

## Playtest round 6, trade and money: most callers buy wholesale and a few want a couple of
## boxes at a price; the purse at the start is smaller so the first days are not a holiday.

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


func _calm(money: int = 1000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	return config


func _state(money: int = 1000, seed_value: int = 3) -> SimState:
	return SimState.new(_calm(money), seed_value)


func _spawn(state: SimState, calls: int) -> Array[Order]:
	for index: int in calls:
		state.orders._spawn(0.0)
	return state.orders.all()


func _per_unit(multiplier: float) -> float:
	return _balance.orders.reward_multiplier * multiplier


func _texts(root: Node) -> String:
	var parts := PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


# --- 1. Опт и розница

func test_the_mix_sizes_and_prices_live_in_content() -> void:
	var orders := _balance.orders
	assert_almost_eq(orders.retail_share, 0.25, 0.05, "about one caller in four buys retail")
	assert_eq(orders.quantity_min, 6)
	assert_eq(orders.quantity_max, 12)
	assert_eq(orders.retail_quantity_min, 1)
	assert_eq(orders.retail_quantity_max, 3)
	assert_lt(orders.wholesale_price_multiplier, 1.0, "wholesale pays less per box")
	assert_gt(orders.retail_price_multiplier, 1.0, "retail pays more per box")


func test_urgent_calls_stay_small_and_dearer_than_retail() -> void:
	var director := _balance.director
	assert_lte(director.urgent_quantity_max, _balance.orders.retail_quantity_max)
	assert_gte(director.urgent_reward_multiplier, _balance.orders.retail_price_multiplier)


func test_most_callers_buy_wholesale_and_some_retail() -> void:
	var orders := _spawn(_state(), 400)
	var retail := 0
	for order: Order in orders:
		if order.kind == Order.RETAIL:
			retail += 1
			assert_between(order.quantity, _balance.orders.retail_quantity_min, _balance.orders.retail_quantity_max)
		else:
			assert_eq(order.kind, Order.WHOLESALE)
			assert_between(order.quantity, _balance.orders.quantity_min, _balance.orders.quantity_max)
	var share := float(retail) / float(orders.size())
	assert_between(share, 0.15, 0.35, "retail share %.2f" % share)


func test_each_kind_is_priced_by_its_own_multiplier() -> void:
	var state := _state()
	for order: Order in _spawn(state, 60):
		var strain := _balance.find_strain(order.strain_id)
		var kind_multiplier := _balance.orders.retail_price_multiplier if order.kind == Order.RETAIL else _balance.orders.wholesale_price_multiplier
		var expected := roundi(float(order.quantity * Economy.price_with(strain, order.min_quality)) * _balance.orders.reward_multiplier * kind_multiplier)
		assert_eq(order.reward, expected)


func test_a_retail_box_pays_more_than_a_wholesale_box() -> void:
	assert_gt(_per_unit(_balance.orders.retail_price_multiplier), _per_unit(_balance.orders.wholesale_price_multiplier) * 1.5)


func test_wholesale_gets_the_longer_deadline() -> void:
	var state := _state()
	var wholesale: Order = null
	var retail: Order = null
	for order: Order in _spawn(state, 40):
		if order.kind == Order.WHOLESALE and wholesale == null:
			wholesale = order
		elif order.kind == Order.RETAIL and retail == null:
			retail = order
	assert_not_null(wholesale)
	assert_not_null(retail)
	state.apply(AnswerOrderCommand.new(wholesale.id, Orders.ACCEPT))
	state.apply(AnswerOrderCommand.new(retail.id, Orders.ACCEPT))
	assert_almost_eq(wholesale.deadline, _balance.orders.wholesale_deadline_hours * HOUR, 0.001)
	assert_almost_eq(retail.deadline, _balance.orders.deadline_hours * HOUR, 0.001)


## A fresh bed planted the moment the call is accepted, the crop hauled, packed and driven over.
func _crops_in_time(strain: StrainDef, quantity: int) -> int:
	var logistics := _balance.day.travel_minutes / 60.0 + _balance.stash.haul_hours + _balance.stash.unload_minutes / 60.0
	logistics += _balance.orders.pack_minutes_per_unit * float(quantity) / 60.0 + _balance.orders.trip_hours
	return floori((_balance.orders.wholesale_deadline_hours - logistics) / strain.growth_hours())


func test_two_to_four_beds_can_fill_a_wholesale_order_in_time() -> void:
	var biggest := _balance.orders.quantity_max
	for strain_id: String in ["basic", "classic"]:
		var strain := _balance.find_strain(strain_id)
		var crops := _crops_in_time(strain, biggest)
		var plain := strain.mean_yield()
		var cared := plain + float(strain.care_yield(true, true))
		assert_gte(2.0 * crops * plain, float(_balance.orders.quantity_min), "%s: two plain beds fill a small wholesale order" % strain_id)
		assert_gte(2.0 * crops * cared, float(biggest), "%s: two cared-for beds fill the biggest" % strain_id)
		assert_gte(4.0 * crops * plain, float(biggest), "%s: four plain beds fill the biggest" % strain_id)


func test_the_kind_is_in_the_event_and_survives_save() -> void:
	var state := _state()
	var order := _spawn(state, 1)[0]
	assert_eq(String(state.event_log.last().data["kind"]), order.kind)
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_eq(loaded.orders.find(order.id).kind, order.kind)


func test_old_orders_have_no_kind() -> void:
	var state := _state()
	var data := _spawn(state, 1)[0].to_dict()
	data.erase("kind")
	assert_eq(Order.from_dict(data).kind, "")


func test_without_a_retail_share_calls_are_as_before() -> void:
	var config := _calm()
	config.orders = _balance.orders.duplicate() as OrdersDef
	config.orders.retail_share = 0.0
	config.orders.wholesale_price_multiplier = 1.0
	config.orders.wholesale_deadline_hours = 0.0
	var state := SimState.new(config, 3)
	for order: Order in _spawn(state, 20):
		assert_eq(order.kind, "")
		assert_false(state.event_log.of_type(EventLog.ORDER_RECEIVED).back().data.has("kind"))
		var strain := _balance.find_strain(order.strain_id)
		assert_eq(order.reward, roundi(float(order.quantity * Economy.price_with(strain, order.min_quality)) * _balance.orders.reward_multiplier))


func test_scripted_and_urgent_calls_have_no_kind() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.first_day = null
	var state := SimState.new(config, 5)
	state.director._trigger(Director.URGENT_ORDER, 0.0)
	var urgent := state.orders.all()[0]
	assert_eq(urgent.kind, "")
	assert_lte(urgent.quantity, _balance.orders.retail_quantity_max)


# --- 2. Тексты: «опт» и «розница»

func _call(state: SimState, kind: String) -> Order:
	var order := state.orders.inject(9, 55, 900, 2.0, 0.0, false, 0.0, "classic", kind)
	return order


func test_call_texts_say_wholesale_or_retail() -> void:
	var state := _state()
	_call(state, Order.WHOLESALE)
	var wholesale := state.event_log.last()
	assert_string_contains(UiText.announcement(wholesale, state), "опт")
	assert_string_contains(Alert.from_event(wholesale, state).title, "опт")
	_call(state, Order.RETAIL)
	var retail := state.event_log.last()
	assert_string_contains(UiText.announcement(retail, state), "розница")
	assert_string_contains(Alert.from_event(retail, state).title, "розница")


func test_a_call_without_a_kind_reads_as_before() -> void:
	var state := _state()
	state.orders.inject(3, 55, 420, 2.0, 0.0, false, 0.0)
	var text := UiText.announcement(state.event_log.last(), state)
	assert_false(text.contains("опт"))
	assert_false(text.contains("розница"))
	assert_string_contains(text, "Звонит клиент: нужно 3 шт.")


func test_phone_calls_say_wholesale_or_retail() -> void:
	var state := _state()
	_call(state, Order.WHOLESALE)
	_call(state, Order.RETAIL)
	var box := VBoxContainer.new()
	add_child_autofree(box)
	var phone := Phone.new()
	autofree(phone)
	PhoneCalls.fill(box, state, phone)
	var text := _texts(box)
	assert_string_contains(text, "опт")
	assert_string_contains(text, "розница")


func test_computer_order_list_says_wholesale_or_retail() -> void:
	var state := _state()
	var order := _call(state, Order.WHOLESALE)
	state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))
	var screen := ComputerScreen.new()
	autofree(screen)
	var row := screen._order_row(order, state, 0.0)
	add_child_autofree(row)
	assert_string_contains(_texts(row), "опт")


# --- 3. Деньги на старте

func test_the_purse_is_about_eight_hundred() -> void:
	assert_between(_balance.starting_money, 700, 900)


func test_the_start_still_hires_a_gardener_reggie_and_the_basket() -> void:
	var state := _state(_balance.starting_money)
	assert_true(state.apply(HireWorkerCommand.new("tom")).ok)
	assert_true(state.apply(RestockCommand.new()).ok)
	assert_gte(state.economy.money, _balance.helper.daily_wage, "Reggie's wage for the first night is there")


func test_the_start_is_below_the_first_level_by_a_bed_or_so() -> void:
	var state := _state(_balance.starting_money)
	var first := _balance.milestones[0].value
	assert_lt(state.empire_value(), first)
	assert_lte(first - state.empire_value(), 2 * _balance.plot_price, "the first level is not far off")


## A sensible player: one gardener, half the beds on the house strain and half on «Классика»,
## and an order taken only when the boxes on hand and the beds in the ground can cover it.
func _sensible_hour(state: SimState) -> void:
	state.apply(PickUpParcelCommand.new())
	state.apply(HaulCommand.new(Helper.ACTOR))
	state.apply(PackCommand.new())
	for order: Order in state.orders.with_status(Order.Status.ACCEPTED):
		if state.orders.can_fill(order):
			state.apply(DispatchCommand.new(order.id, Helper.ACTOR))
	for order: Order in state.orders.with_status(Order.Status.OFFERED):
		if _can_cover(state, order):
			state.apply(AnswerOrderCommand.new(order.id, Orders.ACCEPT))


func _can_cover(state: SimState, offered: Order) -> bool:
	var promised := offered.quantity
	for order: Order in state.orders.with_status(Order.Status.ACCEPTED):
		if order.strain_id == offered.strain_id:
			promised += order.quantity
	var supply := 0
	for product: Product in state.inventory.products():
		if offered.accepts(product):
			supply += 1
	for product: Product in state.stash.transit:
		if offered.accepts(product):
			supply += 1
	for plot: Plot in state.grow.plots():
		if plot.stage != Plot.Stage.EMPTY and plot.strain_id == offered.strain_id:
			supply += 2
	return supply >= promised


func test_one_gardener_pays_the_first_rent_from_eight_hundred() -> void:
	var state := _state(_balance.starting_money, 11)
	assert_true(state.apply(HireWorkerCommand.new("tom")).ok)
	assert_true(state.apply(RestockCommand.new()).ok)
	var basic_beds := floori(state.grow.plots().size() / 2.0)
	state.apply(SetPlantingPlanCommand.new("basic", basic_beds))
	state.apply(SetPlantingPlanCommand.new("classic", state.grow.plots().size() - basic_beds))
	state.apply(SetAutoReorderCommand.new(Supplies.seed_item("classic"), 4))
	var curve: Array[int] = []
	var lowest := state.economy.money
	for hour: int in 76:
		state.apply(AdvanceTimeCommand.new(HOUR * state.config.real_seconds_per_game_day / DAY))
		_sensible_hour(state)
		lowest = mini(lowest, state.economy.money)
		if (hour + 1) % 24 == 0:
			curve.append(state.economy.money)
	var rents := state.event_log.of_type(EventLog.RENT_PAID)
	gut.p("money at 24h/48h/72h: %s, lowest %d, rent paid %d (first at %.1fh), delivered %d" % [str(curve), lowest,
		rents.size(), rents[0].game_time / HOUR if not rents.is_empty() else -1.0, state.event_log.of_type(EventLog.ORDER_PAID).size()])
	assert_true(state.workers.hired, "the gardener stayed")
	assert_eq(state.event_log.of_type(EventLog.RENT_MISSED).size(), 0, "the first rent was paid")
	assert_gte(state.event_log.of_type(EventLog.RENT_PAID).size(), 1)
	assert_gte(lowest, 0)
