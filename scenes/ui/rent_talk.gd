class_name RentTalk
extends RefCounted

## The lord's rent call and the rent talk at the manor: lines, choices and replies.

## Which rent talk is on screen.
const CALL: String = "call"
const MANOR: String = "manor"
const PAY_INDEX: int = 0


## «до 00:00, день 3»: the rent period is long, so the deadline always says which day.
static func deadline(sim: SimState) -> String:
	return UiText.game_when(sim.rent.next_due_at, sim, true)


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
		DialogueLineDef.make(UiText.LORD, "Мистер Кэллоуэй, простите за беспокойство. Аренда — %s, срок %s. Банк, знаете ли, считает дни внимательнее меня." % [owed, deadline(sim)]),
	]
	if sim.rent.credit > 0:
		lines.append(DialogueLineDef.make(UiText.REGGIE, "Это уже за вычетом нашей предоплаты. Лорд помнит, кто его выручил."))
	if sim.rent.can_pay() == CommandResult.NOT_ENOUGH_MONEY:
		lines.append(DialogueLineDef.make(UiText.REGGIE, "В кассе %s. Перевести не выйдет — пообещайте заехать и успейте продать товар." % UiText.money(sim.economy.money)))
	return lines


static func call_choices(sim: SimState) -> PackedStringArray:
	return PackedStringArray([_pay_label("Перевести сейчас", sim), "Заеду в поместье %s" % deadline(sim)])


static func manor_lines(sim: SimState) -> Array[DialogueLineDef]:
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(UiText.LORD, "А, мистер Кэллоуэй! Раз приехали вы, надеюсь, приехала и аренда — %s." % UiText.money(sim.rent.owed())),
	]
	if sim.rent.can_pay() == CommandResult.NOT_ENOUGH_MONEY:
		lines.append(DialogueLineDef.make(UiText.REGGIE, "В кассе %s, Джек. Лорд ждёт %s — успеем продать товар и вернуться." % [UiText.money(sim.economy.money), deadline(sim)]))
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
			DialogueLineDef.make(UiText.REGGIE, "Поместье — у поля. Срок %s, Джек. Лорды ждут ровно до назначенного часа. Обижаются дольше." % deadline(sim)),
		]
	return [DialogueLineDef.make(UiText.LORD, "Разумеется. Срок прежний — %s. Часы в этом доме, в отличие от крыши, ещё исправны." % deadline(sim))]


## Reggie's reminder while Jack owes the lord a visit; empty when he does not.
static func task(sim: SimState, underground: bool) -> String:
	if not sim.rent.visit_promised():
		return ""
	if underground:
		return "Лорд ждёт аренду в поместье — %s, %s. Поднимитесь наверх и подойдите к нему." % [UiText.money(sim.rent.owed()), deadline(sim)]
	return "Лорд ждёт аренду в поместье — %s, %s. Подойдите к нему, иначе платёж сочтут пропущенным." % [UiText.money(sim.rent.owed()), deadline(sim)]


static func announcement(event: SimEvent, sim: SimState) -> String:
	match event.type:
		EventLog.RENT_CALLED:
			return "Звонил лорд Эшкомб: аренда %s." % UiText.money(int(event.data["amount"]))
		EventLog.RENT_VISIT_PROMISED:
			return "Джек обещал лорду привезти аренду в поместье %s." % deadline(sim)
	return ""


static func missed_visit(event: SimEvent) -> String:
	return "Лорд Эшкомб прождал вас в поместье до назначенного часа. Аренда не приехала, херес выдохся. Пропущено %d из %d." % [int(event.data["missed"]), int(event.data["evict_after"])]
