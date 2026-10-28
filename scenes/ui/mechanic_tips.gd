class_name MechanicTips
extends RefCounted

## The first time Jack himself waters, fertilizes, prunes or packs, one line says what it gives.
## «First» is read from the event log, so a loaded game remembers what was already explained.

const TAUGHT: Array[String] = [EventLog.PLOT_WATERED, EventLog.PLOT_FERTILIZED, EventLog.PLOT_PRUNED, EventLog.PACKING_STARTED]


static func tip(event: SimEvent, sim: SimState) -> String:
	if not TAUGHT.has(event.type) or not event.actors.has(SimCommand.PLAYER_ACTOR):
		return ""
	for earlier: SimEvent in sim.event_log.of_type(event.type):
		if earlier.seq < event.seq and earlier.actors.has(SimCommand.PLAYER_ACTOR):
			return ""
	return text(event.type, sim)


static func text(event_type: String, sim: SimState) -> String:
	var strain := sim.config.strain
	match event_type:
		EventLog.PLOT_WATERED:
			return "Совет: воды хватает на %s. Сухая грядка не растёт и теряет %d качества за час." % [UiText.real_duration(strain.water_capacity_hours * SimClock.GAME_SECONDS_PER_HOUR, sim), roundi(strain.dry_penalty_per_hour)]
		EventLog.PLOT_FERTILIZED:
			var more := " и +%d шт. урожая" % strain.fertilizer_yield if strain.fertilizer_yield > 0 else ""
			return "Совет: удобрение даёт +%d к качеству%s — один раз за посадку. Качество — это цена." % [sim.config.fertilizer_bonus, more]
		EventLog.PLOT_PRUNED:
			var extra := " и +%d шт. урожая" % strain.prune_yield if strain.prune_yield > 0 else ""
			return "Совет: обрезка даёт +%d к качеству%s. Только у куста и один раз за посадку." % [sim.config.prune_bonus, extra]
		EventLog.PACKING_STARTED:
			var per_unit := UiText.real_duration(sim.config.orders.pack_minutes_per_unit * 60.0, sim)
			return "Совет: клиенты берут только коробки — россыпь не продаётся. Фасовка — %s на штуку; фасовщика можно нанять в «Людях»." % per_unit
	return ""
