class_name EventLog
extends RefCounted

const PLOT_PLANTED: String = "plot_planted"
const PLOT_WATERED: String = "plot_watered"
const PLOT_DRIED_OUT: String = "plot_dried_out"
const PLOT_STAGE_CHANGED: String = "plot_stage_changed"
const PLOT_HARVESTED: String = "plot_harvested"
const PRODUCT_SOLD: String = "product_sold"
const WORKER_HIRED: String = "worker_hired"
const WORKER_PAID: String = "worker_paid"
const WORKER_QUIT: String = "worker_quit"
const WORKER_TASK_STARTED: String = "worker_task_started"

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
