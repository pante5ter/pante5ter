class_name PhonePlan
extends RefCounted

## The planting plan card in the shop: how many beds each strain gets when a bed is replanted.


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var card := PhoneKit.card(box)
	PhoneKit.heading(card, "План посадок")
	card.add_child(PhoneKit.label("Сколько грядок под каждый сорт. «Авто» — лучшие семена со склада, кончатся — бесплатные.", PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	for strain: StrainDef in sim.planting.best_first():
		var beds := sim.planting.beds_for(strain.id)
		var count := "авто" if beds == PlantingPlan.AUTO else "%d %s" % [beds, UiText.plural(beds, "грядка", "грядки", "грядок")]
		card.add_child(PhoneKit.label("«%s»: %s" % [strain.display_name, count]))
		var fewer := PhoneKit.secondary("−", func() -> void: _set_beds(phone, strain, 0 if beds == PlantingPlan.AUTO else beds - 1), beds != 0)
		var more := PhoneKit.secondary("+", func() -> void: _set_beds(phone, strain, maxi(beds, 0) + 1), beds < sim.config.max_plots)
		var auto := PhoneKit.secondary("Авто", func() -> void: _set_beds(phone, strain, PlantingPlan.AUTO), beds != PlantingPlan.AUTO)
		fewer.tooltip_text = "Меньше грядок «%s»" % strain.display_name
		more.tooltip_text = more_tooltip(strain.display_name)
		var buttons: Array[Button] = [fewer, more, auto]
		PhoneKit.row(card, buttons)


static func more_tooltip(strain_name: String) -> String:
	return "Больше грядок «%s»" % strain_name


static func _set_beds(phone: Phone, strain: StrainDef, beds: int) -> void:
	var result := Game.sim.apply(SetPlantingPlanCommand.new(strain.id, beds))
	if not result.ok:
		phone.message.emit(UiText.error(result.error))
	elif beds == PlantingPlan.AUTO:
		phone.message.emit("«%s» — на усмотрение садовников: лучшие семена со склада." % strain.display_name)
	else:
		phone.message.emit("План: «%s» — %d %s. Садовники учтут при пересадке." % [strain.display_name, beds, UiText.plural(beds, "грядка", "грядки", "грядок")])
	if phone.is_inside_tree():
		phone.refresh()
