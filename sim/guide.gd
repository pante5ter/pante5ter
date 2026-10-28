class_name Guide
extends RefCounted

## The first minutes, one small goal at a time, inside the first-day script. A goal is met by what
## really happened in the event log, in any order: doing a later thing early simply ticks it off.

enum Step { GO_DOWN, PLANT, WATER, PRUNE, HIRE, HARVEST, HAUL, PACK, SEND, DONE }

const ACTOR: String = "reggie"

## Names of the goals already met.
var done: Array[String] = []
var seen_events: int = 0
## Skipped from the menu, or a game that never had the guide (an old save, a skipped first day).
var off: bool = false

var _event_log: EventLog
var _shown: Step = Step.DONE


func _init(config: BalanceConfig, event_log: EventLog) -> void:
	_event_log = event_log
	off = config.guide == null or config.first_day == null
	seen_events = event_log.size()
	_shown = current()


static func step_name(value: Step) -> String:
	return String(Step.keys()[value]).to_lower()


## Goals in the chain, DONE not counted.
static func step_count() -> int:
	return Step.DONE


static func steps_met_by(event: SimEvent) -> Array[Step]:
	var met: Array[Step] = []
	match event.type:
		EventLog.BUNKER_ENTERED:
			met.append(Step.GO_DOWN)
		EventLog.PLOT_PLANTED:
			met.append(Step.GO_DOWN)
			met.append(Step.PLANT)
		EventLog.PLOT_WATERED:
			met.append(Step.WATER)
		EventLog.PLOT_PRUNED:
			met.append(Step.PRUNE)
		EventLog.PLOT_HARVESTED, EventLog.PLOT_CROP_EATEN:
			# A bed harvested unpruned has missed its pruning: no point waiting for it.
			met.append(Step.PRUNE)
			met.append(Step.HARVEST)
		EventLog.WORKER_HIRED:
			if String(event.data.get("role", WorkerDef.FARMHAND)) == WorkerDef.FARMHAND:
				met.append(Step.HIRE)
		EventLog.HAUL_ARRIVED:
			met.append(Step.HAUL)
		EventLog.PACKING_DONE:
			met.append(Step.PACK)
		EventLog.ORDER_DISPATCHED:
			met.append(Step.SEND)
	return met


func active() -> bool:
	return current() != Step.DONE


func current() -> Step:
	if off:
		return Step.DONE
	for value: int in Step.DONE:
		if not done.has(step_name(value as Step)):
			return value as Step
	return Step.DONE


func is_done(value: Step) -> bool:
	return off or done.has(step_name(value))


func update(now: float) -> void:
	if off:
		seen_events = _event_log.size()
		return
	for event: SimEvent in _event_log.since(seen_events):
		for met: Step in steps_met_by(event):
			if not done.has(step_name(met)):
				done.append(step_name(met))
	seen_events = _event_log.size()
	var now_step := current()
	if now_step == _shown:
		return
	_shown = now_step
	_event_log.record(EventLog.GUIDE_STEP, now, PackedStringArray([ACTOR]), {"step": step_name(now_step)})
	seen_events = _event_log.size()


func skip(now: float, actor: String) -> CommandResult:
	if not active():
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	var at := step_name(current())
	off = true
	_shown = Step.DONE
	_event_log.record(EventLog.GUIDE_SKIPPED, now, PackedStringArray([actor]), {"step": at})
	seen_events = _event_log.size()
	return CommandResult.success()


## No lesson for this game, and nothing to log about it.
func finish() -> void:
	off = true
	_shown = Step.DONE
	seen_events = _event_log.size()


func to_dict() -> Dictionary:
	return {"done": done.duplicate(), "seen_events": seen_events, "off": off}


func load_dict(data: Dictionary) -> void:
	done.clear()
	for name: Variant in data.get("done", []) as Array:
		done.append(String(name))
	off = bool(data.get("off", true))
	seen_events = clampi(int(data.get("seen_events", _event_log.size())), 0, _event_log.size())
	_shown = current()
