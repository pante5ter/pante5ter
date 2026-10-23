class_name WorkerView
extends Walker

const RETRY_SECONDS: float = 1.0
const ARRIVE_DISTANCE: float = 0.8
const WORK_OFFSET: Vector3 = Vector3(0.7, 0.0, 0.0)
const BOB_HEIGHT: float = 0.12
const BOB_SPEED: float = 8.0

@export var plots_grid: PlotsGrid
@export var idle_spot: Marker3D
@export var status_label: Label3D
@export var body: Node3D

var _target: Vector3 = Vector3.INF
var _retry_left: float = 0.0
var _work_phase: float = 0.0
var _was_hired: bool = false


func _process(delta: float) -> void:
	var workers := Game.sim.workers
	visible = workers.hired
	if not workers.hired:
		_was_hired = false
		stop()
		return
	if not _was_hired:
		_was_hired = true
		global_position = idle_spot.global_position
		_target = Vector3.INF
	var target := _desired_target(workers)
	var far := global_position.distance_to(target) > ARRIVE_DISTANCE
	_retry_left -= delta
	if not target.is_equal_approx(_target) or (far and not is_moving() and _retry_left <= 0.0):
		_target = target
		_retry_left = RETRY_SECONDS
		move_to(target)
	status_label.text = UiText.worker_status(workers)
	var working := workers.task != Workers.Task.NONE and not far and not is_moving()
	_work_phase = _work_phase + delta * BOB_SPEED if working else 0.0
	body.position.y = absf(sin(_work_phase)) * BOB_HEIGHT


func _desired_target(workers: Workers) -> Vector3:
	if workers.task == Workers.Task.NONE:
		return idle_spot.global_position
	var view := plots_grid.view_for(workers.task_plot_id)
	if view == null:
		return idle_spot.global_position
	return view.approach_position() + WORK_OFFSET
