class_name WorkerCandidate
extends Interactable

@export var visual: Node3D
@export var leave_target: Marker3D
@export var walker_scene: PackedScene

var _clickable_layer: int = 0


func _ready() -> void:
	_clickable_layer = collision_layer


func _process(_delta: float) -> void:
	var available := not Game.sim.workers.hired
	visual.visible = available
	collision_layer = _clickable_layer if available else 0


func hover_text() -> String:
	var worker := Game.sim.workers.definition()
	return "%s ищет работу — поговорить" % worker.display_name


func interact(level: Level) -> void:
	var worker := Game.sim.workers.definition()
	var title := "%s ищет работу.\nБудет сам сажать, поливать и собирать.\nЗарплата %s в день, первый день вперёд." % [worker.display_name, UiText.money(worker.daily_wage)]
	var actions: Array[UiAction] = [UiAction.make("Нанять за %s в день" % UiText.money(worker.daily_wage), _hire.bind(level), Game.sim.economy.money >= worker.daily_wage)]
	level.hud.show_actions(title, actions)


func _hire(level: Level) -> void:
	var worker := Game.sim.workers.definition()
	var result := Game.sim.apply(HireWorkerCommand.new())
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	level.show_message("%s нанят. Он идёт к контейнеру и спускается на плантацию." % worker.display_name)
	_walk_to_container()


func _walk_to_container() -> void:
	var walker := walker_scene.instantiate() as Walker
	get_parent().add_child(walker)
	walker.global_position = global_position
	walker.move_to(leave_target.global_position, walker.queue_free)
