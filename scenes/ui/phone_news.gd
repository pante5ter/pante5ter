class_name PhoneNews
extends RefCounted

## The «Реджи» app: what to do next and the farm news, newest first. Counts what was not read yet.

const SHOWN: int = 15

var unread: int = 0

var _sim: SimState
var _scanned: int = 0


func scan(sim: SimState) -> void:
	if sim != _sim:
		_sim = sim
		_scanned = sim.event_log.size()
		unread = 0
		return
	for event: SimEvent in sim.event_log.since(_scanned):
		if not UiText.announcement(event, sim).is_empty():
			unread += 1
	_scanned = sim.event_log.size()


func mark_read() -> void:
	unread = 0


func fill(box: VBoxContainer, sim: SimState, underground: bool) -> void:
	var reggie := PhoneKit.card(box, PhoneKit.GOLD)
	PhoneKit.heading(reggie, UiText.REGGIE, "", PhoneKit.GOLD)
	reggie.add_child(PhoneKit.label(UiText.objective(sim, underground)))
	var hunt := StoryText.rat_hunt(sim)
	if not hunt.is_empty():
		var clues := PhoneKit.card(box, PhoneKit.DANGER)
		clues.add_child(PhoneKit.label(hunt))
	box.add_child(PhoneKit.label("Новости", PhoneKit.TITLE_SIZE, PhoneKit.MUTED))
	var shown := 0
	var events := sim.event_log.entries()
	for index: int in range(events.size() - 1, -1, -1):
		var text := UiText.announcement(events[index], sim)
		if text.is_empty():
			continue
		var item := PhoneKit.card(box)
		item.add_child(PhoneKit.label(stamp(events[index].game_time), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		item.add_child(PhoneKit.label(text))
		shown += 1
		if shown >= SHOWN:
			break
	if shown == 0:
		box.add_child(PhoneKit.label("Пока тихо. Всё важное с фермы Реджи пишет сюда.", PhoneKit.BODY_SIZE, PhoneKit.MUTED))


static func time_of_day(game_seconds: float) -> String:
	var hour := fmod(game_seconds, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR
	var whole := floori(hour)
	return "%02d:%02d" % [whole, floori((hour - float(whole)) * 60.0)]


static func stamp(game_seconds: float) -> String:
	return "День %d · %s" % [floori(game_seconds / SimClock.GAME_SECONDS_PER_DAY) + 1, time_of_day(game_seconds)]
