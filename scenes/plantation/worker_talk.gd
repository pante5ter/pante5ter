class_name WorkerTalk
extends Interactable

const ASK_WHAT_NEXT: String = "Что делать?"


func _view() -> WorkerView:
	return get_parent() as WorkerView


func hover_text() -> String:
	return "%s — поговорить" % _view().person().display_name


func interact(level: Level) -> void:
	var view := _view()
	var person := view.person()
	if view.role == WorkerDef.HELPER:
		var title := "%s\nНаучить новому и посмотреть, что он умеет, — в телефоне, «Люди»." % PeopleText.helper_status(Game.sim)
		var actions: Array[UiAction] = [
			UiAction.make(ASK_WHAT_NEXT, _advise.bind(level)),
			UiAction.make("Открыть «Люди»", _open_people.bind(level)),
		]
		level.hud.show_actions(title, actions)
		return
	var status := view.status_text()
	var title := "%s\nЗарплата %s в день" % [status, UiText.money(person.daily_wage)]
	var fire_actions: Array[UiAction] = [UiAction.make("Уволить", _fire.bind(level, person))]
	level.hud.show_actions(title, fire_actions)


func _advise(level: Level) -> void:
	level.hud.close_actions()
	var line := DialogueLineDef.make(UiText.REGGIE, AdviceText.text(Game.sim, level.hud.underground))
	level.hud.play_dialogue([line] as Array[DialogueLineDef])


func _open_people(level: Level) -> void:
	level.hud.close_actions()
	level.hud.phone.open(Phone.APP_PEOPLE)


func _fire(level: Level, person: WorkerDef) -> void:
	var result := Game.sim.apply(FireWorkerCommand.new(person.id))
	level.show_message("%s %s." % [person.display_name, PeopleText.fired_word(person)] if result.ok else UiText.error(result.error))
