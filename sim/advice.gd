class_name Advice
extends RefCounted

## What Reggie says when Jack asks «Что делать?»: the current first-day step, or the best next move.


static func line(sim: SimState, underground: bool = false) -> String:
	var lesson := StoryText.lesson(sim, underground)
	if not lesson.is_empty():
		return lesson
	var idle := StoryText.idle_line(sim)
	if not idle.is_empty():
		return idle
	return UiText.objective(sim, underground)


static func time_of_day(sim: SimState) -> String:
	var hour := sim.clock.hour_of_day()
	if hour >= 5.0 and hour < 11.0:
		return "утро"
	if hour >= 11.0 and hour < 17.0:
		return "день"
	if hour >= 17.0 and hour < 22.0:
		return "вечер"
	return "ночь"


## One-shot tip the first time Jack does a care action. Empty when already seen.
static func first_tip(sim: SimState, kind: String) -> String:
	if sim.tips_seen.has(kind):
		return ""
	match kind:
		"water":
			return "Полив: без воды куст не растёт. Держите грядки влажными."
		"prune":
			return "Обрезка листьев: +%d к качеству (с удобрением до +%d). Один раз за цикл." % [sim.config.prune_bonus, _care_cap(sim)]
		"fertilize":
			return "Удобрение: +%d к качеству и чуть больше урожай. Один раз за цикл." % sim.config.fertilizer_bonus
		"pack":
			return "Фасовка: клиенты берут только расфасованное. Россыпью с полки не продают."
		"plant":
			return "Посадка: клик по пустой грядке. Дальше — вода, уход и терпение."
	return ""


static func mark_tip(sim: SimState, kind: String) -> void:
	if kind.is_empty() or sim.tips_seen.has(kind):
		return
	sim.tips_seen.append(kind)


static func _care_cap(sim: SimState) -> int:
	return maxi(sim.config.fertilizer_bonus, 0) + maxi(sim.config.prune_bonus, 0)
