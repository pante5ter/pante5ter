class_name WorkerTalk
extends Interactable


func hover_text() -> String:
	return "%s — поговорить" % Game.sim.workers.definition().display_name


func interact(level: Level) -> void:
	var worker := Game.sim.workers.definition()
	var title := "%s\nЗарплата %s в день" % [UiText.worker_status(Game.sim.workers), UiText.money(worker.daily_wage)]
	var actions: Array[UiAction] = [UiAction.make("Уволить", _fire.bind(level))]
	level.hud.show_actions(title, actions)


func _fire(level: Level) -> void:
	var result := Game.sim.apply(FireWorkerCommand.new())
	level.show_message("%s уволен." % Game.sim.workers.definition().display_name if result.ok else UiText.error(result.error))
