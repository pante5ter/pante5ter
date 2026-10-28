class_name DayCycle
extends RefCounted

## Where Jack is and the rhythm of his day: Reggie calls him home in the evening, a night out is
## noticed, and sleep at home carries him to the morning unless the farm raises an alarm.

const FARM: String = "farm"
const HOME: String = "home"
const STASH: String = "stash"
const PLACES: Array[String] = [FARM, HOME, STASH]
## Actor tag for Jack driving himself.
const JACK: String = "jack"

var place: String = FARM
## Set while Jack is on the road; he arrives at trip_arrives_at.
var trip_to: String = ""
var trip_arrives_at: float = INF
var next_evening_at: float = INF
var next_late_tick_at: float = INF
## Nights count from the first late hour after the start: a new game opens at midnight with the prologue.
var nights_from: float = INF
## The night Jack was last reported out, so the village talk is logged once a night.
var late_night_logged: int = -1
## When the current day began (the last waking, or the start); the day summary counts from here.
var day_started_at: float = 0.0
var slept_at: float = -1.0
## Reggie sent Jack home and he has not slept since: the bed takes him whatever the hour.
var called_home: bool = false

var _def: DayDef
var _suspicion: Suspicion
var _event_log: EventLog
var _economy: Economy


func _init(def: DayDef, suspicion: Suspicion, event_log: EventLog) -> void:
	_def = def
	_suspicion = suspicion
	_event_log = event_log
	if _def != null:
		start_at(0.0)


## Vivienne's bridge winnings after a night at home go here.
func attach_economy(economy: Economy) -> void:
	_economy = economy


func definition() -> DayDef:
	return _def


func enabled() -> bool:
	return _def != null


## Old saves and a fresh game: the evening and night clocks start counting from now.
func start_at(now: float) -> void:
	if _def == null:
		return
	next_evening_at = _next_hour_at(now, _def.evening_hour)
	nights_from = _next_hour_at(now, _def.late_hour)
	next_late_tick_at = nights_from
	day_started_at = now


func travelling() -> bool:
	return not trip_to.is_empty()


func is_home() -> bool:
	return place == HOME and not travelling()


func travel_seconds() -> float:
	return _def.travel_minutes * 60.0 if _def != null else 0.0


func start_trip(destination: String, now: float, actor: String) -> CommandResult:
	if not PLACES.has(destination):
		return CommandResult.failure(CommandResult.UNKNOWN_PLACE)
	if travelling():
		return CommandResult.failure(CommandResult.ON_THE_ROAD)
	if destination == place:
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	trip_to = destination
	trip_arrives_at = now + travel_seconds()
	_event_log.record(EventLog.JACK_LEFT, now, PackedStringArray([actor, JACK]), {
		"from": place,
		"to": destination,
		"arrives_at": trip_arrives_at,
	})
	return CommandResult.success()


func can_sleep(now: float) -> String:
	if _def == null:
		return CommandResult.UNKNOWN_COMMAND
	if not is_home():
		return CommandResult.NOT_AT_HOME
	if is_daytime(now) and not called_home:
		return CommandResult.TOO_EARLY_TO_SLEEP
	return ""


## Between the morning and the hour the bed starts taking Jack.
func is_daytime(at: float) -> bool:
	var hour := fmod(at, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR
	return hour < _def.sleep_from_hour and hour >= _def.wake_hour


## A night's sleep ends in the morning; sent home but back after sunrise, he sleeps a few hours.
func wake_time(now: float) -> float:
	if is_daytime(now):
		return now + maxf(_def.day_sleep_hours, 0.0) * SimClock.GAME_SECONDS_PER_HOUR
	return _next_hour_at(now, _def.wake_hour)


func fall_asleep(now: float, actor: String) -> void:
	slept_at = now
	_event_log.record(EventLog.JACK_SLEPT, now, PackedStringArray([actor, JACK]), {"wakes_at": wake_time(now)})


func wake_up(now: float) -> void:
	day_started_at = now
	called_home = false
	_event_log.record(EventLog.JACK_WOKE, now, PackedStringArray([JACK]), {"slept_at": slept_at})
	_home_night(now)


## Waking at home after a real night (not the prologue's): less talk in the village and a little money.
## A daytime sleep after a night out is not one.
func _home_night(now: float) -> void:
	if not is_home() or now < nights_from or (slept_at >= 0.0 and is_daytime(slept_at)):
		return
	var before := _suspicion.level
	_suspicion.add(-maxf(_def.home_night_suspicion_relief, 0.0))
	var relief := before - _suspicion.level
	var bonus := maxi(_def.home_night_money, 0) if _economy != null else 0
	if bonus > 0:
		_economy.earn(bonus)
	if relief <= 0.0 and bonus <= 0:
		return
	_event_log.record(EventLog.HOME_NIGHT, now, PackedStringArray([JACK, "vivienne"]), {
		"suspicion_relief": relief,
		"bonus": bonus,
		"money": _economy.money if _economy != null else 0,
	})


func interrupt_sleep(alarm: SimEvent) -> void:
	_event_log.record(EventLog.SLEEP_INTERRUPTED, alarm.game_time, PackedStringArray([JACK]), {
		"alarm": alarm.type,
		"alarm_seq": alarm.seq,
	})


## What wakes Jack at night: trouble at the farm someone has to answer.
static func is_alarm(event: SimEvent) -> bool:
	return event.type == EventLog.RAID_STARTED or event.type == EventLog.INSPECTION_WARNED


func next_event_time() -> float:
	return minf(trip_arrives_at, minf(next_evening_at, next_late_tick_at))


func process(now: float) -> void:
	if travelling() and now >= trip_arrives_at:
		_arrive(now)
	while now >= next_evening_at:
		_evening(next_evening_at)
		next_evening_at += SimClock.GAME_SECONDS_PER_DAY
	while now >= next_late_tick_at:
		_late_tick(next_late_tick_at)
		next_late_tick_at = _next_late_tick(next_late_tick_at)


func _arrive(now: float) -> void:
	var from := place
	place = trip_to
	trip_to = ""
	trip_arrives_at = INF
	_event_log.record(EventLog.JACK_ARRIVED, now, PackedStringArray([JACK]), {"from": from, "to": place})


func _evening(at: float) -> void:
	if is_home():
		return
	called_home = true
	_event_log.record(EventLog.EVENING_CALL, at, PackedStringArray([Helper.ACTOR, JACK]), {"place": place})


## Each late hour away from home adds to the suspicion: a lit container and a car out at night.
func _late_tick(at: float) -> void:
	if is_home() or not _is_late(at) or _def.late_suspicion_per_hour <= 0.0:
		return
	_suspicion.add(_def.late_suspicion_per_hour)
	var night := floori((at - _def.late_until_hour * SimClock.GAME_SECONDS_PER_HOUR) / SimClock.GAME_SECONDS_PER_DAY)
	if night == late_night_logged:
		return
	late_night_logged = night
	_event_log.record(EventLog.JACK_OUT_LATE, at, PackedStringArray([JACK]), {
		"place": place,
		"suspicion_per_hour": _def.late_suspicion_per_hour,
	})


## Late at night and past the first counted evening.
func is_night(at: float) -> bool:
	return _def != null and at >= nights_from and _is_late(at)


func _is_late(at: float) -> bool:
	var hour := fmod(at, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR
	return hour >= _def.late_hour or hour < _def.late_until_hour


## Hourly through the night, then straight on to the next evening's late hour.
func _next_late_tick(after: float) -> float:
	var next := after + SimClock.GAME_SECONDS_PER_HOUR
	if _is_late(next):
		return next
	return _next_hour_at(next, _def.late_hour)


## The first moment at or after `now` when the clock shows `hour`.
static func _next_hour_at(now: float, hour: float) -> float:
	var day_start := floorf(now / SimClock.GAME_SECONDS_PER_DAY) * SimClock.GAME_SECONDS_PER_DAY
	var at := day_start + hour * SimClock.GAME_SECONDS_PER_HOUR
	if at <= now:
		at += SimClock.GAME_SECONDS_PER_DAY
	return at


func to_dict() -> Dictionary:
	return {
		"place": place,
		"trip_to": trip_to,
		"trip_arrives_at": ExactFloat.encode(trip_arrives_at),
		"next_evening_at": ExactFloat.encode(next_evening_at),
		"next_late_tick_at": ExactFloat.encode(next_late_tick_at),
		"nights_from": ExactFloat.encode(nights_from),
		"late_night_logged": late_night_logged,
		"day_started_at": ExactFloat.encode(day_started_at),
		"slept_at": ExactFloat.encode(slept_at),
		"called_home": called_home,
	}


func load_dict(data: Dictionary) -> void:
	place = String(data["place"]) if PLACES.has(String(data["place"])) else FARM
	trip_to = String(data["trip_to"])
	trip_arrives_at = ExactFloat.decode(data["trip_arrives_at"])
	next_evening_at = ExactFloat.decode(data["next_evening_at"])
	next_late_tick_at = ExactFloat.decode(data["next_late_tick_at"])
	nights_from = ExactFloat.decode(data["nights_from"])
	late_night_logged = int(data["late_night_logged"])
	day_started_at = ExactFloat.decode(data["day_started_at"])
	slept_at = ExactFloat.decode(data["slept_at"])
	called_home = data.get("called_home", false) == true
