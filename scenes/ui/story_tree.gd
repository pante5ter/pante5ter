class_name StoryTree
extends RefCounted

## The forks of Jack's story, read back from the event log: every story, rent talk and the rat hunt's
## questions as a node with the branch he took and the ones he left. Read-only; nothing here touches the sim.

## How a fork ended.
const CHOSEN: String = "chosen"
const WAITING: String = "waiting"
const MISSED: String = "missed"
const HIDDEN_LABEL: String = "???"
const RAT: String = "Крыса"
const LORD: String = "Лорд"
const VILLAGE: String = "Деревня"
const RENT: String = "Аренда"
const STORYLINES: PackedStringArray = [RAT, LORD, VILLAGE]

const TITLES: Dictionary[String, String] = {
	"courier_theft": "Курьер пропал с заказом",
	"hiker": "Турист у поля",
	"lord_advance": "Лорд просит аванс",
	"lord_dinner": "Ужин у лорда",
	"lord_night_vehicles": "Ночные машины на поле",
	"neighbour_smell": "Сосед и запах",
	"raid_clip": "Клип «Молочных зубов»",
	"reggie_cousin": "Кузен Реджи",
	"reporter": "Репортёр из газеты",
	"reporter_vans": "Репортёр и фургоны",
	"vicar_roof": "Викарий и крыша",
	"intrigue_accuse": "Кто крыса?",
}
const TITLE_CHARS: int = 38


class Branch:
	var label: String = ""
	var chosen: bool = false
	## Jack saw this option on screen; an option never shown keeps its label secret.
	var seen: bool = false
	## «Вышло» / «Не вышло» for a gamble, or what the choice led to; empty when it simply happened.
	var outcome: String = ""

	func shown_label() -> String:
		return label if seen or chosen else HIDDEN_LABEL


class Beat:
	var at: float = 0.0
	var resolved_at: float = -1.0
	var title: String = ""
	var storyline: String = ""
	var state: String = WAITING
	var branches: Array[Branch] = []

	func chosen_index() -> int:
		for index: int in branches.size():
			if branches[index].chosen:
				return index
		return -1

	func day() -> int:
		return DayEndWatch.day_number(at)


## Forks that opened or closed in [from, to], in the order they opened.
static func beats(sim: SimState, from: float, to: float) -> Array[Beat]:
	var found: Array[Beat] = []
	var log := sim.event_log.entries()
	for index: int in log.size():
		var event := log[index]
		var beat: Beat = null
		match event.type:
			EventLog.STORY_STARTED:
				beat = _story_beat(sim, log, index)
			EventLog.RENT_CALLED:
				beat = _rent_call_beat(log, index)
			EventLog.RENT_VISIT_PROMISED:
				beat = _manor_beat(log, index)
		if beat == null:
			continue
		var opened := beat.at >= from and beat.at <= to
		var closed := beat.resolved_at >= from and beat.resolved_at <= to
		if opened or closed:
			found.append(beat)
	return found


static func _story_beat(sim: SimState, log: Array[SimEvent], start: int) -> Beat:
	var story_id := String(log[start].data.get("story_id", ""))
	var story := find_story(sim, story_id)
	var beat := Beat.new()
	beat.at = log[start].game_time
	beat.title = title(story_id, story)
	beat.storyline = storyline(sim, story_id, story)
	var labels := story.choice_labels() if story != null else PackedStringArray()
	for label: String in labels:
		var branch := Branch.new()
		branch.label = label
		beat.branches.append(branch)
	for index: int in range(start + 1, log.size()):
		var event := log[index]
		if String(event.data.get("story_id", "")) != story_id:
			continue
		if event.type == EventLog.STORY_RESOLVED:
			_resolve(beat, int(event.data.get("choice", -1)), event.game_time, true)
			var picked := beat.chosen_index()
			if picked >= 0:
				beat.branches[picked].outcome = _story_outcome(story, picked, event, log, index)
			return beat
		if event.type == EventLog.STORY_EXPIRED:
			beat.state = MISSED
			beat.resolved_at = event.game_time
			return beat
		if event.type == EventLog.STORY_STARTED:
			return beat
	return beat


static func _resolve(beat: Beat, choice: int, at: float, all_seen: bool) -> void:
	beat.state = CHOSEN
	beat.resolved_at = at
	for index: int in beat.branches.size():
		beat.branches[index].seen = all_seen
		beat.branches[index].chosen = index == choice


static func _story_outcome(story: StoryDef, picked: int, event: SimEvent, log: Array[SimEvent], at_index: int) -> String:
	if story != null and story.id == Intrigue.ACCUSE_STORY_ID:
		for index: int in range(at_index + 1, log.size()):
			var after := log[index]
			if after.game_time > event.game_time:
				break
			if after.type == EventLog.INTRIGUE_RESOLVED:
				match String(after.data.get("outcome", "")):
					Intrigue.CAUGHT:
						return "Попали: крыса поймана"
					Intrigue.WRONG:
						return "Мимо: обвинили невиновного"
			if after.type == EventLog.INTRIGUE_STEP and String(after.data.get("path", "")) == Intrigue.WAITED:
				return "Реджи спросит снова"
		return ""
	if story == null or picked >= story.choices.size() or story.choices[picked].chance >= 1.0:
		return ""
	return "Вышло" if event.data.get("worked", true) == true else "Не вышло"


static func _rent_call_beat(log: Array[SimEvent], start: int) -> Beat:
	var beat := _rent_beat(log[start].game_time, "Лорд звонит: аренда %s" % UiText.money(int(log[start].data.get("amount", 0))), PackedStringArray(["Перевести сейчас", "Заехать в поместье"]))
	for index: int in range(start + 1, log.size()):
		var event := log[index]
		match event.type:
			EventLog.RENT_PAID:
				var by_phone := String(event.data.get("where", "")) == Rent.BY_PHONE
				if by_phone:
					_resolve(beat, 0, event.game_time, true)
				else:
					_unanswered(beat, event.game_time)
				return beat
			EventLog.RENT_VISIT_PROMISED:
				_resolve(beat, 1, event.game_time, true)
				return beat
			EventLog.RENT_MISSED, EventLog.RENT_CALLED:
				_unanswered(beat, event.game_time)
				return beat
	return beat


static func _manor_beat(log: Array[SimEvent], start: int) -> Beat:
	var beat := _rent_beat(log[start].game_time, "Аренда в поместье: %s" % UiText.money(int(log[start].data.get("amount", 0))), PackedStringArray(["Привезти деньги", "Не успеть к сроку"]))
	for index: int in range(start + 1, log.size()):
		var event := log[index]
		if event.type == EventLog.RENT_PAID:
			_resolve(beat, 0, event.game_time, true)
			return beat
		if event.type == EventLog.RENT_MISSED:
			_resolve(beat, 1, event.game_time, true)
			beat.branches[1].outcome = "Лорд прождал зря"
			return beat
	return beat


static func _rent_beat(at: float, heading: String, labels: PackedStringArray) -> Beat:
	var beat := Beat.new()
	beat.at = at
	beat.title = heading
	beat.storyline = RENT
	for label: String in labels:
		var branch := Branch.new()
		branch.label = label
		branch.seen = true
		beat.branches.append(branch)
	return beat


static func _unanswered(beat: Beat, at: float) -> void:
	beat.state = MISSED
	beat.resolved_at = at


## The story behind an id, including the rat hunt's question once the sim has forgotten it after a load.
static func find_story(sim: SimState, story_id: String) -> StoryDef:
	var story := sim.stories.find(story_id)
	if story == null and story_id == Intrigue.ACCUSE_STORY_ID and sim.intrigue.definition() != null:
		story = IntrigueAccusation.build(sim.intrigue)
	return story


static func title(story_id: String, story: StoryDef) -> String:
	if TITLES.has(story_id):
		return TITLES[story_id]
	if story != null:
		for line: DialogueLineDef in story.lines:
			if not line.text.is_empty():
				return line.text if line.text.length() <= TITLE_CHARS else line.text.left(TITLE_CHARS - 1).strip_edges() + "…"
	return story_id


## The rat hunt claims its stories first, then the lord's, then the rest is the village.
static func storyline(sim: SimState, story_id: String, story: StoryDef) -> String:
	if _rat_story_ids(sim).has(story_id):
		return RAT
	var first_day := sim.config.first_day
	if story != null and (story.kind == StoryDef.LORD or (first_day != null and first_day.lord_story == story)):
		return LORD
	return VILLAGE


static func _rat_story_ids(sim: SimState) -> PackedStringArray:
	var ids := PackedStringArray()
	var def := sim.config.intrigue
	if def == null:
		return ids
	if def.opening_story != null:
		ids.append(def.opening_story.id)
	for person: SuspectDef in def.suspects:
		if person.intro_story != null:
			ids.append(person.intro_story.id)
	ids.append(Intrigue.ACCUSE_STORY_ID)
	return ids


## Per storyline: how many of its stories have been told and how many there are.
static func progress(sim: SimState) -> Dictionary[String, Vector2i]:
	var totals: Dictionary[String, Vector2i] = {}
	for line: String in STORYLINES:
		totals[line] = Vector2i.ZERO
	var counted := PackedStringArray()
	for story: StoryDef in sim.stories.all():
		if not counted.has(story.id):
			counted.append(story.id)
	if sim.config.intrigue != null and not counted.has(Intrigue.ACCUSE_STORY_ID):
		counted.append(Intrigue.ACCUSE_STORY_ID)
	for story_id: String in counted:
		var line := storyline(sim, story_id, sim.stories.find(story_id))
		var told := 1 if _is_told(sim, story_id) else 0
		totals[line] = totals[line] + Vector2i(told, 1)
	return totals


static func _is_told(sim: SimState, story_id: String) -> bool:
	if story_id == Intrigue.ACCUSE_STORY_ID:
		return not sim.event_log.of_type(EventLog.INTRIGUE_RESOLVED).is_empty()
	return sim.stories.used.has(story_id) and sim.stories.pending_id != story_id


static func percent(done: Vector2i) -> int:
	return 0 if done.y <= 0 else roundi(100.0 * float(done.x) / float(done.y))


static func overall_percent(sim: SimState) -> int:
	var total := Vector2i.ZERO
	var lines := progress(sim)
	for line: String in lines:
		total += lines[line]
	return percent(total)
