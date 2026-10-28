class_name DayStickers
extends RefCounted

## The key facts of a day as paper stickers for the summary: a new clue, someone quit, a raid, the rent,
## how a story ended. Two to five of them, most important first.

const MIN_NOTES: int = 2
const MAX_NOTES: int = 5
const PAPER: Color = Color("EDEBE6")  # white
const PAPER_WARM: Color = Color("D2BE84")  # wheat
const PAPER_PLAIN: Color = Color("D8CFBE")  # plaster
const INK_ALERT: Color = Color("B83A32")  # alert_red
const INK_STORY: Color = Color("2C3446")  # navy_suit
const INK_MONEY: Color = Color("6E8F5E")  # money_green


class Note:
	var heading: String = ""
	var text: String = ""
	var paper: Color = PAPER
	var ink: Color = INK_STORY
	var rank: int = 9
	var at: float = 0.0

	static func make(heading_text: String, body: String, rank_value: int, paper_colour: Color, ink_colour: Color) -> Note:
		var note := Note.new()
		note.heading = heading_text
		note.text = body
		note.rank = rank_value
		note.paper = paper_colour
		note.ink = ink_colour
		return note


static func notes(sim: SimState, from: float, to: float) -> Array[Note]:
	var found: Array[Note] = []
	var clues := 0
	for event: SimEvent in sim.event_log.entries():
		if event.game_time < from or event.game_time >= to:
			continue
		if event.type == EventLog.INTRIGUE_CLUE:
			clues += 1
			continue
		var note := _note(event, sim)
		if note == null or found.any(func(other: Note) -> bool: return other.text == note.text):
			continue
		note.at = event.game_time
		found.append(note)
	if clues > 0:
		var text := "Новая улика на доске в кабинете." if clues == 1 else "Новых улик на доске в кабинете: %d." % clues
		found.append(Note.make("Улика", text, 1, PAPER, INK_ALERT))
	found.sort_custom(func(a: Note, b: Note) -> bool: return a.rank < b.rank or (a.rank == b.rank and a.at < b.at))
	found = found.slice(0, MAX_NOTES)
	if found.size() < MIN_NOTES:
		found.append(Note.make("Касса", "На руках %s." % UiText.money(sim.economy.money), 8, PAPER_PLAIN, INK_MONEY))
	if found.size() < MIN_NOTES:
		found.append(Note.make("Тихо", "Ни налётов, ни звонков из поместья. В деревне о нас не говорили.", 9, PAPER_PLAIN, INK_STORY))
	return found


static func _note(event: SimEvent, sim: SimState) -> Note:
	var data := event.data
	match event.type:
		EventLog.INTRIGUE_RESOLVED:
			return Note.make("Дело о крысе", _intrigue_ending(String(data.get("outcome", ""))), 0, PAPER, INK_ALERT)
		EventLog.RAID_RESOLVED:
			return Note.make("Налёт", DayReport.situation(event, sim), 0, PAPER, INK_ALERT)
		EventLog.RENT_EVICTED:
			return Note.make("Аренда", "Лорд расторг аренду. Ферма потеряна.", 0, PAPER, INK_ALERT)
		EventLog.RENT_MISSED:
			return Note.make("Аренда", "Платёж лорду пропущен: %d из %d." % [int(data.get("missed", 0)), int(data.get("evict_after", 0))], 1, PAPER, INK_ALERT)
		EventLog.HAUL_STOPPED:
			return Note.make("Полиция", "Лендровер с ящиками остановили: потеряно %s." % DayText.crates(int(data.get("units", 0))), 1, PAPER, INK_ALERT)
		EventLog.STORY_RESOLVED:
			return _story_note(event, sim)
		EventLog.STORY_EXPIRED:
			return Note.make("Поместье", "Лорд так и не дождался вас: «%s»." % StoryTree.title(String(data.get("story_id", "")), null), 3, PAPER_WARM, INK_STORY)
		EventLog.WORKER_QUIT:
			return Note.make("Ушёл", "%s ушёл: денег на зарплату не было." % _person(String(data.get("worker_id", "")), sim), 2, PAPER, INK_ALERT)
		EventLog.COURIER_QUIT:
			return Note.make("Ушёл", "%s больше не возит заказы." % UiText.courier_name(String(data.get("courier_id", "")), sim), 2, PAPER, INK_ALERT)
		EventLog.INSPECTION_FAILED:
			return Note.make("Проверка", "Нашли, к чему придраться: штраф %s." % UiText.money(int(data.get("fine", 0))), 2, PAPER, INK_ALERT)
		EventLog.INSPECTION_PASSED:
			return Note.make("Проверка", "Проверка ушла ни с чем.", 3, PAPER_PLAIN, INK_STORY)
		EventLog.RENT_PAID:
			return Note.make("Аренда", "Лорду уплачено %s." % UiText.money(int(data.get("amount", 0))), 4, PAPER_PLAIN, INK_MONEY)
		EventLog.MILESTONE_REACHED:
			return Note.make("Империя", String(data.get("title", "")), 4, PAPER_WARM, INK_MONEY)
		EventLog.POWER_CUT:
			return Note.make("Свет", "Электричество отключили за неуплату.", 3, PAPER, INK_ALERT)
		EventLog.WORKER_HIRED:
			return Note.make("Новый человек", "В команде: %s." % _person(String(data.get("worker_id", "")), sim), 5, PAPER_PLAIN, INK_STORY)
		EventLog.COURIER_HIRED:
			return Note.make("Новый человек", "Новый курьер: %s." % UiText.courier_name(String(data.get("courier_id", "")), sim), 5, PAPER_PLAIN, INK_STORY)
	return null


static func _story_note(event: SimEvent, sim: SimState) -> Note:
	var story_id := String(event.data.get("story_id", ""))
	var story := StoryTree.find_story(sim, story_id)
	var choice := int(event.data.get("choice", -1))
	if story == null or choice < 0 or choice >= story.choices.size():
		return null
	var text := "Выбор: «%s»" % story.choices[choice].label
	if story.choices[choice].chance < 1.0:
		text += " — вышло." if event.data.get("worked", true) == true else " — не вышло."
	return Note.make(StoryTree.title(story_id, story), text, 2, PAPER_WARM, INK_STORY)


static func _intrigue_ending(outcome: String) -> String:
	match outcome:
		Intrigue.CAUGHT:
			return "Крыса поймана. Налёты на время стихнут."
		Intrigue.WRONG:
			return "Обвинили не того. Настоящая крыса на свободе."
		Intrigue.RETALIATED:
			return "Реджи нанёс «Зубам» визит. Пока тихо."
		Intrigue.RETALIATION_FAILED:
			return "Визит к «Зубам» не удался. Ждите ответа."
	return "Дело закрыто."


static func _person(worker_id: String, sim: SimState) -> String:
	var person := sim.config.find_worker(worker_id)
	if person == null:
		person = sim.config.find_packer(worker_id)
	return person.display_name if person != null else worker_id
