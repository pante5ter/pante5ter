class_name PhoneFinance
extends RefCounted

## The «Финансы» app: today's and yesterday's totals, the regular bills and every recent pound with its reason.

const SHOWN: int = 30


static func fill(box: VBoxContainer, sim: SimState) -> void:
	var now := sim.clock.elapsed_game_seconds
	var today := sim.clock.day()
	var purse := PhoneKit.card(box, PhoneKit.GOLD)
	purse.add_child(PhoneKit.label("На руках", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	purse.add_child(PhoneKit.label(UiText.money(sim.economy.money), 28, PhoneKit.GOLD))
	_day_line(purse, "Сегодня, день %d" % (today + 1), MoneyLedger.totals(sim, _day_start(today), now + 1.0))
	if today > 0:
		_day_line(purse, "Вчера", MoneyLedger.totals(sim, _day_start(today - 1), _day_start(today)))
	_add_bills(box, sim)
	box.add_child(PhoneKit.label("Последние операции", PhoneKit.TITLE_SIZE, PhoneKit.MUTED))
	var entries := MoneyLedger.entries(sim)
	var shown := 0
	for index: int in range(entries.size() - 1, -1, -1):
		_entry_row(box, entries[index])
		shown += 1
		if shown >= SHOWN:
			break
	if shown == 0:
		box.add_child(PhoneKit.label("Денег ещё никто не платил и не получал.", PhoneKit.BODY_SIZE, PhoneKit.MUTED))


static func signed(amount: int) -> String:
	return ("+" if amount >= 0 else "−") + UiText.money(absi(amount))


static func _day_start(day: int) -> float:
	return float(day) * SimClock.GAME_SECONDS_PER_DAY


static func _day_line(parent: Container, title: String, totals: Vector2i) -> void:
	var line := HBoxContainer.new()
	line.add_child(PhoneKit.label(title, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	var figure := PhoneKit.label("пришло %s · ушло %s" % [UiText.money(totals.x), UiText.money(totals.y)], PhoneKit.SMALL_SIZE, PhoneKit.TEXT)
	figure.size_flags_horizontal = Control.SIZE_SHRINK_END
	figure.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(figure)
	parent.add_child(line)


## What leaves the purse on its own: rent and the crew's daily wages.
static func _add_bills(box: VBoxContainer, sim: SimState) -> void:
	var wages := 0
	var who := PackedStringArray()
	if sim.helper.exists():
		wages += sim.helper.definition().daily_wage
		who.append(sim.helper.definition().display_name)
	if sim.workers.hired:
		wages += sim.workers.definition().daily_wage
		who.append(sim.workers.definition().display_name)
	if sim.packer.hired:
		wages += sim.packer.definition().daily_wage
		who.append(sim.packer.definition().display_name)
	var rent := sim.rent.amount() if not sim.rent.evicted else 0
	if wages == 0 and rent == 0:
		return
	var bills := PhoneKit.card(box)
	PhoneKit.heading(bills, "Регулярные расходы")
	if rent > 0:
		_pair(bills, "Аренда, срок %s" % UiText.game_when(sim.rent.next_due_at, sim, true), UiText.money(rent))
	if wages > 0:
		_pair(bills, "Зарплаты в день (%s)" % ", ".join(who), UiText.money(wages))


static func _entry_row(box: VBoxContainer, entry: MoneyLedger.Entry) -> void:
	var item := PhoneKit.card(box, PhoneKit.GOOD if entry.amount >= 0 else PhoneKit.DANGER)
	var line := HBoxContainer.new()
	line.add_child(PhoneKit.label(entry.reason, PhoneKit.BODY_SIZE))
	var figure := PhoneKit.label(signed(entry.amount), PhoneKit.BODY_SIZE, PhoneKit.GOOD.lightened(0.25) if entry.amount >= 0 else PhoneKit.DANGER.lightened(0.3))
	figure.size_flags_horizontal = Control.SIZE_SHRINK_END
	figure.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(figure)
	item.add_child(line)
	item.add_child(PhoneKit.label(PhoneNews.stamp(entry.game_time), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))


static func _pair(parent: Container, name: String, value: String) -> void:
	var line := HBoxContainer.new()
	line.add_child(PhoneKit.label(name, PhoneKit.BODY_SIZE))
	var figure := PhoneKit.label(value, PhoneKit.BODY_SIZE, PhoneKit.GOLD)
	figure.size_flags_horizontal = Control.SIZE_SHRINK_END
	figure.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(figure)
	parent.add_child(line)
