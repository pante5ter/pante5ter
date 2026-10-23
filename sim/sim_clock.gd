class_name SimClock
extends RefCounted

const GAME_SECONDS_PER_DAY: float = 86400.0
const GAME_SECONDS_PER_HOUR: float = 3600.0

var elapsed_game_seconds: float = 0.0
var _game_seconds_per_real_second: float = 1.0


func _init(real_seconds_per_game_day: float) -> void:
	assert(real_seconds_per_game_day > 0.0, "real_seconds_per_game_day must be positive")
	_game_seconds_per_real_second = GAME_SECONDS_PER_DAY / real_seconds_per_game_day


func real_to_game(real_seconds: float) -> float:
	return maxf(real_seconds, 0.0) * _game_seconds_per_real_second


func advance(game_seconds: float) -> void:
	elapsed_game_seconds += maxf(game_seconds, 0.0)


func advance_to(game_time: float) -> void:
	elapsed_game_seconds = maxf(elapsed_game_seconds, game_time)


func day() -> int:
	return floori(elapsed_game_seconds / GAME_SECONDS_PER_DAY)


func hour_of_day() -> float:
	return fmod(elapsed_game_seconds, GAME_SECONDS_PER_DAY) / GAME_SECONDS_PER_HOUR


func to_dict() -> Dictionary:
	return {"elapsed_game_seconds": elapsed_game_seconds}


func load_dict(data: Dictionary) -> void:
	elapsed_game_seconds = float(data["elapsed_game_seconds"])
