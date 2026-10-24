class_name EventLog
extends RefCounted

const PLOT_PLANTED: String = "plot_planted"
const PLOT_WATERED: String = "plot_watered"
const PLOT_DRIED_OUT: String = "plot_dried_out"
const PLOT_STAGE_CHANGED: String = "plot_stage_changed"
const PLOT_HARVESTED: String = "plot_harvested"
const PLOT_CROP_EATEN: String = "plot_crop_eaten"
const PRODUCT_SOLD: String = "product_sold"
const WORKER_HIRED: String = "worker_hired"
const WORKER_PAID: String = "worker_paid"
const WORKER_QUIT: String = "worker_quit"
const WORKER_TASK_STARTED: String = "worker_task_started"
const WORKER_FIRED: String = "worker_fired"
const PLOT_FERTILIZED: String = "plot_fertilized"
const PLOT_PRUNED: String = "plot_pruned"
const PLOT_BOUGHT: String = "plot_bought"
const SUPPLY_ORDERED: String = "supply_ordered"
const SUPPLY_DELIVERED: String = "supply_delivered"
const ORDER_RECEIVED: String = "order_received"
const ORDER_ACCEPTED: String = "order_accepted"
const ORDER_DECLINED: String = "order_declined"
const ORDER_HAGGLED: String = "order_haggled"
const ORDER_WALKED_AWAY: String = "order_walked_away"
const ORDER_MISSED: String = "order_missed"
const ORDER_DISPATCHED: String = "order_dispatched"
const DELIVERY_STOPPED: String = "delivery_stopped"
const COURIER_HIRED: String = "courier_hired"
const COURIER_FIRED: String = "courier_fired"
const COURIER_STOLE: String = "courier_stole"
const COURIER_QUIT: String = "courier_quit"
const PACKING_STARTED: String = "packing_started"
const PACKING_DONE: String = "packing_done"
const PARCEL_PICKED_UP: String = "parcel_picked_up"
const WENT_QUIET: String = "went_quiet"
const BACK_TO_WORK: String = "back_to_work"
const ORDER_PAID: String = "order_paid"
const ORDER_EXPIRED: String = "order_expired"
const MILESTONE_REACHED: String = "milestone_reached"
const PLOT_PROBLEM: String = "plot_problem"
const PLOT_TREATED: String = "plot_treated"
const WORKER_STOLE: String = "worker_stole"
const INSPECTION_WARNED: String = "inspection_warned"
const INSPECTION_PASSED: String = "inspection_passed"
const INSPECTION_FAILED: String = "inspection_failed"
const RAID_STARTED: String = "raid_started"
const RAID_RESOLVED: String = "raid_resolved"
const RENT_PAID: String = "rent_paid"
const RENT_MISSED: String = "rent_missed"
const RENT_EVICTED: String = "rent_evicted"
const HELPER_UNPAID: String = "helper_unpaid"
const HELPER_TRAINING_STARTED: String = "helper_training_started"
const HELPER_SKILL_LEARNED: String = "helper_skill_learned"
const HELPER_SAVED: String = "helper_saved"
const HELPER_SKILLS_REFUNDED: String = "helper_skills_refunded"
const SUPPLY_RULE_SET: String = "supply_rule_set"
const STORY_STARTED: String = "story_started"
const STORY_RESOLVED: String = "story_resolved"
const STORY_EXPIRED: String = "story_expired"
const DIRECTOR_EVENT: String = "director_event"
const FIRST_DAY_STEP: String = "first_day_step"
const INTRIGUE_STARTED: String = "intrigue_started"
const INTRIGUE_STEP: String = "intrigue_step"
const INTRIGUE_CLUE: String = "intrigue_clue"
const INTRIGUE_RESOLVED: String = "intrigue_resolved"
const SENSOR_INSTALLED: String = "sensor_installed"
const VENTILATION_SET: String = "ventilation_set"
const POWER_BILLED: String = "power_billed"
const POWER_CUT: String = "power_cut"
const HAUL_STARTED: String = "haul_started"
const HAUL_ARRIVED: String = "haul_arrived"
const HAUL_STOPPED: String = "haul_stopped"
const JACK_LEFT: String = "jack_left"
const JACK_ARRIVED: String = "jack_arrived"
const EVENING_CALL: String = "evening_call"
const JACK_OUT_LATE: String = "jack_out_late"
const JACK_SLEPT: String = "jack_slept"
const JACK_WOKE: String = "jack_woke"
const SLEEP_INTERRUPTED: String = "sleep_interrupted"

var _entries: Array[SimEvent] = []


func record(type: String, game_time: float, actors: PackedStringArray, data: Dictionary = {}) -> SimEvent:
	var event := SimEvent.new()
	event.seq = _entries.size()
	event.type = type
	event.game_time = game_time
	event.actors = actors
	event.data = _as_json_shape(data)
	_entries.append(event)
	return event


func entries() -> Array[SimEvent]:
	return _entries.duplicate()


func of_type(type: String) -> Array[SimEvent]:
	var matching: Array[SimEvent] = []
	for event: SimEvent in _entries:
		if event.type == type:
			matching.append(event)
	return matching


func since(seq: int) -> Array[SimEvent]:
	var result: Array[SimEvent] = []
	for index: int in range(maxi(seq, 0), _entries.size()):
		result.append(_entries[index])
	return result


func size() -> int:
	return _entries.size()


func last() -> SimEvent:
	if _entries.is_empty():
		return null
	return _entries[_entries.size() - 1]


func to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: SimEvent in _entries:
		result.append(event.to_dict())
	return result


func load_array(source: Array) -> void:
	_entries.clear()
	for item: Variant in source:
		_entries.append(SimEvent.from_dict(item as Dictionary))


static func _as_json_shape(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data, "", true, true))
	assert(parsed is Dictionary, "event data must be JSON-serializable")
	return parsed as Dictionary
