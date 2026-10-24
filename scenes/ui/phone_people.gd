class_name PhonePeople
extends RefCounted


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	Phone.clear(box)
	box.add_child(UiStyle.label("Контакты Финна. Люди проверенные — более или менее.", 13, UiStyle.MUTED))
	_add_helper(box, sim, phone)
	box.add_child(UiStyle.label("На грядки", 16, UiStyle.ACCENT))
	for person: WorkerDef in sim.config.candidates():
		_add_candidate(box, sim, phone, person, sim.workers.hired, sim.workers.definition())
	if not sim.config.packer_candidates.is_empty():
		box.add_child(UiStyle.label("На фасовку", 16, UiStyle.ACCENT))
		for person: WorkerDef in sim.config.packer_candidates:
			_add_candidate(box, sim, phone, person, sim.packer.hired, sim.packer.definition())
	box.add_child(UiStyle.label("Курьеры — на компьютере на плантации, вкладка «Курьеры».", 13, UiStyle.MUTED))


static func _add_helper(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var helper := sim.helper
	if not helper.exists():
		return
	var person := helper.definition()
	box.add_child(UiStyle.label("%s — правая рука" % person.display_name, 16, UiStyle.ACCENT))
	var wage := "Зарплата %s в день." % UiText.money(person.daily_wage)
	if helper.wage_debt > 0:
		wage += " Должны ему %s." % UiText.money(helper.wage_debt)
	box.add_child(UiStyle.label("%s\n%s\n%s" % [person.description, PeopleText.helper_status(sim), wage], 14))
	var known := PackedStringArray()
	for skill_id: String in helper.skills:
		var skill := sim.config.find_skill(skill_id)
		if skill != null:
			known.append(skill.display_name)
	box.add_child(UiStyle.label("Умеет: %s." % (", ".join(known) if not known.is_empty() else "возить заказы, лечить грядки, гасить свет перед проверкой"), 13, UiStyle.MUTED))
	for skill: SkillDef in sim.config.skills:
		if helper.skills.has(skill.id) or helper.training_skill_id == skill.id:
			continue
		var row := VBoxContainer.new()
		row.add_child(UiStyle.label("«%s»: %s" % [skill.display_name, skill.description], 13))
		var text := "Учить: %s, %s" % [UiText.money(skill.price), UiText.real_duration(skill.train_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)]
		row.add_child(UiStyle.button(text, phone.learn.bind(skill.id), helper.present() and sim.economy.money >= skill.price))
		box.add_child(row)


static func _add_candidate(box: VBoxContainer, sim: SimState, phone: Phone, person: WorkerDef, slot_taken: bool, current: WorkerDef) -> void:
	var row := VBoxContainer.new()
	var works_here := slot_taken and current != null and current.id == person.id
	var header := "%s — %s в день%s" % [person.display_name, UiText.money(person.daily_wage), " · работает у вас" if works_here else ""]
	row.add_child(UiStyle.label(header, 15, Color.WHITE if works_here else UiStyle.MUTED))
	row.add_child(UiStyle.label("%s\n%s" % [person.description, PeopleText.person_traits(person)], 13))
	if works_here:
		var status := PeopleText.packer_status(sim) if person.role == WorkerDef.PACKER else UiText.worker_status(sim.workers)
		row.add_child(UiStyle.label(status, 13, UiStyle.MUTED))
		row.add_child(UiStyle.button("Уволить", phone.fire.bind(person.id)))
	elif slot_taken:
		row.add_child(UiStyle.button("Место занято", phone.hire.bind(person.id), false))
	else:
		row.add_child(UiStyle.button("Нанять (первый день вперёд)", phone.hire.bind(person.id), sim.economy.money >= person.daily_wage))
	box.add_child(row)
