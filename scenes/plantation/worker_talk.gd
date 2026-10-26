class_name WorkerTalk
extends Interactable


func _view() -> WorkerView:
	return get_parent() as WorkerView


func hover_text() -> String:
	if _view().role == WorkerDef.HELPER:
		return "%s — спросить, что делать" % _view().person().display_name
	return "%s — поговорить" % _view().person().display_name


func interact(level: Level) -> void:
	var view := _view()
	var person := view.person()
	if view.role == WorkerDef.HELPER:
		_ask_reggie(level)
		return
	var status := view.status_text()
	var title := "%s\nЗарплата %s в день" % [status, UiText.money(person.daily_wage)]
	var fire_actions: Array[UiAction] = [UiAction.make("Уволить", _fire.bind(level, person))]
	level.hud.show_actions(title, fire_actions)


func _ask_reggie(level: Level) -> void:
	var sim := Game.sim
	var advice := Advice.line(sim, _is_underground(level))
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(UiText.REGGIE, "Спрашиваете, что делать, мистер Кэллоуэй?"),
		DialogueLineDef.make(UiText.REGGIE, advice),
	]
	var hello: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, PeopleText.helper_status(sim))]
	var actions: Array[UiAction] = [
		UiAction.make("Что делать?", _play_advice.bind(level, lines)),
		UiAction.make("Открыть «Люди»", _open_people.bind(level)),
		UiAction.make("Просто поздороваться", _play_advice.bind(level, hello)),
	]
	level.hud.show_actions("%s\nВсегда можно спросить, что делать." % person_line(sim), actions)


func person_line(sim: SimState) -> String:
	return PeopleText.helper_status(sim)


func _play_advice(level: Level, lines: Array[DialogueLineDef]) -> void:
	level.hud.close_actions()
	level.hud.play_dialogue(lines)


func _is_underground(level: Level) -> bool:
	return String(level.scene_file_path).contains("plantation")


func _open_people(level: Level) -> void:
	level.hud.close_actions()
	level.hud.phone.open(Phone.APP_PEOPLE)


func _fire(level: Level, person: WorkerDef) -> void:
	var result := Game.sim.apply(FireWorkerCommand.new(person.id))
	level.show_message("%s %s." % [person.display_name, PeopleText.fired_word(person)] if result.ok else UiText.error(result.error))
