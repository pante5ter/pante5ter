class_name SimEvent
extends RefCounted

var seq: int = 0
var type: String = ""
var game_time: float = 0.0
var actors: PackedStringArray = PackedStringArray()
var data: Dictionary = {}


func _init(event_type: String = "", at: float = 0.0, event_actors: PackedStringArray = PackedStringArray(), event_data: Dictionary = {}) -> void:
	type = event_type
	game_time = at
	actors = event_actors
	data = event_data


func to_dict() -> Dictionary:
	return {
		"seq": seq,
		"type": type,
		"game_time": ExactFloat.encode(game_time),
		"actors": Array(actors),
		"data": data,
	}


static func from_dict(source: Dictionary) -> SimEvent:
	var event := SimEvent.new()
	event.seq = int(source["seq"])
	event.type = String(source["type"])
	event.game_time = ExactFloat.decode(source["game_time"])
	event.actors = PackedStringArray(source["actors"] as Array)
	event.data = source["data"] as Dictionary
	return event
