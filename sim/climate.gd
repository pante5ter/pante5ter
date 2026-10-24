class_name Climate
extends RefCounted

## Temperature and humidity per bunker room. Damp air grows mold on the beds;
## stronger ventilation dries it at an electricity cost billed every few hours.

const ACTOR: String = "power_company"

var sensor_installed: bool = false
var ventilation: int = 0
var power_owed: int = 0
var hours_since_bill: int = 0
var next_tick_at: float = SimClock.GAME_SECONDS_PER_HOUR

var _def: ClimateDef
var _grow: Grow
var _suspicion: Suspicion
var _economy: Economy
var _event_log: EventLog


func _init(def: ClimateDef, grow: Grow, suspicion: Suspicion, economy: Economy, event_log: EventLog) -> void:
	_def = def
	_grow = grow
	_suspicion = suspicion
	_economy = economy
	_event_log = event_log


func exists() -> bool:
	return _def != null


func definition() -> ClimateDef:
	return _def


func bed_room() -> RoomDef:
	if _def == null:
		return null
	for room: RoomDef in _def.rooms:
		if room.has_beds:
			return room
	return null


## What actually runs: a quiet farm is down to the free vent.
func running() -> VentilationDef:
	if _def == null or _def.ventilation.is_empty():
		return null
	return _def.ventilation[0 if _suspicion.quiet else ventilation]


func humidity(room: RoomDef) -> float:
	var value := room.base_humidity
	if room.has_beds:
		value += room.humidity_per_bed * float(_growing_beds())
	var air := running()
	if air != null:
		value -= air.humidity_drop
	return clampf(value, 0.0, 100.0)


func temperature(room: RoomDef) -> float:
	var value := room.base_temperature
	if room.has_beds and not _suspicion.quiet:
		value += room.heat_per_bed * float(_growing_beds())
	var air := running()
	if air != null:
		value -= air.cooling
	return value


## How damp air scales the farm's trouble chance into a mold chance; 0 when the beds' room is dry.
func mold_factor() -> float:
	var room := bed_room()
	if room == null:
		return 0.0
	var excess := humidity(room) - _def.mold_safe_humidity
	if excess <= 0.0:
		return 0.0
	return minf(excess * _def.mold_factor_per_point, _def.mold_factor_max)


func _growing_beds() -> int:
	var count := 0
	for target: Plot in _grow.plots():
		if target.is_growing():
			count += 1
	return count


## A save from before the bunker had a climate: the first hour starts now.
func start_at(now: float) -> void:
	next_tick_at = now + SimClock.GAME_SECONDS_PER_HOUR


func buy_sensor(now: float, actor: String) -> CommandResult:
	if _def == null:
		return CommandResult.failure(CommandResult.UNKNOWN_ITEM)
	if sensor_installed:
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	if not _economy.spend(_def.sensor_price):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	sensor_installed = true
	_event_log.record(EventLog.SENSOR_INSTALLED, now, PackedStringArray([actor]), {"cost": _def.sensor_price, "money": _economy.money})
	return CommandResult.success(_def.sensor_price)


func set_ventilation(level: int, now: float, actor: String) -> CommandResult:
	if _def == null or level < 0 or level >= _def.ventilation.size():
		return CommandResult.failure(CommandResult.UNKNOWN_CHOICE)
	ventilation = level
	_event_log.record(EventLog.VENTILATION_SET, now, PackedStringArray([actor]), {"level": level})
	return CommandResult.success(level)


func next_event_time() -> float:
	return next_tick_at if _def != null else INF


func process(now: float) -> void:
	if _def == null:
		return
	while now >= next_tick_at:
		_tick(next_tick_at)
		next_tick_at += SimClock.GAME_SECONDS_PER_HOUR


func _tick(at: float) -> void:
	var air := running()
	if air != null:
		power_owed += air.power_per_hour
	hours_since_bill += 1
	if hours_since_bill >= maxi(_def.bill_every_hours, 1):
		_bill(at)


func _bill(at: float) -> void:
	hours_since_bill = 0
	var amount := power_owed
	power_owed = 0
	if amount <= 0:
		return
	if _economy.spend(amount):
		_event_log.record(EventLog.POWER_BILLED, at, PackedStringArray([ACTOR]), {"amount": amount, "money": _economy.money})
		return
	ventilation = 0
	_event_log.record(EventLog.POWER_CUT, at, PackedStringArray([ACTOR]), {"amount": amount, "money": _economy.money})


func to_dict() -> Dictionary:
	return {
		"sensor_installed": sensor_installed,
		"ventilation": ventilation,
		"power_owed": power_owed,
		"hours_since_bill": hours_since_bill,
		"next_tick_at": ExactFloat.encode(next_tick_at),
	}


func load_dict(data: Dictionary) -> void:
	sensor_installed = data["sensor_installed"] == true
	ventilation = int(data["ventilation"])
	power_owed = int(data["power_owed"])
	hours_since_bill = int(data["hours_since_bill"])
	next_tick_at = ExactFloat.decode(data["next_tick_at"])
	if _def != null:
		ventilation = clampi(ventilation, 0, maxi(_def.ventilation.size() - 1, 0))
