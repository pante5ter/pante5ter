extends Node

const BALANCE_PATH: String = "res://content/balance.tres"
const DEFAULT_SAVE_PATH: String = "user://save.json"
const DEFAULT_UI_SETTINGS_PATH: String = "user://ui.cfg"
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var sim: SimState
var is_running: bool = false
var save_path: String = DEFAULT_SAVE_PATH
var ui_settings_path: String = DEFAULT_UI_SETTINGS_PATH
var time_scale: float = 1.0
var _balance: BalanceConfig
var _fresh_start: bool = false
var _seen_events: int = 0


func _ready() -> void:
	new_game(int(Time.get_unix_time_from_system()), true)


func _process(delta: float) -> void:
	if is_running and sim != null:
		sim.apply(AdvanceTimeCommand.new(delta * time_scale))
		_slow_down_for_story()


## At x2/x4 story beats came faster than they could be read; each one brings the game back to x1.
## The sim knows nothing of real time, so the pacing lives here rather than in a real-time gap.
func _slow_down_for_story() -> void:
	var beat := false
	for event: SimEvent in sim.event_log.since(_seen_events):
		beat = beat or Stories.is_beat(event)
	_seen_events = sim.event_log.size()
	if beat:
		set_speed(0)


func set_speed(index: int) -> void:
	time_scale = SPEEDS[clampi(index, 0, SPEEDS.size() - 1)]


func new_game(seed_value: int, fresh_start: bool = false) -> void:
	sim = SimState.new(_get_balance(), seed_value)
	_seen_events = sim.event_log.size()
	_fresh_start = fresh_start


## True once after a new game that should open with the prologue.
func take_fresh_start() -> bool:
	var fresh := _fresh_start
	_fresh_start = false
	return fresh


func save_game(path: String = "") -> Error:
	if sim == null:
		return ERR_UNCONFIGURED
	if path.is_empty():
		path = save_path
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(sim.to_json())
	file.close()
	return DirAccess.rename_absolute(temp_path, path)


func load_game(path: String = "") -> Error:
	if path.is_empty():
		path = save_path
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var text := FileAccess.get_file_as_string(path)
	var loaded := SimState.from_json(text, _get_balance())
	if loaded == null:
		return ERR_PARSE_ERROR
	sim = loaded
	_seen_events = sim.event_log.size()
	_fresh_start = false
	return OK


func _get_balance() -> BalanceConfig:
	if _balance == null:
		_balance = load(BALANCE_PATH) as BalanceConfig
	return _balance
