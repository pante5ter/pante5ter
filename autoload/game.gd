extends Node

const BALANCE_PATH: String = "res://content/balance.tres"
const DEFAULT_SAVE_PATH: String = "user://save.json"

var sim: SimState
var is_running: bool = false
var save_path: String = DEFAULT_SAVE_PATH
var _balance: BalanceConfig


func _ready() -> void:
	new_game(int(Time.get_unix_time_from_system()))


func _process(delta: float) -> void:
	if is_running and sim != null:
		sim.apply(AdvanceTimeCommand.new(delta))


func new_game(seed_value: int) -> void:
	sim = SimState.new(_get_balance(), seed_value)


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
	return OK


func _get_balance() -> BalanceConfig:
	if _balance == null:
		_balance = load(BALANCE_PATH) as BalanceConfig
	return _balance
