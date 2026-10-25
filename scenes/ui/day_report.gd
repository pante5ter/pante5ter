class_name DayReport
extends RefCounted

## What a stretch of time cost and what happened in it, for the bedtime summary and the morning briefing:
## one line of losses, the situations that need Jack's attention, and a nod to a new clue on the wall.


class Losses:
	var seized: int = 0
	var raided: int = 0
	var orders: int = 0
	var stolen_beds: int = 0
	var eaten_beds: int = 0
	var fines: int = 0

	func parts() -> PackedStringArray:
		var found := PackedStringArray()
		if seized > 0:
			found.append("полиция забрала %s" % DayText.crates(seized))
		if raided > 0:
			found.append("гопники унесли %s" % DayText.crates(raided))
		if orders > 0:
			found.append("пропало в дороге заказов: %d" % orders)
		if stolen_beds > 0:
			found.append("украден урожай с грядок: %d" % stolen_beds)
		if eaten_beds > 0:
			found.append("вредители съели урожай грядок: %d" % eaten_beds)
		if fines > 0:
			found.append("штрафы и откупные %s" % UiText.money(fines))
		return found


static func lines(sim: SimState, from: float, to: float) -> PackedStringArray:
	var found := PackedStringArray()
	var lost := losses(sim, from, to).parts()
	if not lost.is_empty():
		found.append("Потери: %s." % "; ".join(lost))
	found.append_array(DayText.news_between(sim, from, to, DayText.SITUATIONS))
	if has_new_clue(sim, from, to):
		found.append("Новая зацепка — на стене в контейнере.")
	return found


static func losses(sim: SimState, from: float, to: float) -> Losses:
	var total := Losses.new()
	for event: SimEvent in sim.event_log.entries():
		if event.game_time < from or event.game_time > to:
			continue
		match event.type:
			EventLog.HAUL_STOPPED:
				total.seized += int(event.data.get("units", 0))
			EventLog.RAID_RESOLVED:
				total.raided += int(event.data.get("taken", 0))
				total.fines += int(event.data.get("paid", 0))
			EventLog.COURIER_STOLE, EventLog.DELIVERY_STOPPED:
				total.orders += 1
			EventLog.WORKER_STOLE:
				total.stolen_beds += 1
			EventLog.PLOT_CROP_EATEN:
				total.eaten_beds += 1
			EventLog.INSPECTION_FAILED:
				total.fines += int(event.data.get("fine", 0))
	return total


static func has_new_clue(sim: SimState, from: float, to: float) -> bool:
	for event: SimEvent in sim.event_log.entries():
		if event.game_time >= from and event.game_time <= to and DayText.CLUE_EVENTS.has(event.type):
			return true
	return false


## A situation in a word or two; what it cost is already in the losses line.
static func situation(event: SimEvent, sim: SimState) -> String:
	match event.type:
		EventLog.RAID_RESOLVED:
			return "Приходили гопники «Молочные зубы». " + _raid_ending(event)
		EventLog.INSPECTION_FAILED:
			return "Проверка нашла, к чему придраться, и выписала штраф."
	return UiText.announcement(event, sim)


static func _raid_ending(event: SimEvent) -> String:
	if int(event.data.get("taken", 0)) > 0 or int(event.data.get("paid", 0)) > 0:
		return "Ушли не с пустыми руками."
	match String(event.data.get("outcome", "")):
		"chased":
			return "Их прогнали — правда, не тихо."
		"helper_chased":
			return "Реджи выпроводил их, даже не повысив голоса."
	return "Ящиков на ферме не было, ушли ни с чем."
