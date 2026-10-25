class_name RoadText
extends RefCounted

## Who is out on the road right now and when they turn up: Jack, Reggie, the couriers.


class Trip:
	extends RefCounted
	## DayCycle.JACK, Helper.ACTOR or a courier id.
	var who: String = ""
	var name: String = ""
	var doing: String = ""
	var seconds_left: float = 0.0
	## Jack counts down to where he is going; everyone else to coming back.
	var arriving: bool = false

	func countdown(sim: SimState) -> String:
		return UiText.real_duration(seconds_left, sim)

	func line() -> String:
		return "%s: %s" % [name, doing]

	func tooltip(sim: SimState) -> String:
		return "%s %s — %s через %s" % [name, doing, "приедет" if arriving else "вернётся", countdown(sim)]


static func trips(sim: SimState) -> Array[Trip]:
	var found: Array[Trip] = []
	var now := sim.clock.elapsed_game_seconds
	var jack := _jack(sim, now)
	if jack != null:
		found.append(jack)
	var reggie := _reggie(sim, now)
	if reggie != null:
		found.append(reggie)
	for courier_id: String in sim.couriers.busy_until:
		if courier_id == Helper.ACTOR or courier_id == Couriers.JACK:
			continue
		var back_at: float = sim.couriers.busy_until[courier_id]
		var order := _order_carried_by(sim, courier_id)
		if back_at <= now or (order == null and not sim.couriers.hired.has(courier_id)):
			continue
		var doing := ("везёт заказ #%d" % order.id) if order != null else "едет обратно с доставки"
		found.append(_make(courier_id, UiText.courier_name(courier_id, sim), doing, back_at - now, false))
	return found


static func _jack(sim: SimState, now: float) -> Trip:
	var day := sim.day
	if day.travelling():
		var hauling := sim.stash.on_the_road() and sim.stash.driver == DayCycle.JACK and day.trip_to == DayCycle.STASH
		var doing := "везёт ящики в тайник" if hauling else "едет %s" % Travel.TITLES.get(day.trip_to, "")
		return _make(DayCycle.JACK, UiText.JACK, doing, day.trip_arrives_at - now, true)
	var back_at: float = sim.couriers.busy_until.get(Couriers.JACK, -INF)
	if back_at > now:
		var order := _order_carried_by(sim, Couriers.JACK)
		var doing := ("везёт заказ #%d" % order.id) if order != null else "едет обратно с доставки"
		return _make(DayCycle.JACK, UiText.JACK, doing, back_at - now, false)
	return null


static func _reggie(sim: SimState, now: float) -> Trip:
	var helper := sim.helper
	if not helper.exists() or helper.present():
		return null
	var doing := "в отъезде"
	match helper.away_reason:
		Helper.AWAY_DELIVERY:
			var order := _order_carried_by(sim, Helper.ACTOR)
			doing = ("везёт заказ #%d" % order.id) if order != null else "едет обратно с доставки"
		Helper.AWAY_HAUL:
			if sim.stash.on_the_road() and sim.stash.driver == Helper.ACTOR:
				doing = "везёт ящики в тайник"
			elif sim.packing.busy():
				doing = "фасует в тайнике"
			else:
				doing = "едет обратно из тайника"
		Helper.AWAY_TRAINING:
			var skill := sim.config.find_skill(helper.training_skill_id)
			doing = "на курсах «%s»" % (skill.display_name if skill != null else "?")
	return _make(Helper.ACTOR, helper.definition().display_name, doing, helper.away_until - now, false)


static func _order_carried_by(sim: SimState, courier_id: String) -> Order:
	for order: Order in sim.orders.with_status(Order.Status.IN_TRANSIT):
		if order.courier_id == courier_id:
			return order
	return null


static func _make(who: String, name: String, doing: String, seconds_left: float, arriving: bool) -> Trip:
	var trip := Trip.new()
	trip.who = who
	trip.name = name
	trip.doing = doing
	trip.seconds_left = maxf(seconds_left, 0.0)
	trip.arriving = arriving
	return trip
