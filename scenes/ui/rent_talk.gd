class_name RentTalk
extends RefCounted

## The lord's rent call and the rent talk at the manor: lines, choices and replies.

## Which rent talk is on screen.
const CALL: String = "call"
const MANOR: String = "manor"
const PAY_INDEX: int = 0


static func deadline(sim: SimState) -> String:
	var due := sim.rent.next_due_at
	var hour := fmod(due, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR
	if is_zero_approx(hour):
		return "полуночи"
	return "%02d:%02d" % [floori(hour), floori(fmod(hour, 1.0) * 60.0)]


static func _pay_label(verb: String, sim: SimState) -> String:
	var label := "%s %s" % [verb, UiText.money(sim.rent.owed())]
	if sim.rent.can_pay() == CommandResult.NOT_ENOUGH_MONEY:
		label += " — в кассе только %s" % UiText.money(sim.economy.money)
	return label


## Paying greys out when the money is short; the other answer is always there.
static func pay_flags(sim: SimState) -> Array[bool]:
	return [sim.rent.can_pay().is_empty(), true]


static func call_lines(sim: SimState) -> Array[DialogueLineDef]:
	var owed := UiText.money(sim.rent.owed())
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make("", "Звонит телефон. Дворецкий соединяет с лордом Эшкомбом."),
		DialogueLineDef.make(UiText.LORD, "Мистер Кэллоуэй, простите за беспокойство. Аренда — %s — к %s. Банк, знаете ли, считает дни внимательнее меня." % [owed, deadline(sim)]),
	]
	if sim.rent.credit > 0:
		lines.append(DialogueLineDef.make(UiText.REGGIE, "Это уже за вычетом нашей предоплаты. Лорд помнит, кто его выручил."))
	if sim.rent.can_pay() == CommandResult.NOT_ENOUGH_MONEY:
		lines.append(DialogueLineDef.make(UiText.REGGIE, "В кассе %s. Перевести не выйдет — пообещайте заехать и успейте продать товар." % UiText.money(sim.economy.money)))
	return lines


static func call_choices(sim: SimState) -> PackedStringArray:
	return PackedStringArray([_pay_label("Перевести сейчас", sim), "Заеду в поместье до %s" % deadline(sim)])


static func manor_lines(sim: SimState) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(UiText.LORD, "А, мистер Кэллоуэй! Раз приехали вы, надеюсь, приехала и аренда — %s." % UiText.money(sim.rent.owed())),
	]
	if sim.rent.can_pay() == CommandResult.NOT_ENOUGH_MONEY:
		lines.append(DialogueLineDef.make(UiText.REGGIE, "В кассе %s, Джек. До %s ещё можно продать товар и вернуться." % [UiText.money(sim.economy.money), deadline(sim)]))
	return lines


static func manor_choices(sim: SimState) -> PackedStringArray:
	return PackedStringArray([_pay_label("Отдать", sim), "Пока не готов — загляну позже"])


static func reply(talk: String, index: int, sim: SimState) -> Array[DialogueLineDef]:
	if index == PAY_INDEX:
		if talk == CALL:
			return [DialogueLineDef.make(UiText.LORD, "Получил. Вы образцовый арендатор, мистер Кэллоуэй. Почти подозрительно образцовый.")]
		return [DialogueLineDef.make(UiText.LORD, "Наличными! Как в старые времена, когда джентльмены доверяли банкам меньше, чем друг другу.")]
	if talk == CALL:
		return [
			DialogueLineDef.make(UiText.LORD, "Буду ждать. Херес, полагаю, вы пьёте?"),
			DialogueLineDef.make(UiText.REGGIE, "Поместье — у поля. До %s, Джек: лорды ждут ровно до назначенного часа, а обижаются потом надолго." % deadline(sim)),
		]
	return [DialogueLineDef.make(UiText.LORD, "Разумеется. Я жду до %s — часы в этом доме, в отличие от крыши, ещё исправны." % deadline(sim))]


## Reggie's reminder while Jack owes the lord a visit; empty when he does not.
static func task(sim: SimState, underground: bool) -> String:
	if not sim.rent.visit_promised():
		return ""
	var left := UiText.real_duration(sim.rent.due_in(sim.clock.elapsed_game_seconds), sim)
	if underground:
		return "Лорд ждёт аренду в поместье — %s, до %s (осталось %s). Поднимитесь наверх и подойдите к нему." % [UiText.money(sim.rent.owed()), deadline(sim), left]
	return "Лорд ждёт аренду в поместье — %s, до %s (осталось %s). Подойдите к нему, иначе платёж сочтут пропущенным." % [UiText.money(sim.rent.owed()), deadline(sim), left]


static func announcement(event: SimEvent, sim: SimState) -> String:
	match event.type:
		EventLog.RENT_CALLED:
			return "Звонил лорд Эшкомб: аренда %s." % UiText.money(int(event.data["amount"]))
		EventLog.RENT_VISIT_PROMISED:
			return "Джек обещал лорду привезти аренду в поместье до %s." % deadline(sim)
	return ""


static func missed_visit(event: SimEvent) -> String:
	return "Лорд Эшкомб прождал вас в поместье до назначенного часа. Аренда не приехала, херес выдохся. Пропущено %d из %d." % [int(event.data["missed"]), int(event.data["evict_after"])]
