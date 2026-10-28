class_name DayEndWatch
extends RefCounted

## Which stretch of Jack's time has had its summary of the day. One summary per day: at bedtime, or,
## when Jack stayed up through the night, at the morning hour for the day that ended. The view's memory,
## not the sim's: every level has its own HUD, so it lives here and survives scene changes.

static var _sim_id: int = 0
static var _summarised_until: float = 0.0


## The summary covers Jack's time from here on.
static func summarised_until(sim: SimState) -> float:
	_adopt(sim)
	return _summarised_until


static func mark(sim: SimState, until: float) -> void:
	_adopt(sim)
	_summarised_until = maxf(_summarised_until, until)


## Where the next summary starts: Jack's last waking, unless a summary already told part of that day.
static func day_from(sim: SimState) -> float:
	return maxf(sim.day.day_started_at, summarised_until(sim))


## «День N окончен» counts from the start of the stretch, never from the hour it is shown at.
static func day_number(from: float) -> int:
	return floori(from / SimClock.GAME_SECONDS_PER_DAY) + 1


## The first morning after the summarised stretch that a night stands between; INF when none can come.
static func next_morning(sim: SimState) -> float:
	if not sim.day.enabled():
		return INF
	var after := summarised_until(sim)
	var morning := _next_hour_at(after, sim.day.definition().wake_hour)
	# The night a new game opens with is the prologue's: its morning closes no day.
	while morning <= sim.day.nights_from:
		morning += SimClock.GAME_SECONDS_PER_DAY
	return morning


## Jack stayed up through a night: the day before it needs its summary now.
static func all_nighter_due(sim: SimState) -> bool:
	return sim.clock.elapsed_game_seconds >= next_morning(sim)


## A fresh game or a load starts counting from now: old days are never replayed.
static func _adopt(sim: SimState) -> void:
	if sim.get_instance_id() == _sim_id:
		return
	_sim_id = sim.get_instance_id()
	_summarised_until = sim.day.day_started_at
	if not sim.day.enabled():
		return
	var now := sim.clock.elapsed_game_seconds
	var last_morning := _next_hour_at(now, sim.day.definition().wake_hour) - SimClock.GAME_SECONDS_PER_DAY
	if last_morning > sim.day.nights_from and last_morning <= now:
		_summarised_until = maxf(_summarised_until, last_morning)


static func _next_hour_at(now: float, hour: float) -> float:
	var day_start := floorf(now / SimClock.GAME_SECONDS_PER_DAY) * SimClock.GAME_SECONDS_PER_DAY
	var at := day_start + hour * SimClock.GAME_SECONDS_PER_HOUR
	if at <= now:
		at += SimClock.GAME_SECONDS_PER_DAY
	return at


## Tests start from a clean memory.
static func forget() -> void:
	_sim_id = 0
	_summarised_until = 0.0
