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
	if sim.suspicion.inspection_pending():
		found.append(InspectionTalk.task(sim))
	if sim.rent.visit_promised():
		found.append(SEPARATOR.join(["Лорд ждёт в поместье", UiText.money(sim.rent.owed()), RentTalk.deadline(sim)]))
	var story := sim.stories.pending()
	if story != null and sim.stories.call_waiting():
		found.append(SEPARATOR.join(["Звонит: %s" % story.caller, "ответить"]))
	elif story != null and story.waits_for_jack():
		found.append(SEPARATOR.join([story_task(story), UiText.due_by(sim.stories.next_event_time(), sim)]))
	for order: Order in sim.orders.with_status(Order.Status.ACCEPTED):
		found.append(SEPARATOR.join(["Заказ #%d: отправить" % order.id, UiText.due_by(order.deadline, sim)]))
	if found.size() > MAX_LINES:
		var more := found.size() - MAX_LINES
		found = found.slice(0, MAX_LINES)
		found.append("…и ещё %d — в телефоне и на компьютере" % more)
	return found


static func story_task(story: StoryDef) -> String:
	if not story.call_task.is_empty():
		return story.call_task
	return "Лорд зовёт в поместье" if story.place == StoryDef.MANOR else "Ждут у вас дома"


static func text(sim: SimState) -> String:
	return "\n".join(lines(sim))
