class_name StoryText
extends RefCounted

## Texts for the first-day script, the director and the choice stories.

const LESSON_STEPS: Array[FirstDay.Step] = [
	FirstDay.Step.PLANT, FirstDay.Step.CALL, FirstDay.Step.ANSWER, FirstDay.Step.HARVEST,
	FirstDay.Step.PACK, FirstDay.Step.SEND, FirstDay.Step.TROUBLE,
]


## Finn's line while the script teaches something; empty when the script has nothing to say.
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
		FirstDay.Step.PACK:
			return def.pack_line
		FirstDay.Step.SEND:
			return def.send_line
		FirstDay.Step.TROUBLE:
			var target := sim.grow.plot(first_day.trouble_plot_id)
			if target != null and not target.problem.is_empty():
				return "Грядка %d: %s" % [UiText.plot_number(target.id), def.trouble_line]
	return ""


## Finn's line for the quiet stretches of the first day, below anything the player can act on.
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
	if sim.workers.hired:
		lines.append(UiText.worker_status(sim.workers))
	if sim.packer.hired:
		lines.append(PeopleText.packer_status(sim))
	if lines.is_empty():
		return UiText.worker_status(sim.workers)
	return "\n".join(lines)


static func urgent_call(event: SimEvent) -> String:
	return "Срочный звонок: %d шт., качество %d+, %s — вдвое против обычного. Ждать клиент не будет (Tab)." % [int(event.data["quantity"]), int(event.data["min_quality"]), UiText.money(int(event.data["reward"]))]


static func announcement(event: SimEvent, sim: SimState) -> String:
	if event.type != EventLog.DIRECTOR_EVENT:
		return ""
	match String(event.data["kind"]):
		Director.RUMOUR:
			if String(event.data["about"]) == Director.ABOUT_INSPECTION:
				var hours := float(event.data["hours"]) * SimClock.GAME_SECONDS_PER_HOUR
				return "Знакомый из участка шепнул: проверка будет через %s. Свет лучше выключить заранее — или довериться %s." % [UiText.real_duration(hours, sim), _helper_dative(sim)]
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
