class_name StoryText
extends RefCounted

## Texts for the first-day script, the director and the choice stories.

const LESSON_STEPS: Array[FirstDay.Step] = [
	FirstDay.Step.PLANT, FirstDay.Step.CALL, FirstDay.Step.ANSWER, FirstDay.Step.HARVEST,
	FirstDay.Step.HAUL, FirstDay.Step.PACK, FirstDay.Step.SEND, FirstDay.Step.TROUBLE,
]


## Reggie's line while the script teaches something; empty when the script has nothing to say.
static func lesson(sim: SimState, underground: bool) -> String:
	var first_day := sim.first_day
	var def := first_day.definition()
	if def == null or not LESSON_STEPS.has(first_day.step):
		return ""
	match first_day.step:
		FirstDay.Step.PLANT:
			return def.plant_bunker_line if underground else def.plant_field_line
		FirstDay.Step.CALL:
			return def.call_line
		FirstDay.Step.ANSWER:
			return def.answer_line
		FirstDay.Step.HARVEST:
			return def.harvest_line
		FirstDay.Step.HAUL:
			if sim.stash.on_the_road():
				return ""
			if sim.inventory.farm_crates().is_empty():
				return def.harvest_line
			return def.haul_line
		FirstDay.Step.PACK:
			return def.pack_line
		FirstDay.Step.SEND:
			return def.send_line
		FirstDay.Step.TROUBLE:
			var target := sim.grow.plot(first_day.trouble_plot_id)
			if target != null and not target.problem.is_empty():
				return "Грядка %d: %s" % [UiText.plot_number(target.id), def.trouble_line]
	return ""


## Reggie's line for the quiet stretches of the first day, below anything the player can act on.
static func idle_line(sim: SimState) -> String:
	var def := sim.first_day.definition()
	if def == null:
		return ""
	match sim.first_day.step:
		FirstDay.Step.PAID:
			return def.paid_line
		FirstDay.Step.EVENING:
			return def.evening_line
		FirstDay.Step.MORNING:
			return def.morning_line
	return ""


static func crew_status(sim: SimState) -> String:
	var lines := PackedStringArray()
	if sim.helper.exists():
		lines.append(PeopleText.helper_status(sim))
	for gardener: Gardener in sim.workers.gardeners():
		lines.append(UiText.gardener_status(gardener))
	if sim.packer.hired:
		lines.append(PeopleText.packer_status(sim))
	if lines.is_empty():
		return UiText.worker_status(sim.workers)
	var hint := PeopleText.hire_hint(sim)
	if not hint.is_empty():
		lines.append(hint)
	return "\n".join(lines)


static func urgent_call(event: SimEvent, sim: SimState) -> String:
	var strain := UiText.order_strain(String(event.data.get("strain_id", "")), sim)
	return "Срочный звонок: %d шт.%s, качество %d+, %s — вдвое против обычного. Ждать клиент не будет." % [int(event.data["quantity"]), strain, int(event.data["min_quality"]), UiText.money(int(event.data["reward"]))]


static func rat_hunt(sim: SimState) -> String:
	var intrigue := sim.intrigue
	if intrigue.phase != Intrigue.Phase.INVESTIGATING:
		return ""
	return "Нас сдали «Молочным зубам». Улик собрано %d из %d — я вешаю их на доску у компьютера в бункере. Когда сложим все, решим, кто крыса." % [intrigue.clues_given, intrigue.schedule.size()]


static func summons(sim: SimState, underground: bool) -> String:
	var rent := RentTalk.task(sim, underground)
	if not rent.is_empty():
		return rent
	var story := sim.stories.pending()
	if story == null or story.place != StoryDef.MANOR:
		return ""
	if underground:
		return "Лорд Эшкомб просит заехать в поместье. Поднимитесь наверх и подойдите к нему — сюда он не спустится, и слава богу."
	return "Лорд Эшкомб ждёт вас у поместья. Подойдите к нему, пока он не обиделся."


static func announcement(event: SimEvent, sim: SimState) -> String:
	if event.type == EventLog.STORY_STARTED:
		var started := sim.stories.find(String(event.data["story_id"]))
		if started != null and started.place == StoryDef.MANOR:
			return "Звонил дворецкий: лорд Эшкомб просит вас заехать в поместье."
		return ""
	if event.type == EventLog.STORY_EXPIRED:
		return "Лорд Эшкомб так и не дождался вас в поместье. Дворецкий передал, что милорд «не настаивает». Это хуже, чем если бы настаивал."
	if event.type == EventLog.INTRIGUE_CLUE:
		return ClueBoardText.announcement(event, sim)
	if event.type != EventLog.DIRECTOR_EVENT:
		return ""
	match String(event.data["kind"]):
		Director.RUMOUR:
			if String(event.data["about"]) == Director.ABOUT_INSPECTION:
				var hours := float(event.data["hours"]) * SimClock.GAME_SECONDS_PER_HOUR
				return "Знакомый из участка шепнул: проверка будет %s. Свет лучше выключить заранее — или довериться %s." % [UiText.game_when(event.game_time + hours, sim), _helper_dative(sim)]
			return "В пабе болтают, что гопники с трассы присмотрели наш контейнер. Этой ночью товар лучше держать в дороге, а не на полке."
		Director.COURIER_TROUBLE:
			var hours := float(event.data["hours"]) * SimClock.GAME_SECONDS_PER_HOUR
			return "%s застрял: на дороге перевернулся трактор с репой. Опоздает на %s." % [UiText.courier_name(String(event.data["courier_id"]), sim), UiText.real_duration(hours, sim)]
	return ""


static func _helper_dative(sim: SimState) -> String:
	return sim.helper.definition().display_name if sim.helper.exists() else "удаче"


static func reply(choice: StoryChoiceDef, worked: bool) -> Array[DialogueLineDef]:
	return choice.reply if worked else choice.fail_reply


static func refusal(code: String, choice: StoryChoiceDef) -> String:
	if code == CommandResult.NOT_ENOUGH_MONEY:
		return "На это нужно %s, а столько в кассе нет. Выберите другое." % UiText.money(choice.cost())
	return UiText.error(code)
