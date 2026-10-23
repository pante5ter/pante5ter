class_name WorkerCandidate
extends Interactable

@export var visual: Node3D

var _clickable_layer: int = 0


func _ready() -> void:
	_clickable_layer = collision_layer


func _process(_delta: float) -> void:
	var available := not Game.sim.workers.hired
	visual.visible = available
	collision_layer = _clickable_layer if available else 0


func hover_text() -> String:
	var worker := Game.sim.workers.definition()
	return "%s ищет работу — нанять за %s в день" % [worker.display_name, UiText.money(worker.daily_wage)]


func interact(level: Level) -> void:
	var worker := Game.sim.workers.definition()
	var result := Game.sim.apply(HireWorkerCommand.new())
	if result.ok:
		level.show_message("%s нанят за %s в день. Он уже спускается на плантацию." % [worker.display_name, UiText.money(worker.daily_wage)])
	elif result.error == CommandResult.NOT_ENOUGH_MONEY:
		level.show_message("Не хватает денег: %s просит %s вперёд." % [worker.display_name, UiText.money(worker.daily_wage)])
	else:
		level.show_message(UiText.error(result.error))
