class_name WorkerView
extends Walker

const RETRY_SECONDS: float = 1.0
const ARRIVE_DISTANCE: float = 0.8
const WORK_OFFSET: Vector3 = Vector3(0.7, 0.0, 0.0)
const WORKER_LAYER: int = 0b100
const FRESH_HIRE_HOURS: float = 1.0

@export var plots_grid: PlotsGrid
@export var idle_spot: Marker3D
@export var arrival_spot: Marker3D
@export var talk: WorkerTalk
@export var status_label: Label3D

var _target: Vector3 = Vector3.INF
var _retry_left: float = 0.0
var _was_hired: bool = false


func _process(delta: float) -> void:
	var workers := Game.sim.workers
	visible = workers.hired
	talk.collision_layer = WORKER_LAYER if workers.hired else 0
	if not workers.hired:
		_was_hired = false
		stop()
		return
	if not _was_hired:
		_was_hired = true
		global_position = arrival_spot.global_position if _hired_recently() else _desired_target(workers)
		_target = Vector3.INF
	var target := _desired_target(workers)
	var far := global_position.distance_to(target) > ARRIVE_DISTANCE
	_retry_left -= delta
	if not target.is_equal_approx(_target) or (far and not is_moving() and _retry_left <= 0.0):
		_target = target
		_retry_left = RETRY_SECONDS
		move_to(target)
	status_label.text = UiText.worker_status(workers)
	if workers.task != Workers.Task.NONE and not far and not is_moving():
		_face(plots_grid.view_for(workers.task_plot_id).global_position)
		model.play_work()
	elif not is_moving():
		model.play_idle()


func _desired_target(workers: Workers) -> Vector3:
	if workers.task == Workers.Task.NONE:
		return idle_spot.global_position
	var view := plots_grid.view_for(workers.task_plot_id)
	if view == null:
		return idle_spot.global_position
	return view.approach_position() + WORK_OFFSET


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(flat.x, flat.z)


func _hired_recently() -> bool:
	var hires := Game.sim.event_log.of_type(EventLog.WORKER_HIRED)
	if hires.is_empty():
		return false
	var since := Game.sim.clock.elapsed_game_seconds - hires[hires.size() - 1].game_time
	return since < FRESH_HIRE_HOURS * SimClock.GAME_SECONDS_PER_HOUR
