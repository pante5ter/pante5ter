class_name PeopleText
extends RefCounted


## «нанят» / «нанята»: Russian past forms agree with the person's gender.
static func hired_word(person: WorkerDef) -> String:
	return "нанят" if person.male else "нанята"


static func fired_word(person: WorkerDef) -> String:
	return "уволен" if person.male else "уволена"


static func left_word(person: WorkerDef) -> String:
	return "ушёл" if person.male else "ушла"


static func helper_status(sim: SimState) -> String:
	var helper := sim.helper
	if not helper.exists():
		return ""
	var name := helper.definition().display_name
	var left := UiText.real_duration(helper.away_until - sim.clock.elapsed_game_seconds, sim)
	match helper.away_reason:
		Helper.AWAY_DELIVERY:
			for order: Order in sim.orders.with_status(Order.Status.IN_TRANSIT):
				if order.courier_id == Helper.ACTOR:
					return "%s везёт заказ #%d — вернётся через %s" % [name, order.id, left]
			return "%s возвращается с доставки — будет через %s" % [name, left]
		Helper.AWAY_HAUL:
			if sim.stash.on_the_road() and sim.stash.driver == Helper.ACTOR:
				return "%s везёт ящики в тайник — вернётся через %s" % [name, left]
			if sim.packing.busy():
				return "%s фасует ящики в тайнике — вернётся через %s" % [name, left]
			return "%s возвращается из тайника — будет через %s" % [name, left]
		Helper.AWAY_TRAINING:
			var skill := sim.config.find_skill(helper.training_skill_id)
			return "%s на курсах «%s» — вернётся через %s" % [name, skill.display_name if skill != null else "?", left]
	if helper.task == Workers.Task.NONE:
		return "%s: на подхвате" % name
	if helper.task_plot_id < 0:
		return "%s: %s" % [name, UiText.TASK_VERBS.get(helper.task, "работает")]
	return "%s: %s, грядка %d" % [name, UiText.TASK_VERBS.get(helper.task, "работает"), UiText.plot_number(helper.task_plot_id)]


## Where gardeners are hired, while there are none: playtesters kept asking.
static func hire_hint(sim: SimState) -> String:
	if not sim.workers.gardeners().is_empty() or sim.workers.capacity() <= 0:
		return ""
	return "Садовников нет — нанять: телефон (Tab) → «Люди»"


static func packer_status(sim: SimState) -> String:
	var packer := sim.packer
	if not packer.hired:
		return "Фасовщика нет"
	var name := packer.definition().display_name
	return ("%s: фасует урожай" % name) if packer.working else ("%s: ждёт урожая" % name)


static func person_traits(person: WorkerDef) -> String:
	var speed := "быстро" if person.competence >= 1.2 else ("не спеша" if person.competence < 0.95 else "в обычном темпе")
	var honesty := "честный" if person.steal_chance() < 0.05 else ("может приворовывать" if person.steal_chance() < 0.25 else "глаза бегают")
	var tongue := "молчун" if person.talkativeness < 3.0 else ("болтает в пабе" if person.talkativeness >= 6.0 else "иногда болтает")
	return "Работает %s · %s · %s" % [speed, honesty, tongue]
