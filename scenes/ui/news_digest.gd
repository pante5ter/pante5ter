class_name NewsDigest
extends RefCounted

## Routine farm news is batched so five ripe beds do not flash five banners.


static func is_routine(event: SimEvent) -> bool:
	match event.type:
		EventLog.PLOT_STAGE_CHANGED:
			return String(event.data.get("stage", "")) == Plot.stage_name(Plot.Stage.READY)
		EventLog.PLOT_WATERED, EventLog.PLOT_FERTILIZED, EventLog.PLOT_PRUNED, EventLog.PLOT_TREATED:
			return true
		EventLog.WORKER_TASK_STARTED:
			return true
	return false


## Turns a burst of routine events into one or two short lines. Other events pass through as-is.
static func compress(events: Array[SimEvent], sim: SimState) -> PackedStringArray:
	var ripe: Array[int] = []
	var cared: Array[int] = []
	var other := PackedStringArray()
	for event: SimEvent in events:
		if not is_routine(event):
			var text := UiText.announcement(event, sim)
			if not text.is_empty() and not other.has(text):
				other.append(text)
			continue
		if event.type == EventLog.WORKER_TASK_STARTED:
			continue
		var plot_id := int(event.data.get("plot_id", -1))
		if plot_id < 0:
			continue
		var number := UiText.plot_number(plot_id)
		if event.type == EventLog.PLOT_STAGE_CHANGED:
			if not ripe.has(number):
				ripe.append(number)
		elif not cared.has(number):
			cared.append(number)
	var lines := PackedStringArray()
	if not ripe.is_empty():
		ripe.sort()
		lines.append("Созрели грядки %s." % _join(ripe) if ripe.size() > 1 else "Грядка %d созрела." % ripe[0])
	if cared.size() >= 2:
		cared.sort()
		lines.append("Уход на грядках %s." % _join(cared))
	lines.append_array(other)
	return lines


static func _join(plots: Array[int]) -> String:
	var parts := PackedStringArray()
	for number: int in plots:
		parts.append(str(number))
	return ", ".join(parts)
