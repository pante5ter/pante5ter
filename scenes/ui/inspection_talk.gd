class_name InspectionTalk
extends RefCounted

## The warning call before an inspection: a friend at the station rings, Jack picks how to meet it.

const CALLER: String = "Знакомый из участка"
const CHOICES: Array[String] = [Suspicion.PREP_LIGHTS, Suspicion.PREP_HIDE, Suspicion.PREP_BRIBE, Suspicion.PREP_NOTHING]


static func call_lines(sim: SimState) -> Array[DialogueLineDef]:
	var when := UiText.game_when(sim.suspicion.inspection_at, sim)
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(CALLER, "Кэллоуэй? Я тебе не звонил. Проверка едет к твоему полю %s — сосед написал жалобу." % when),
		DialogueLineDef.make(UiText.REGGIE, "Вариантов немного, и у каждого своя цена. Решайте, мистер Кэллоуэй."),
	]
	return lines


static func choices(sim: SimState) -> PackedStringArray:
	var labels := PackedStringArray()
	for choice: String in CHOICES:
		labels.append(label(choice, sim))
	return labels


static func label(choice: String, sim: SimState) -> String:
	var def := sim.suspicion.definition()
	match choice:
		Suspicion.PREP_LIGHTS:
			return "Погасить свет и затаиться — рост встанет, зато проверку пройдём"
		Suspicion.PREP_HIDE:
			return "Вынести ящики в пшеницу — %d%% пройти, часть ящиков может пропасть" % _percent(sim.suspicion.pass_chance(choice))
		Suspicion.PREP_BRIBE:
			return "Заплатить проверяющему через знакомого — %s, %d%% пройти" % [UiText.money(def.bribe_price), _percent(sim.suspicion.pass_chance(choice))]
	return "Ничего не делать — %d%% пройти, иначе штраф до %s" % [_percent(sim.suspicion.pass_chance(choice)), UiText.money(def.fine)]


static func pay_flags(sim: SimState) -> Array[bool]:
	var flags: Array[bool] = []
	for choice: String in CHOICES:
		flags.append(choice != Suspicion.PREP_BRIBE or sim.economy.money >= sim.suspicion.definition().bribe_price)
	return flags


static func reply(choice: String) -> Array[DialogueLineDef]:
	var text := "Ладно. Сидим тихо и надеемся, что проверяющий торопится к обеду."
	match choice:
		Suspicion.PREP_LIGHTS:
			text = "Гашу лампы. Растения пару часов поскучают — переживут. Мы тоже."
		Suspicion.PREP_HIDE:
			text = "Выношу ящики в пшеницу. Только бы барсуки не оказались любителями."
		Suspicion.PREP_BRIBE:
			text = "Конверт ушёл. Проверяющий, говорят, очень близорукий человек — за деньги."
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, text)]
	return lines


static func task(sim: SimState) -> String:
	var suspicion := sim.suspicion
	var when := "Проверка %s" % UiText.game_when(suspicion.inspection_at, sim)
	if suspicion.awaiting_prep():
		return JackTasks.SEPARATOR.join([when, "ответить на звонок и подготовиться"])
	match suspicion.prep:
		Suspicion.PREP_LIGHTS:
			return JackTasks.SEPARATOR.join([when, "свет выключен, ждём"])
		Suspicion.PREP_HIDE:
			return JackTasks.SEPARATOR.join([when, "ящики спрятаны в пшенице"])
		Suspicion.PREP_BRIBE:
			return JackTasks.SEPARATOR.join([when, "проверяющему заплачено"])
	return JackTasks.SEPARATOR.join([when, "ничего не делаем"])


## What came of the visit, with the choice Jack made on the call.
static func outcome(event: SimEvent, sim: SimState) -> String:
	var choice := String(event.data.get("prep", ""))
	var lost := int(event.data.get("lost", 0))
	var lost_note := " Из пшеницы не вернулось ящиков: %d." % lost if lost > 0 else ""
	if event.type == EventLog.INSPECTION_PASSED:
		match choice:
			Suspicion.PREP_LIGHTS:
				return "Проверка прошла: в темноте проверяющий увидел только пыль. Свет снова горит."
			Suspicion.PREP_HIDE:
				return "Проверка прошла: полки пустые, проверяющий скучает.%s" % lost_note
			Suspicion.PREP_BRIBE:
				return "Проверка прошла: проверяющий посмотрел на часы, а не на полки."
			Suspicion.PREP_NOTHING:
				return "Проверка прошла чудом: проверяющий спешил и толком не смотрел. Повезло."
		return "Проверяющий потоптался у контейнера и уехал ни с чем. Приятный человек."
	var fine := UiText.money(int(event.data.get("fine", 0)))
	match choice:
		Suspicion.PREP_HIDE:
			return "Проверяющий нашёл следы в пшенице. Штраф %s.%s" % [fine, lost_note]
		Suspicion.PREP_BRIBE:
			return "Конверт взяли, но проверяющий всё равно придрался. Штраф %s — честные взяточники нынче редкость." % fine
		Suspicion.PREP_NOTHING:
			return "Проверяющий нашёл, к чему придраться. Штраф %s." % fine
	return "Никто не подготовился к проверке — штраф %s. Взятка — тоже статья расходов." % fine


static func _percent(chance: float) -> int:
	return roundi(chance * 100.0)
