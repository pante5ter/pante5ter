class_name Director
extends RefCounted

## When the farm has been quiet for too long, something happens.
const ACTOR: String = "director"
const URGENT_ORDER: String = "urgent_order"
const LORD_VISIT: String = "lord_visit"
const RUMOUR: String = "rumour"
const BREAKDOWN: String = "breakdown"
const COURIER_TROUBLE: String = "courier_trouble"
const STORY: String = "story"
const KINDS: Array[String] = [URGENT_ORDER, LORD_VISIT, RUMOUR, BREAKDOWN, COURIER_TROUBLE, STORY]
const ABOUT_INSPECTION: String = "inspection"
const ABOUT_RAID: String = "raid"
const ALWAYS_NOTABLE: Array[String] = [
	EventLog.STORY_STARTED, EventLog.STORY_RESOLVED, EventLog.STORY_EXPIRED, EventLog.DIRECTOR_EVENT, EventLog.FIRST_DAY_STEP,
	EventLog.INTRIGUE_STARTED, EventLog.INTRIGUE_STEP, EventLog.INTRIGUE_CLUE, EventLog.INTRIGUE_RESOLVED,
]

var last_notable_at: float = 0.0
var seen_events: int = 0
## An urgent caller who picked the night rings at this morning hour instead; the quiet spell may bring something else.
var urgent_call_at: float = INF

var _def: DirectorDef
var _config: BalanceConfig
var _rng: SimRng
var _orders: Orders
var _problems: Problems
var _suspicion: Suspicion
var _raids: Raids
var _couriers: Couriers
var _stories: Stories
var _first_day: FirstDay
var _event_log: EventLog


func _init(config: BalanceConfig, rng: SimRng, orders: Orders, problems: Problems, suspicion: Suspicion, raids: Raids, couriers: Couriers, stories: Stories, first_day: FirstDay, event_log: EventLog) -> void:
	_config = config
	_def = config.director
	_rng = rng
	_orders = orders
	_problems = problems
	_suspicion = suspicion
	_raids = raids
	_couriers = couriers
	_stories = stories
	_first_day = first_day
	_event_log = event_log


func quiet_seconds() -> float:
	return _def.quiet_real_seconds * SimClock.GAME_SECONDS_PER_DAY / _config.real_seconds_per_game_day


func next_event_time() -> float:
	return INF if _def == null else minf(_quiet_ends_at(), urgent_call_at)


func _quiet_ends_at() -> float:
	return last_notable_at + quiet_seconds()


## An old save starts the quiet clock from the moment it is loaded.
func restart(now: float) -> void:
	last_notable_at = now
	seen_events = _event_log.size()


func process(now: float) -> void:
	if _def == null:
		return
	_scan()
	if now >= urgent_call_at:
		urgent_call_at = INF
		# A full line by the morning means he found another supplier; the phone stays quiet.
		if _orders.has_room():
			_trigger(URGENT_ORDER, now)
			last_notable_at = maxf(last_notable_at, now)
		seen_events = _event_log.size()
	if now < _quiet_ends_at():
		return
	last_notable_at = now
	if _busy():
		return
	var kind := _pick_kind()
	if kind == URGENT_ORDER and _orders.calls_resume_at(now) > now:
		urgent_call_at = minf(urgent_call_at, _orders.calls_resume_at(now))
		kind = _pick_kind(URGENT_ORDER)
	if not kind.is_empty():
		_trigger(kind, now)
	seen_events = _event_log.size()


func _scan() -> void:
	for event: SimEvent in _event_log.since(seen_events):
		if ALWAYS_NOTABLE.has(event.type) or _def.notable_events.has(event.type):
			last_notable_at = maxf(last_notable_at, event.game_time)
	seen_events = _event_log.size()


## Something is already going on; the director waits for the next quiet spell.
func _busy() -> bool:
	return _stories.is_pending() or _raids.pending or _suspicion.inspection_pending() or _first_day.blocks_director()


func applicable(kind: String) -> bool:
	match kind:
		URGENT_ORDER:
			return _orders.has_room()
		LORD_VISIT:
			return not _stories.untold(StoryDef.LORD).is_empty()
		RUMOUR:
			return _rumour_about() != ""
		BREAKDOWN:
			return not _problems.healthy_growing().is_empty()
		COURIER_TROUBLE:
			return not _deliveries_on_time().is_empty()
		STORY:
			return not _stories.untold(StoryDef.VILLAGE).is_empty()
	return false


func _deliveries_on_time() -> Array[Order]:
	var found: Array[Order] = []
	for order: Order in _orders.with_status(Order.Status.IN_TRANSIT):
		if not order.delayed:
			found.append(order)
	return found


func _pick_kind(except: String = "") -> String:
	var candidates: Array[String] = []
	var total := 0.0
	for kind: String in KINDS:
		if kind != except and _def.weight(kind) > 0.0 and applicable(kind):
			candidates.append(kind)
			total += _def.weight(kind)
	if candidates.is_empty():
		return ""
	var roll := _rng.randf() * total
	for kind: String in candidates:
		roll -= _def.weight(kind)
		if roll < 0.0:
			return kind
	return candidates[candidates.size() - 1]


func _rumour_about() -> String:
	if _suspicion.level >= _def.rumour_inspection_min_suspicion and not _suspicion.inspection_pending():
		return ABOUT_INSPECTION
	if _raids.enabled() and not _raids.pending and not _raids.expected:
		return ABOUT_RAID
	return ""


func _trigger(kind: String, now: float) -> void:
	var data := {"kind": kind}
	match kind:
		URGENT_ORDER:
			var quantity := _rng.randi_range(_def.urgent_quantity_min, _def.urgent_quantity_max)
			var strain_id := _orders.pick_strain()
			var price := Economy.price_with(_orders.price_strain(strain_id), _def.urgent_min_quality)
			var reward := roundi(float(quantity * price) * _config.orders.reward_multiplier * _def.urgent_reward_multiplier)
			data["order_id"] = _orders.inject(quantity, _def.urgent_min_quality, reward, _def.urgent_answer_hours, _def.urgent_deadline_hours, true, now, strain_id).id
		LORD_VISIT:
			var visit := _stories.untold(StoryDef.LORD)[0]
			_stories.start(visit, now, ACTOR)
			data["story_id"] = visit.id
		STORY:
			var told := _stories.untold(StoryDef.VILLAGE)
			var story := told[_rng.randi_range(0, told.size() - 1)]
			_stories.start(story, now, ACTOR)
			data["story_id"] = story.id
		RUMOUR:
			var about := _rumour_about()
			data["about"] = about
			if about == ABOUT_INSPECTION:
				_suspicion.schedule_inspection(now, _def.rumour_inspection_hours)
				data["hours"] = _def.rumour_inspection_hours
			else:
				_raids.expect()
		BREAKDOWN:
			var beds := _problems.healthy_growing()
			var target := beds[_rng.randi_range(0, beds.size() - 1)]
			_problems.force(target.id, Problems.LAMP, now)
			data["plot_id"] = target.id
		COURIER_TROUBLE:
			var on_road := _deliveries_on_time()[0]
			_couriers.delay(on_road, _def.courier_delay_hours * SimClock.GAME_SECONDS_PER_HOUR)
			data["order_id"] = on_road.id
			data["courier_id"] = on_road.courier_id
			data["hours"] = _def.courier_delay_hours
	_event_log.record(EventLog.DIRECTOR_EVENT, now, PackedStringArray([ACTOR]), data)


func to_dict() -> Dictionary:
	return {
		"last_notable_at": ExactFloat.encode(last_notable_at),
		"seen_events": seen_events,
		"urgent_call_at": ExactFloat.encode(urgent_call_at),
	}


func load_dict(data: Dictionary) -> void:
	last_notable_at = ExactFloat.decode(data["last_notable_at"])
	seen_events = int(data["seen_events"])
	urgent_call_at = ExactFloat.decode(data["urgent_call_at"]) if data.has("urgent_call_at") else INF
