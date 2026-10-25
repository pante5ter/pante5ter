class_name JackTasks
extends RefCounted

## What Jack has to do himself by a set hour, one line each, for the HUD under the clock.
## «Лорд ждёт в поместье · £1500 · до 00:00, день 3».

const MAX_LINES: int = 4
const SEPARATOR: String = " · "


static func lines(sim: SimState) -> PackedStringArray:
	var found := PackedStringArray()
	if sim.rent.evicted:
		return found
	if sim.raids.pending:
		found.append(SEPARATOR.join(["Гопники у контейнера", UiText.due_by(sim.raids.deadline, sim)]))
	if sim.suspicion.inspection_pending() and not sim.suspicion.quiet:
		found.append(SEPARATOR.join(["Проверка %s" % UiText.game_when(sim.suspicion.inspection_at, sim), "выключить свет"]))
	if sim.rent.visit_promised():
		found.append(SEPARATOR.join(["Лорд ждёт в поместье", UiText.money(sim.rent.owed()), RentTalk.deadline(sim)]))
	var story := sim.stories.pending()
	if story != null and story.place == StoryDef.MANOR:
		found.append(SEPARATOR.join(["Лорд зовёт в поместье", UiText.due_by(sim.stories.next_event_time(), sim)]))
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		found.append(SEPARATOR.join(["Заказ #%d: отправить" % order.id, UiText.due_by(order.deadline, sim)]))
	if found.size() > MAX_LINES:
		var more := found.size() - MAX_LINES
		found = found.slice(0, MAX_LINES)
		found.append("…и ещё %d — в телефоне и на компьютере" % more)
	return found


static func text(sim: SimState) -> String:
	return "\n".join(lines(sim))
