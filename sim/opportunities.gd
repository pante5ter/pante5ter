class_name Opportunities
extends RefCounted

## Vivienne's village news as business, one chance a day at most and tied to her first line of the
## morning: a household selling up puts used kit on sale, a lord in debt is a lead on a future field,
## a party at a manor rings in one big retail order.

const SALE: String = "sale"
const LEAD: String = "lead"
const PARTY: String = "party"
const KINDS: Array[String] = [SALE, LEAD, PARTY]
const ACTOR: String = "vivienne"

var next_open_at: float = INF
## Leads on fields: gossip line index and when the lead goes cold.
var leads: Array[Dictionary] = []

var _def: OpportunitiesDef
var _rng: SimRng
var _upgrades: Upgrades
var _orders: Orders
var _event_log: EventLog


func _init(def: OpportunitiesDef, rng: SimRng, upgrades: Upgrades, orders: Orders, event_log: EventLog) -> void:
	_def = def
	_rng = rng
	_upgrades = upgrades
	_orders = orders
	_event_log = event_log
	if _def != null:
		next_open_at = (float(_def.start_day) * 24.0 + _def.open_hour) * SimClock.GAME_SECONDS_PER_HOUR


func enabled() -> bool:
	return _def != null and not _def.gossip_kinds.is_empty()


## The line Vivienne opens day `day` with.
func gossip_index(day: int) -> int:
	if not enabled():
		return -1
	return posmod(day * _def.gossip_stride, _def.gossip_kinds.size())


func kind_on(day: int) -> String:
	return _def.kind_for(gossip_index(day)) if enabled() else ""


## A save from before the gossip meant business: the first chance is the next morning's.
func start_at(now: float) -> void:
	if _def == null:
		return
	var slot := floorf(now / SimClock.GAME_SECONDS_PER_DAY) * SimClock.GAME_SECONDS_PER_DAY + _def.open_hour * SimClock.GAME_SECONDS_PER_HOUR
	next_open_at = slot if slot > now else slot + SimClock.GAME_SECONDS_PER_DAY


func next_event_time() -> float:
	if not enabled():
		return INF
	var next := next_open_at
	if not _upgrades.sale_id.is_empty():
		next = minf(next, _upgrades.sale_until)
	for lead: Dictionary in leads:
		next = minf(next, float(lead["until"]))
	return next


func process(now: float) -> void:
	if not enabled():
		return
	if not _upgrades.sale_id.is_empty() and now >= _upgrades.sale_until:
		var expired := _upgrades.sale_until
		_event_log.record(EventLog.OPPORTUNITY_EXPIRED, expired, PackedStringArray([ACTOR]), {"kind": SALE, "upgrade_id": _upgrades.sale_id})
		_upgrades.end_sale()
	for lead: Dictionary in leads.duplicate():
		if now >= float(lead["until"]):
			leads.erase(lead)
			_event_log.record(EventLog.OPPORTUNITY_EXPIRED, float(lead["until"]), PackedStringArray([ACTOR]), {"kind": LEAD, "gossip": int(lead["gossip"])})
	while now >= next_open_at:
		_open(next_open_at)
		next_open_at += SimClock.GAME_SECONDS_PER_DAY


func _open(at: float) -> void:
	var day := floori(at / SimClock.GAME_SECONDS_PER_DAY)
	if day < _def.start_day:
		return
	var gossip := gossip_index(day)
	match _def.kind_for(gossip):
		SALE:
			_open_sale(gossip, at)
		LEAD:
			_open_lead(gossip, at)
		PARTY:
			_open_party(gossip, at)


func _open_sale(gossip: int, at: float) -> void:
	var candidates := _upgrades.sale_candidates()
	if candidates.is_empty():
		return
	var picked := candidates[0] if candidates.size() == 1 else candidates[_rng.randi_range(0, candidates.size() - 1)]
	var full := _upgrades.find(picked).price
	var price := roundi(float(full) * (1.0 - clampf(_def.sale_discount, 0.0, 1.0)))
	var until := at + _def.sale_hours * SimClock.GAME_SECONDS_PER_HOUR
	_upgrades.start_sale(picked, price, until)
	_record(SALE, gossip, at, {"upgrade_id": picked, "price": price, "full_price": full, "until": until})


func _open_lead(gossip: int, at: float) -> void:
	var until := at + _def.lead_days * SimClock.GAME_SECONDS_PER_DAY
	leads.append({"gossip": gossip, "opened_at": at, "until": until})
	_record(LEAD, gossip, at, {"until": until})


func _open_party(gossip: int, at: float) -> void:
	var quantity := _rng.randi_range(_def.party_quantity_min, maxi(_def.party_quantity_min, _def.party_quantity_max))
	var min_quality := mini(_def.party_min_quality, _orders.achievable_quality(""))
	var reward := roundi(float(quantity * Economy.price_with(_orders.price_strain(""), min_quality)) * _def.party_price_multiplier)
	var order := _orders.inject(quantity, min_quality, reward, _def.party_answer_hours, _def.party_deadline_hours, false, at, "", Order.RETAIL)
	_record(PARTY, gossip, at, {"order_id": order.id, "quantity": quantity, "reward": reward})


func _record(kind: String, gossip: int, at: float, data: Dictionary) -> void:
	var record := data.duplicate()
	record["kind"] = kind
	record["gossip"] = gossip
	_event_log.record(EventLog.OPPORTUNITY_OPENED, at, PackedStringArray([ACTOR]), record)


func to_dict() -> Dictionary:
	var stored: Array[Dictionary] = []
	for lead: Dictionary in leads:
		stored.append({"gossip": lead["gossip"], "opened_at": ExactFloat.encode(float(lead["opened_at"])), "until": ExactFloat.encode(float(lead["until"]))})
	return {"next_open_at": ExactFloat.encode(next_open_at), "leads": stored}


func load_dict(data: Dictionary) -> void:
	next_open_at = ExactFloat.decode(data["next_open_at"]) if data.has("next_open_at") else next_open_at
	leads.clear()
	for item: Variant in data.get("leads", []) as Array:
		var lead := item as Dictionary
		leads.append({"gossip": int(lead["gossip"]), "opened_at": ExactFloat.decode(lead["opened_at"]), "until": ExactFloat.decode(lead["until"])})
