class_name ClueBoardText
extends RefCounted

## The cork board in the bunker: every clue Reggie has pinned up, by whom it concerns.

const RAID_CASE: String = "Налёт: что известно"
const NEW_MARK: String = "НОВОЕ"
const NEW_COLOR: Color = Color(1.0, 0.62, 0.5)


static func announcement(event: SimEvent, sim: SimState) -> String:
	return "Реджи приколол на доску в бункере улику %d из %d: %s" % [int(event.data["number"]), int(event.data["of"]), sim.intrigue.clue_text(String(event.data["clue"]))]


static func when(game_time: float) -> String:
	var day := floori(game_time / SimClock.GAME_SECONDS_PER_DAY)
	var hour := fmod(game_time, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR
	var whole_hour := floori(hour)
	return "день %d, %02d:%02d" % [day + 1, whole_hour, floori((hour - float(whole_hour)) * 60.0)]


static func case_title(sim: SimState, suspect_id: String) -> String:
	if suspect_id.is_empty():
		return RAID_CASE
	var person := sim.intrigue.definition().suspect(suspect_id)
	return person.accuse_label if person != null else suspect_id


static func found_line(clue: IntrigueClue) -> String:
	var place := clue.place if not clue.place.is_empty() else "со слов Реджи"
	return "Где: %s · Когда: %s" % [place, when(clue.found_at)]


static func status(sim: SimState, pinned: int) -> String:
	var intrigue := sim.intrigue
	match intrigue.phase:
		Intrigue.Phase.WAITING, Intrigue.Phase.OPENING:
			return "Доска пуста. Пока нас никто не сдавал — или мы об этом не знаем."
		Intrigue.Phase.INVESTIGATING:
			if pinned == 0:
				return "Реджи наводит справки. Первая улика скоро будет на доске."
			return "Улик на доске: %d из %d. Реджи приносит их сам." % [pinned, intrigue.schedule.size()]
		Intrigue.Phase.ACCUSING:
			if intrigue.accuse_at > 0.0:
				return "Все улики на доске. Реджи вернётся к разговору через %s." % UiText.real_duration(intrigue.accuse_at - sim.clock.elapsed_game_seconds, sim)
			return "Все улики на доске. Пора решать, кто крыса."
	if pinned == 0:
		return "Доска пуста. Дело закрыли, не начав."
	return "Дело закрыто. Булавки остались."


## Fills the board: the status, then one card per case with its clues; the latest one is marked.
static func fill(box: VBoxContainer, sim: SimState) -> void:
	var def := sim.intrigue.definition()
	var clues := IntrigueBoard.pinned(def, sim.event_log) if def != null else ([] as Array[IntrigueClue])
	box.add_child(UiStyle.label(status(sim, clues.size()), 15, UiStyle.MUTED))
	var newest := 0
	for clue: IntrigueClue in clues:
		newest = maxi(newest, clue.number)
	for suspect_id: String in IntrigueBoard.cases(def, clues):
		box.add_child(UiStyle.label(case_title(sim, suspect_id), 17, UiStyle.ACCENT))
		for clue: IntrigueClue in clues:
			if clue.suspect_id != suspect_id:
				continue
			var fresh := clue.number == newest and sim.intrigue.phase != Intrigue.Phase.DONE
			var text := ("%s · %s" % [NEW_MARK, clue.text]) if fresh else clue.text
			box.add_child(UiStyle.label("• " + text, 15, NEW_COLOR if fresh else Color.WHITE))
			box.add_child(UiStyle.label("   " + found_line(clue), 13, UiStyle.MUTED))
