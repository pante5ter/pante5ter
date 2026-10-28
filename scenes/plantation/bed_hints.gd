class_name BedHints
extends RefCounted

## The hover line over a bed: what each thing Jack can do to it gives, with the numbers from content.


static func hover(plot: Plot, title: String, sim: SimState) -> String:
	match plot.stage:
		Plot.Stage.EMPTY:
			var strain := sim.config.find_strain(sim.planting.choose())
			if strain == null:
				strain = sim.config.strain
			return "%s — посадить «%s»: созреет за %s" % [title, strain.display_name, _hours(strain.growth_hours(), sim)]
		Plot.Stage.READY:
			return "%s — собрать урожай: ляжет в ящики у лифта, оттуда в тайник" % title
	if not plot.problem.is_empty():
		return "%s — %s, вылечить: пока не вылечите, рост стоит" % [title, UiText.problem(plot.problem)]
	var strain := sim.grow.strain_of(plot)
	var lines := PackedStringArray(["%s — уход:" % title])
	lines.append("полить — воды на %s, сухая не растёт" % _hours(strain.water_capacity_hours, sim))
	if not plot.fertilized:
		lines.append("удобрить — +%d к качеству%s" % [sim.config.fertilizer_bonus, _more(strain.fertilizer_yield)])
	if not plot.pruned:
		var when := "" if plot.stage == Plot.Stage.BUSH else ", когда станет кустом"
		lines.append("обрезать — +%d к качеству%s%s" % [sim.config.prune_bonus, _more(strain.prune_yield), when])
	return "\n".join(lines)


static func _more(units: int) -> String:
	return " и +%d шт. урожая" % units if units > 0 else ""


static func _hours(game_hours: float, sim: SimState) -> String:
	return UiText.real_duration(game_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)
