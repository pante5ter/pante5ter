class_name PhonePeople
extends RefCounted

## The «Люди» app, on the phone and on the computer: the crew, the couriers and the packer.

const COURIERS_SECTION: String = "CouriersSection"


static func fill(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	box.add_child(_section("Бригада"))
	_add_helper(box, sim, phone)
	var crew := sim.workers
	box.add_child(PhoneKit.label("Садовники на грядки — %d из %d" % [crew.gardeners().size(), crew.capacity()], PhoneKit.TITLE_SIZE, PhoneKit.MUTED))
	var crew_full := crew.gardeners().size() >= crew.capacity()
	for person: WorkerDef in sim.config.candidates():
		var hired := crew.is_hired(person.id)
		_add_candidate(box, sim, phone, person, hired or crew_full, person if hired else null)
	_add_couriers(box, sim, phone)
	if not sim.config.packer_candidates.is_empty():
		box.add_child(_section("Фасовщик — в тайнике"))
		for person: WorkerDef in sim.config.packer_candidates:
			_add_candidate(box, sim, phone, person, sim.packer.hired, sim.packer.definition())


static func _section(title: String) -> Label:
	return PhoneKit.label(title.to_upper(), PhoneKit.SMALL_SIZE, PhoneKit.GOLD)


static func _add_couriers(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var heading := _section("Курьеры")
	heading.name = COURIERS_SECTION
	box.add_child(heading)
	var now := sim.clock.elapsed_game_seconds
	var intro := "Возят заказы клиентам. Риск в дороге растёт вместе с подозрением."
	if sim.helper.exists():
		intro += " %s возит бесплатно, риск %d%%, но пока он в дороге, ферма без него." % [sim.helper.definition().display_name, roundi(sim.couriers.trip_risk(Helper.ACTOR) * 100.0)]
	box.add_child(PhoneKit.label(intro, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	for courier: CourierDef in sim.config.courier_candidates:
		var hired := sim.couriers.hired.has(courier.id)
		var card := PhoneKit.card(box, Phone.APP_COLORS[Phone.APP_PEOPLE] if hired else PhoneKit.CARD)
		var status := ""
		if hired:
			status = " · в дороге" if not sim.couriers.is_free(courier.id, now) else " · свободен"
		PhoneKit.heading(card, courier.display_name + status, "%d%%" % roundi(courier.cut * 100.0))
		card.add_child(PhoneKit.label(courier.description, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		card.add_child(PhoneKit.label("Берёт %d%% с заказа, риск %d%%, скорость ×%.1f." % [roundi(courier.cut * 100.0), roundi(sim.couriers.trip_risk(courier.id) * 100.0), courier.speed], PhoneKit.SMALL_SIZE))
		if hired:
			card.add_child(PhoneKit.danger("Уволить", phone.fire_courier.bind(courier.id), sim.couriers.is_free(courier.id, now)))
		else:
			card.add_child(PhoneKit.primary("Нанять за %s" % UiText.money(courier.hire_fee), phone.hire_courier.bind(courier.id), sim.economy.money >= courier.hire_fee))


static func _add_helper(box: VBoxContainer, sim: SimState, phone: Phone) -> void:
	var helper := sim.helper
	if not helper.exists():
		return
	var person := helper.definition()
	var card := PhoneKit.card(box, PhoneKit.GOLD)
	PhoneKit.heading(card, "%s — правая рука" % person.display_name, "%s/день" % UiText.money(person.daily_wage), PhoneKit.GOLD)
	card.add_child(PhoneKit.label(PeopleText.helper_status(sim)))
	if helper.wage_debt > 0:
		card.add_child(PhoneKit.label("Должны ему %s." % UiText.money(helper.wage_debt), PhoneKit.BODY_SIZE, PhoneKit.GOLD))
	var known := PackedStringArray()
	for skill_id: String in helper.skills:
		var skill := sim.config.find_skill(skill_id)
		if skill != null:
			known.append(skill.display_name)
	card.add_child(PhoneKit.label("Умеет: %s." % (", ".join(known) if not known.is_empty() else "возить заказы, ящики и Джека, лечить грядки, гасить свет перед проверкой"), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	for skill: SkillDef in sim.config.skills:
		if helper.skills.has(skill.id) or helper.training_skill_id == skill.id:
			continue
		var course := PhoneKit.card(box)
		PhoneKit.heading(course, "Курс «%s»" % skill.display_name, UiText.money(skill.price))
		course.add_child(PhoneKit.label(skill.description, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
		var text := "Учить: %s, %s" % [UiText.money(skill.price), UiText.real_duration(skill.train_hours * SimClock.GAME_SECONDS_PER_HOUR, sim)]
		course.add_child(PhoneKit.secondary(text, phone.learn.bind(skill.id), helper.present() and sim.economy.money >= skill.price))


static func _add_candidate(box: VBoxContainer, sim: SimState, phone: Phone, person: WorkerDef, slot_taken: bool, current: WorkerDef) -> void:
	var works_here := slot_taken and current != null and current.id == person.id
	var card := PhoneKit.card(box, Phone.APP_COLORS[Phone.APP_PEOPLE] if works_here else PhoneKit.CARD)
	PhoneKit.heading(card, person.display_name + (" · у вас" if works_here else ""), "%s/день" % UiText.money(person.daily_wage), PhoneKit.TEXT if works_here or not slot_taken else PhoneKit.MUTED)
	card.add_child(PhoneKit.label(PeopleText.person_traits(person), PhoneKit.SMALL_SIZE, PhoneKit.MUTED))
	if works_here:
		var gardener := sim.workers.find(person.id)
		var status := UiText.gardener_status(gardener) if gardener != null else PeopleText.packer_status(sim)
		card.add_child(PhoneKit.label(status))
		card.add_child(PhoneKit.danger("Уволить", phone.fire.bind(person.id)))
	elif slot_taken:
		card.add_child(PhoneKit.secondary("Бригада укомплектована" if person.role == WorkerDef.FARMHAND else "Место занято", phone.hire.bind(person.id), false))
	else:
		card.add_child(PhoneKit.label(person.description, PhoneKit.SMALL_SIZE))
		card.add_child(PhoneKit.primary("Нанять (первый день вперёд)", phone.hire.bind(person.id), sim.economy.money >= person.daily_wage))
