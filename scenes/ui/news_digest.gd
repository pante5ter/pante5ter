class_name NewsDigest
extends RefCounted

## Routine farm news gathered into one line every few seconds («Созрели грядки 2, 4, 5 · садовники
## собрали грядки 1, 3»), so the screen does not flicker with a line per bed. Urgent news never come here.
## The crew's watering is not news at all: it never stops.

const RIPE: String = "ripe"
const CREW_PLANTED: String = "crew_planted"
const CREW_HARVESTED: String = "crew_harvested"
const PACKED: String = "packed"
const WAGES: String = "wages"
const POWER: String = "power"
## The order the parts of the line come in.
const ORDER: Array[String] = [RIPE, CREW_HARVESTED, CREW_PLANTED, PACKED, WAGES, POWER]

## topic -> plot numbers or amounts gathered since the last flush.
var _gathered: Dictionary[String, Array] = {}


## The topic an event is routine news for; empty when it is not routine.
static func topic_of(event: SimEvent) -> String:
	match event.type:
		EventLog.PLOT_STAGE_CHANGED:
			return RIPE if String(event.data.get("stage", "")) == Plot.stage_name(Plot.Stage.READY) else ""
		EventLog.PLOT_PLANTED:
			return CREW_PLANTED if _by_crew(event) else ""
		EventLog.PLOT_HARVESTED:
			return CREW_HARVESTED if _by_crew(event) else ""
		EventLog.PACKING_DONE:
			return PACKED
		EventLog.WORKER_PAID:
			return WAGES
		EventLog.POWER_BILLED:
			return POWER
	return ""


## Takes the event when it is routine; false means it is for the screen right away.
func add(event: SimEvent) -> bool:
	var topic := topic_of(event)
	if topic.is_empty():
		return false
	var figure := 0
	match topic:
		PACKED:
			figure = int(event.data.get("units", 0))
		WAGES:
			figure = int(event.data.get("wage", 0))
		POWER:
			figure = int(event.data.get("amount", 0))
		_:
			figure = UiText.plot_number(int(event.data.get("plot_id", 0)))
	var list: Array = _gathered.get(topic, [])
	if not (_is_plot_topic(topic) and list.has(figure)):
		list.append(figure)
	_gathered[topic] = list
	return true


func is_empty() -> bool:
	return _gathered.is_empty()


## The gathered news as one line, and a clean slate.
func flush() -> String:
	var parts := PackedStringArray()
	for topic: String in ORDER:
		if _gathered.has(topic):
			parts.append(_part(topic, _gathered[topic]))
	_gathered.clear()
	return UiText.capitalized(" · ".join(parts)) if not parts.is_empty() else ""


func clear() -> void:
	_gathered.clear()


static func _part(topic: String, figures: Array) -> String:
	var numbers := PackedStringArray()
	var total := 0
	for figure: Variant in figures:
		numbers.append(str(figure))
		total += int(figure)
	var many := figures.size() > 1
	match topic:
		RIPE:
			return ("созрели грядки %s" if many else "созрела грядка %s") % ", ".join(numbers)
		CREW_PLANTED:
			return "садовники посадили %s" % _beds(numbers)
		CREW_HARVESTED:
			return "садовники собрали %s" % _beds(numbers)
		PACKED:
			return "расфасовано %d шт. — на полке в тайнике" % total
		WAGES:
			return "зарплаты: %s" % UiText.money(total)
		POWER:
			return "электричество: %s" % UiText.money(total)
	return ""


static func _beds(numbers: PackedStringArray) -> String:
	return ("грядки %s" if numbers.size() > 1 else "грядку %s") % ", ".join(numbers)


static func _is_plot_topic(topic: String) -> bool:
	return topic == RIPE or topic == CREW_PLANTED or topic == CREW_HARVESTED


## Done by a gardener or Reggie rather than by Jack.
static func _by_crew(event: SimEvent) -> bool:
	for actor: String in event.actors:
		if actor != SimCommand.PLAYER_ACTOR and not actor.begins_with("plot:"):
			return true
	return false
