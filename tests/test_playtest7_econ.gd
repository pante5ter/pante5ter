extends GutTest

## Playtest round 7, economy: one shop delivery a day, clients that grow with the farm, expensive
## kit with running costs, and Vivienne's gossip that turns into sales, leads and big orders.

const BALANCE_PATH: String = "res://content/balance.tres"
const HOUR: float = SimClock.GAME_SECONDS_PER_HOUR
const DAY: float = SimClock.GAME_SECONDS_PER_DAY

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _calm(money: int = 1000) -> BalanceConfig:
	var config := _balance.duplicate() as BalanceConfig
	config.starting_money = money
	config.first_day = null
	config.director = null
	config.day = null
	config.problems = _balance.problems.duplicate() as ProblemsDef
	config.problems.chance_per_hour = 0.0
	config.raids = _balance.raids.duplicate() as RaidsDef
	config.raids.chance_per_night = 0.0
	config.rent = _balance.rent.duplicate() as RentDef
	config.rent.amount = 0
	return config


func _state(money: int = 1000, seed_value: int = 3) -> SimState:
	return SimState.new(_calm(money), seed_value)


func _advance_to(state: SimState, game_time: float) -> void:
	var left := game_time - state.clock.elapsed_game_seconds
	if left > 0.0:
		state.apply(AdvanceTimeCommand.new(left / DAY * state.config.real_seconds_per_game_day))


func _advance(state: SimState, hours: float) -> void:
	_advance_to(state, state.clock.elapsed_game_seconds + hours * HOUR)


func _first_day_of(state: SimState, kind: String) -> int:
	for day: int in range(state.config.opportunities.start_day, 60):
		if state.opportunities.kind_on(day) == kind:
			return day
	return -1


func _opened(state: SimState, kind: String) -> Array[SimEvent]:
	return state.event_log.of_type(EventLog.OPPORTUNITY_OPENED).filter(
		func(event: SimEvent) -> bool: return String(event.data["kind"]) == kind)


func _install(state: SimState, upgrade_id: String) -> void:
	assert_true(state.apply(BuyUpgradeCommand.new(upgrade_id)).ok, "bought %s" % upgrade_id)
	_advance_to(state, state.upgrades.on_order[upgrade_id] + 1.0)
	assert_true(state.upgrades.has(upgrade_id), "installed %s" % upgrade_id)


# --- Daily delivery ---

func test_an_order_before_the_cutoff_comes_with_this_mornings_delivery() -> void:
	var state := _state()
	_advance_to(state, 7.0 * HOUR)
	assert_true(state.apply(BuyCommand.new(Supplies.FERTILIZER, 2)).ok)
	assert_eq(state.supplies.pending_deliveries()[0]["arrives_at"], 9.0 * HOUR)
	_advance_to(state, 9.0 * HOUR - 60.0)
	assert_true(state.supplies.parcel().is_empty(), "nothing before the delivery hour")
	_advance_to(state, 9.0 * HOUR + 1.0)
	assert_eq(state.supplies.parcel().size(), 1)


func test_an_order_after_the_cutoff_waits_for_tomorrows_delivery() -> void:
	var state := _state()
	_advance_to(state, 8.5 * HOUR)
	assert_eq(state.supplies.arrival_for(state.clock.elapsed_game_seconds), DAY + 9.0 * HOUR)
	assert_eq(state.supplies.arrival_for(8.0 * HOUR), 9.0 * HOUR, "the cutoff minute itself still makes it")
	assert_eq(state.supplies.arrival_for(15.0 * HOUR), DAY + 9.0 * HOUR)
	assert_eq(state.supplies.cutoff_for(15.0 * HOUR), DAY + 8.0 * HOUR)


func test_everything_ordered_in_a_day_arrives_together() -> void:
	var state := _state()
	_advance_to(state, 10.0 * HOUR)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	_advance(state, 5.0)
	state.apply(BuyCommand.new(Supplies.PESTICIDE, 1))
	state.apply(RestockCommand.new())
	var times := {}
	for delivery: Dictionary in state.supplies.pending_deliveries():
		times[float(delivery["arrives_at"])] = true
	assert_eq(times.keys(), [DAY + 9.0 * HOUR])


func test_a_delivery_from_an_old_save_still_arrives_on_its_own_time() -> void:
	var state := _state()
	var saved := state.to_dict()
	var supplies := saved["supplies"] as Dictionary
	supplies["deliveries"] = [{"item": Supplies.LAMP, "quantity": 1, "arrives_at": ExactFloat.encode(1.5 * HOUR)}]
	saved.erase("upgrades")
	saved.erase("opportunities")
	var loaded := SimState.from_json(JSON.stringify(saved), _calm())
	assert_not_null(loaded)
	_advance_to(loaded, 1.5 * HOUR + 1.0)
	assert_eq(loaded.supplies.parcel().size(), 1)
	assert_eq(loaded.opportunities.next_open_at, 7.0 * HOUR, "an old save gets its first chance the next morning")


func test_without_a_shop_config_parcels_come_after_the_old_delay() -> void:
	var config := _calm()
	config.shop = null
	var state := SimState.new(config, 1)
	state.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	assert_eq(state.supplies.pending_deliveries()[0]["arrives_at"], config.delivery_hours * HOUR)
	assert_true(state.upgrades.catalogue().is_empty())


func test_the_village_store_sells_on_the_spot_at_a_markup_only_in_the_village() -> void:
	var config := _balance.duplicate() as BalanceConfig
	config.first_day = null
	config.director = null
	var state := SimState.new(config, 2)
	assert_eq(state.apply(BuyCommand.new(Supplies.FERTILIZER, 1, true)).error, CommandResult.NOT_IN_VILLAGE)
	state.day.place = DayCycle.STASH
	assert_true(state.in_village())
	var money := state.economy.money
	var bought := state.apply(BuyCommand.new(Supplies.FERTILIZER, 2, true))
	assert_true(bought.ok)
	var price := ceili(float(config.fertilizer_price) * (1.0 + config.shop.village_markup))
	assert_gt(price, config.fertilizer_price)
	assert_eq(bought.value, price * 2)
	assert_eq(state.economy.money, money - price * 2)
	assert_eq(state.supplies.fertilizer, 2, "in Jack's hands at once")
	assert_eq(state.apply(BuyCommand.new(Supplies.seed_item("classic"), 1, true)).error, CommandResult.NOT_SOLD_IN_VILLAGE)


# --- Quality ---

func test_care_never_lifts_quality_more_than_the_cap_over_the_base() -> void:
	var config := _calm()
	config.fertilizer_bonus = 30
	config.prune_bonus = 30
	var strain := _balance.strain.duplicate() as StrainDef
	strain.quality_variance = 0
	config.strain = strain
	var state := SimState.new(config, 4)
	var target := state.grow.plot(0)
	state.apply(PlantCommand.new(0, "basic"))
	target.fertilized = true
	target.pruned = true
	assert_eq(state.grow.care_quality(target), 20)
	target.stage = Plot.Stage.READY
	target.water_seconds = HOUR
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_eq(state.inventory.products()[0].quality, strain.base_quality + 20)


func test_elite_has_the_highest_base_and_full_care_reaches_its_best() -> void:
	var elite := _balance.find_strain("elite")
	assert_eq(elite.base_quality, 80)
	for strain: StrainDef in _balance.strains():
		assert_true(strain == elite or strain.base_quality < elite.base_quality)
	assert_eq(_balance.best_quality(elite), 100)
	assert_eq(_balance.best_quality(_balance.strain), 70)
	assert_eq(_balance.fertilizer_bonus + _balance.prune_bonus, _balance.max_care_quality_bonus, "full care is exactly the cap")


func test_no_request_asks_for_more_than_full_care_can_grow() -> void:
	var state := _state()
	state.demand = null
	state.orders.demand = _FullDemand.new(_balance.orders, state.inventory, state.event_log)
	for call: int in 200:
		state.orders._spawn(0.0)
		var order := state.orders.all().back() as Order
		assert_lte(order.min_quality, state.orders.achievable_quality(order.strain_id), "order %d" % order.id)
		assert_true(order.strain_id.is_empty() or state.progress.is_strain_unlocked(order.strain_id))
		state.orders.remove(order)


class _FullDemand:
	extends Demand

	func level(_now: float) -> float:
		return 1.0


# --- Demand ---

func test_a_newcomers_calls_come_out_exactly_as_before() -> void:
	var with_demand := _state(1000, 9)
	var without := _state(1000, 9)
	without.orders.demand = null
	assert_eq(with_demand.orders.demand_level(0.0), 0.0)
	for call: int in 30:
		with_demand.orders._spawn(0.0)
		without.orders._spawn(0.0)
	assert_eq(JSON.stringify(with_demand.orders.to_dict()), JSON.stringify(without.orders.to_dict()))


func test_recent_takings_and_stock_grow_demand_smoothly_up_to_the_cap() -> void:
	var state := _state()
	var def := _balance.orders
	state.event_log.record(EventLog.ORDER_PAID, 0.0, PackedStringArray(), {"reward": def.demand_full_takings / 2})
	var half_takings := state.orders.demand_level(HOUR)
	assert_almost_eq(half_takings, def.demand_takings_weight * 0.5, 0.001)
	for unit: int in def.demand_full_stock:
		state.inventory.create("basic", 50)
	assert_almost_eq(state.orders.demand_level(HOUR), def.demand_takings_weight * 0.5 + (1.0 - def.demand_takings_weight), 0.001)
	state.event_log.record(EventLog.ORDER_PAID, HOUR, PackedStringArray(), {"reward": def.demand_full_takings * 5})
	assert_eq(state.orders.demand_level(HOUR), 1.0, "capped")
	assert_almost_eq(state.orders.demand_level(HOUR + def.demand_window_hours * HOUR + 1.0), 1.0 - def.demand_takings_weight, 0.001, "old takings drop out of the window")


func test_clients_never_ask_much_above_what_the_farm_grows() -> void:
	var state := _state()
	state.orders.demand = _FullDemand.new(_balance.orders, state.inventory, state.event_log)
	for unit: int in 20:
		state.inventory.create("basic", 50)
	for call: int in 100:
		state.orders._spawn(0.0)
		var order := state.orders.all().back() as Order
		assert_lte(order.min_quality, _balance.orders.quality_max, "a farm at quality 50 gets no pickier callers")
		assert_lte(order.min_quality, maxi(_balance.orders.quality_min, 50) + _balance.orders.quality_max - _balance.orders.quality_min)
		state.orders.remove(order)
	var lowest := 100
	for call: int in 100:
		state.orders._spawn(0.0)
		var order := state.orders.all().back() as Order
		lowest = mini(lowest, order.min_quality)
		state.orders.remove(order)
	assert_lte(lowest, 50, "the bottom of the range stays within reach")


func test_a_big_supplier_gets_bigger_pickier_richer_calls() -> void:
	var small := _state(1000, 5)
	var big := _state(1000, 5)
	big.orders.demand = _FullDemand.new(_balance.orders, big.inventory, big.event_log)
	for unit: int in 10:
		big.inventory.create("classic", 85)
	var small_units := 0
	var big_units := 0
	var small_pay := 0
	var big_pay := 0
	var small_quality := 0
	var big_quality := 0
	for call: int in 80:
		small.orders._spawn(0.0)
		big.orders._spawn(0.0)
		var a := small.orders.all().back() as Order
		var b := big.orders.all().back() as Order
		small_units += a.quantity
		big_units += b.quantity
		small_pay += a.reward
		big_pay += b.reward
		small_quality += a.min_quality
		big_quality += b.min_quality
		if b.kind == Order.WHOLESALE:
			assert_lte(b.quantity, _balance.orders.quantity_max + _balance.orders.demand_extra_quantity_max)
			assert_gte(b.quantity, _balance.orders.quantity_min + _balance.orders.demand_extra_quantity_min)
		small.orders.remove(a)
		big.orders.remove(b)
	assert_gt(big_units, small_units * 1.3)
	assert_gt(big_quality, small_quality)
	assert_gt(big_pay, small_pay * 1.5)


# --- Upgrades ---

func test_kit_is_gated_by_level_and_comes_with_the_delivery() -> void:
	var state := _state(1000)
	assert_eq(state.progress.reached, 0)
	assert_eq(state.apply(BuyUpgradeCommand.new("auto_water")).error, CommandResult.UPGRADE_LOCKED)
	assert_eq(state.apply(BuyUpgradeCommand.new("nonsense")).error, CommandResult.UNKNOWN_ITEM)
	_advance_to(state, 10.0 * HOUR)
	var bought := state.apply(BuyUpgradeCommand.new("dehumidifier"))
	assert_true(bought.ok)
	assert_eq(bought.value, 650)
	assert_eq(state.apply(BuyUpgradeCommand.new("dehumidifier")).error, CommandResult.ALREADY_DONE)
	assert_false(state.upgrades.has("dehumidifier"))
	assert_eq(state.upgrades.on_order["dehumidifier"], DAY + 9.0 * HOUR)
	_advance_to(state, DAY + 9.0 * HOUR - 1.0)
	var suspicion := state.suspicion.level
	_advance_to(state, DAY + 9.0 * HOUR + 1.0)
	assert_true(state.upgrades.has("dehumidifier"))
	assert_eq(state.event_log.of_type(EventLog.UPGRADE_INSTALLED).size(), 1)
	assert_gt(state.suspicion.level, suspicion + 0.5, "the van at the door is noticed")


func test_every_installed_piece_is_billed_daily_and_an_unpaid_bill_switches_it_off() -> void:
	var state := _state(20000)
	_install(state, "dehumidifier")
	var room := state.climate.bed_room()
	var dry := state.climate.humidity(room)
	_advance(state, 24.0)
	var bills := state.event_log.of_type(EventLog.UPGRADES_BILLED)
	assert_eq(bills.size(), 1)
	assert_eq(int(bills[0].data["amount"]), 30)
	state.economy.money = 0
	_advance(state, 24.0)
	assert_eq(state.event_log.of_type(EventLog.UPGRADES_CUT).size(), 1)
	assert_false(state.upgrades.powered)
	assert_eq(state.climate.humidity(room), minf(dry + 10.0, 100.0), "switched off, the air is damp again")
	state.economy.money = 1000
	_advance(state, 24.0)
	assert_true(state.upgrades.powered, "paying the next bill switches it back on")


func test_the_dehumidifier_dries_the_beds_room() -> void:
	var state := _state(20000)
	for plot_id: int in 6:
		state.apply(PlantCommand.new(plot_id, "basic"))
	var room := state.climate.bed_room()
	var damp := state.climate.humidity(room)
	_install(state, "dehumidifier")
	assert_almost_eq(state.climate.humidity(room), damp - 10.0, 0.01)


func test_lamps_grow_a_quarter_faster_and_draw_daily_suspicion() -> void:
	var state := _state(20000)
	state.apply(PlantCommand.new(0, "basic"))
	var plain := state.grow.stage_duration(state.grow.plot(0))
	_install(state, "grow_lamps")
	assert_almost_eq(state.grow.stage_duration(state.grow.plot(0)), plain / 1.25, 0.01)
	_advance_to(state, state.upgrades.next_bill_at - 1.0)
	state.suspicion.level = 50.0
	_advance_to(state, state.upgrades.next_bill_at + 1.0)
	assert_gt(state.suspicion.level, 50.0 + 4.0, "the meter is noticed with every bill")


func test_coco_adds_yield_and_quality_within_the_cap_and_hydro_replaces_it() -> void:
	var state := _state(1000)
	assert_eq(state.apply(BuyUpgradeCommand.new("hydro")).error, CommandResult.UPGRADE_LOCKED)
	state.economy.money = 30000
	state.apply(AdvanceTimeCommand.new(0.0))
	assert_eq(state.progress.reached, 3, "a rich farm reaches the levels")
	assert_eq(state.apply(BuyUpgradeCommand.new("hydro")).error, CommandResult.NEEDS_UPGRADE)
	_install(state, "coco")
	assert_eq(state.upgrades.yield_bonus(), 1)
	assert_eq(state.upgrades.quality_bonus(), 4)
	var target := state.grow.plot(0)
	state.apply(PlantCommand.new(0, "basic"))
	assert_eq(state.grow.care_quality(target), 4, "kit alone lifts an uncared bed")
	target.fertilized = true
	target.pruned = true
	assert_eq(state.grow.care_quality(target), 20, "with full care the cap holds")
	_install(state, "hydro")
	assert_false(state.upgrades.has("coco"), "hydroponics take the coco out")
	assert_eq(state.upgrades.yield_bonus(), 2)
	assert_eq(state.apply(BuyUpgradeCommand.new("coco")).error, CommandResult.ALREADY_DONE, "no going back a tier")


func test_coco_lifts_the_harvest_by_one_unit() -> void:
	var config := _calm(20000)
	var strain := _balance.strain.duplicate() as StrainDef
	strain.yield_min = 2
	strain.yield_max = 2
	config.strain = strain
	var state := SimState.new(config, 6)
	_install(state, "coco")
	state.apply(PlantCommand.new(0, "basic"))
	state.grow.plot(0).stage = Plot.Stage.READY
	assert_true(state.apply(HarvestCommand.new(0)).ok)
	assert_eq(state.inventory.count(), 3)


func test_auto_watering_keeps_its_six_beds_wet_and_leaves_the_rest() -> void:
	var state := _state(20000)
	_install(state, "auto_water")
	assert_true(state.apply(BuyPlotCommand.new()).ok)
	for plot_id: int in 7:
		state.apply(PlantCommand.new(plot_id, "basic"))
		state.apply(WaterCommand.new(plot_id))
	_advance(state, 8.0)
	for plot_id: int in 6:
		assert_eq(state.grow.plot(plot_id).dry_seconds, 0.0, "bed %d watered by the drip" % plot_id)
	assert_gt(state.grow.plot(6).dry_seconds, 0.0, "the seventh bed is not on the line")
	assert_gt(state.event_log.of_type(EventLog.AUTO_WATERED).size(), 0)


func test_the_camera_gives_more_time_to_answer_a_raid_once() -> void:
	var state := _state(20000)
	_install(state, "camera")
	state.raids.pending = true
	state.raids.deadline = state.clock.elapsed_game_seconds + 3.0 * HOUR
	var deadline := state.raids.deadline
	state.upgrades.process(state.clock.elapsed_game_seconds)
	assert_eq(state.raids.deadline, deadline + 3.0 * HOUR)
	state.upgrades.process(state.clock.elapsed_game_seconds)
	assert_eq(state.raids.deadline, deadline + 3.0 * HOUR, "one warning per raid")
	assert_eq(state.event_log.of_type(EventLog.RAID_SPOTTED).size(), 1)


func test_installed_kit_counts_toward_the_empire() -> void:
	var state := _state(20000)
	var value := state.empire_value()
	_install(state, "camera")
	assert_eq(state.empire_value(), value, "money became kit, the empire is as big")


func test_upgrades_and_chances_survive_save_and_load() -> void:
	var state := _state(20000)
	_install(state, "coco")
	state.apply(BuyUpgradeCommand.new("camera"))
	_advance_to(state, _first_day_of(state, Opportunities.LEAD) * DAY + 8.0 * HOUR)
	assert_false(state.opportunities.leads.is_empty())
	var loaded := SimState.from_json(state.to_json(), state.config)
	assert_not_null(loaded)
	assert_eq(loaded.to_json(), state.to_json())
	_advance(state, 50.0)
	_advance(loaded, 50.0)
	assert_eq(loaded.to_json(), state.to_json())


# --- Opportunities ---

func test_the_gossip_map_follows_vivienne_line_for_line() -> void:
	var def := _balance.opportunities
	assert_eq(def.gossip_kinds.size(), Vivienne.GOSSIP.size())
	assert_eq(def.gossip_notes.size(), Vivienne.GOSSIP.size())
	assert_eq(def.gossip_stride, Vivienne.DAY_STRIDE)
	for index: int in def.gossip_kinds.size():
		var kind := def.gossip_kinds[index]
		assert_true(kind.is_empty() or Opportunities.KINDS.has(kind), "line %d: %s" % [index, kind])
		assert_eq(kind.is_empty(), def.gossip_notes[index].is_empty(), "line %d has a note exactly when it means business" % index)
	for kind: String in Opportunities.KINDS:
		assert_true(def.gossip_kinds.has(kind), "some gossip means %s" % kind)
	var state := _state()
	Vivienne.forget()
	for day: int in 12:
		assert_eq(Vivienne.say(Vivienne.GOSSIP, day), Vivienne.GOSSIP[state.opportunities.gossip_index(day)], "day %d" % day)
	Vivienne.forget()


func test_a_household_selling_up_puts_used_kit_on_sale_for_the_day() -> void:
	var state := _state(1000)
	var day := _first_day_of(state, Opportunities.SALE)
	_advance_to(state, day * DAY + state.config.opportunities.open_hour * HOUR + 1.0)
	var opened := _opened(state, Opportunities.SALE)
	assert_eq(opened.size(), 1)
	var upgrade_id := state.upgrades.sale_id
	assert_true(["dehumidifier", "camera"].has(upgrade_id), "only kit the farm may buy goes on sale")
	var full := state.upgrades.find(upgrade_id).price
	assert_eq(state.upgrades.price_of(upgrade_id), roundi(full * 0.6))
	_advance_to(state, state.upgrades.sale_until + 1.0)
	assert_eq(state.upgrades.sale_id, "", "the sale ends the same evening")
	assert_eq(state.upgrades.price_of(upgrade_id), full)
	assert_eq(state.event_log.of_type(EventLog.OPPORTUNITY_EXPIRED).size(), 1)


func test_buying_on_sale_pays_the_used_price_once() -> void:
	var state := _state(1000)
	var day := _first_day_of(state, Opportunities.SALE)
	_advance_to(state, day * DAY + state.config.opportunities.open_hour * HOUR + 1.0)
	var upgrade_id := state.upgrades.sale_id
	var money := state.economy.money
	var paid := state.apply(BuyUpgradeCommand.new(upgrade_id))
	assert_true(paid.ok)
	assert_eq(state.economy.money, money - roundi(state.upgrades.find(upgrade_id).price * 0.6))
	assert_eq(state.upgrades.sale_id, "")


func test_a_party_at_the_manor_rings_in_one_big_retail_order() -> void:
	var state := _state()
	var def := state.config.opportunities
	var day := _first_day_of(state, Opportunities.PARTY)
	_advance_to(state, day * DAY + def.open_hour * HOUR + 1.0)
	var opened := _opened(state, Opportunities.PARTY)
	assert_eq(opened.size(), 1)
	var order := state.orders.find(int(opened[0].data["order_id"]))
	assert_not_null(order)
	assert_eq(order.kind, Order.RETAIL)
	assert_between(order.quantity, def.party_quantity_min, def.party_quantity_max)
	assert_gt(order.quantity, _balance.orders.retail_quantity_max, "bigger than any usual retail call")
	assert_lte(order.min_quality, state.orders.achievable_quality(""))
	assert_eq(order.reward, roundi(order.quantity * Economy.price_with(state.config.strain, order.min_quality) * def.party_price_multiplier))


func test_a_lord_in_debt_is_a_logged_lead_that_goes_cold() -> void:
	var state := _state()
	var def := state.config.opportunities
	var day := _first_day_of(state, Opportunities.LEAD)
	_advance_to(state, day * DAY + def.open_hour * HOUR + 1.0)
	assert_eq(state.opportunities.leads.size(), 1)
	assert_eq(_opened(state, Opportunities.LEAD).size(), 1)
	_advance_to(state, day * DAY + def.open_hour * HOUR + def.lead_days * DAY + 1.0)
	assert_true(state.opportunities.leads.is_empty())


func test_idle_gossip_days_and_the_first_days_bring_nothing() -> void:
	var state := _state()
	_advance_to(state, state.config.opportunities.start_day * DAY)
	assert_eq(state.event_log.of_type(EventLog.OPPORTUNITY_OPENED).size(), 0, "nothing before the start day")
	_advance_to(state, 20.0 * DAY)
	var expected := 0
	for day: int in range(state.config.opportunities.start_day, 20):
		if state.opportunities.kind_on(day) == Opportunities.PARTY or state.opportunities.kind_on(day) == Opportunities.LEAD:
			expected += 1
	var parties_and_leads := _opened(state, Opportunities.PARTY).size() + _opened(state, Opportunities.LEAD).size()
	assert_eq(parties_and_leads, expected)


func test_the_same_seed_brings_the_same_chances() -> void:
	var a := _state(5000, 12)
	var b := _state(5000, 12)
	_advance_to(a, 15.0 * DAY)
	_advance_to(b, 15.0 * DAY)
	assert_eq(JSON.stringify(a.event_log.of_type(EventLog.OPPORTUNITY_OPENED).map(func(e: SimEvent) -> Dictionary: return e.to_dict())),
		JSON.stringify(b.event_log.of_type(EventLog.OPPORTUNITY_OPENED).map(func(e: SimEvent) -> Dictionary: return e.to_dict())))
