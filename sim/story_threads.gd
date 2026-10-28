class_name StoryThreads
extends RefCounted

## Plot threads told over several days: each beat comes `delay_hours` after the beats it follows
## were answered, within its hours of the day, and never over another story. Nothing is saved:
## what was told and when is all in the stories and the event log.

const ACTOR: String = "thread"

var _config: BalanceConfig
var _stories: Stories
var _clock: SimClock
var _event_log: EventLog
var _answered_at: Dictionary[String, float] = {}
var _seen: int = 0


func _init(config: BalanceConfig, stories: Stories, clock: SimClock, event_log: EventLog) -> void:
	_config = config
	_stories = stories
	_clock = clock
	_event_log = event_log


func beats() -> Array[StoryDef]:
	return _config.threads


## The earliest moment the beat may start; INF once told or while a beat before it is unanswered.
func due_at(story: StoryDef) -> float:
	_scan()
	if _stories.used.has(story.id) or story.choices.is_empty():
		return INF
	var answered := 0.0
	for earlier: String in story.after_stories:
		if not _answered_at.has(earlier):
			return INF
		answered = maxf(answered, _answered_at[earlier])
	var earliest := answered + maxf(story.delay_hours, 0.0) * SimClock.GAME_SECONDS_PER_HOUR
	return story.opens_at(maxf(earliest, _clock.elapsed_game_seconds))


func next_event_time() -> float:
	if _stories.is_pending():
		return INF
	var next := INF
	for story: StoryDef in beats():
		next = minf(next, due_at(story))
	return next


func update(now: float) -> void:
	if _stories.is_pending():
		return
	for story: StoryDef in beats():
		if due_at(story) <= now and _stories.start(story, now, ACTOR):
			return


func _scan() -> void:
	if _seen > _event_log.size():
		_seen = 0
		_answered_at.clear()
	for event: SimEvent in _event_log.since(_seen):
		if event.type == EventLog.STORY_RESOLVED:
			_answered_at[String(event.data.get("story_id", ""))] = event.game_time
	_seen = _event_log.size()
