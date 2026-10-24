class_name WorkerView
extends Walker

const RETRY_SECONDS: float = 1.0
const ARRIVE_DISTANCE: float = 0.8
const WORK_OFFSET: Vector3 = Vector3(0.7, 0.0, 0.0)
const WORKER_LAYER: int = 0b100
const FRESH_HIRE_HOURS: float = 1.0
const BENCH_GROUP: StringName = &"packing_bench"
## Where the helper and the packer stand when idle, relative to the farmhand's spot.
const IDLE_OFFSETS: Dictionary[String, Vector3] = {
	WorkerDef.FARMHAND: Vector3.ZERO,
	WorkerDef.HELPER: Vector3(1.2, 0.0, 0.0),
	WorkerDef.PACKER: Vector3(-1.2, 0.0, 0.0),
}

@export var plots_grid: PlotsGrid
@export var idle_spot: Marker3D
@export var arrival_spot: Marker3D
@export var talk: WorkerTalk
@export var status_label: Label3D
## The level's Worker node is the farmhand and spawns the other two at start.
@export_enum("farmhand", "helper", "packer") var role: String = WorkerDef.FARMHAND

var _target: Vector3 = Vector3.INF
var _retry_left: float = 0.0
var _was_present: bool = false
var _seen_absent: bool = false


func _ready() -> void:
	if role != WorkerDef.FARMHAND or scene_file_path.is_empty():
		return
	var scene := load(scene_file_path) as PackedScene
	for extra_role: String in [WorkerDef.HELPER, WorkerDef.PACKER]:
		var extra := scene.instantiate() as WorkerView
		extra.role = extra_role
		extra.name = extra_role.capitalize()
		extra.plots_grid = plots_grid
		extra.idle_spot = idle_spot
		extra.arrival_spot = arrival_spot
		get_parent().add_child.call_deferred(extra)


func _process(delta: float) -> void:
	var present := _present()
	visible = present
	talk.collision_layer = WORKER_LAYER if present else 0
	if not present:
		_was_present = false
		_seen_absent = true
		stop()
		return
	if not _was_present:
		_was_present = true
		global_position = arrival_spot.global_position if _seen_absent or _hired_recently() else _desired_target()
		_target = Vector3.INF
	var target := _desired_target()
	var far := global_position.distance_to(target) > ARRIVE_DISTANCE
	_retry_left -= delta
	if not target.is_equal_approx(_target) or (far and not is_moving() and _retry_left <= 0.0):
		_target = target
		_retry_left = RETRY_SECONDS
		move_to(target)
	status_label.text = _status()
	if _task() != Workers.Task.NONE and not far and not is_moving():
		_face(_work_point())
		model.play_work()
	elif not is_moving():
		model.play_idle()


func person() -> WorkerDef:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.definition()
		WorkerDef.PACKER:
			return Game.sim.packer.definition()
	return Game.sim.workers.definition()


func _present() -> bool:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.present()
		WorkerDef.PACKER:
			return Game.sim.packer.hired
	return Game.sim.workers.hired


func _task() -> Workers.Task:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.task
		WorkerDef.PACKER:
			return Workers.Task.PACK if Game.sim.packer.working else Workers.Task.NONE
	return Game.sim.workers.task


func _task_plot_id() -> int:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.task_plot_id
		WorkerDef.PACKER:
			return -1
	return Game.sim.workers.task_plot_id


func _status() -> String:
	match role:
		WorkerDef.HELPER:
			return PeopleText.helper_status(Game.sim)
		WorkerDef.PACKER:
			return PeopleText.packer_status(Game.sim)
	return UiText.worker_status(Game.sim.workers)


func _bench() -> PackingBench:
	return get_tree().get_first_node_in_group(BENCH_GROUP) as PackingBench


func _idle_point() -> Vector3:
	return idle_spot.global_position + IDLE_OFFSETS.get(role, Vector3.ZERO)


func _desired_target() -> Vector3:
	var task := _task()
	if task == Workers.Task.NONE:
		return _idle_point()
	if task == Workers.Task.PACK:
		var bench := _bench()
		return bench.approach_position() if bench != null else _idle_point()
	var view := plots_grid.view_for(_task_plot_id())
	if view == null:
		return _idle_point()
	return view.approach_position() + WORK_OFFSET


func _work_point() -> Vector3:
	if _task() == Workers.Task.PACK:
		var bench := _bench()
		return bench.global_position if bench != null else global_position
	var view := plots_grid.view_for(_task_plot_id())
	return view.global_position if view != null else global_position


func _face(point: Vector3) -> void:
	var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(flat.x, flat.z)


func _hired_recently() -> bool:
	var hires := Game.sim.event_log.of_type(EventLog.WORKER_HIRED).filter(func(event: SimEvent) -> bool: return String(event.data.get("role", WorkerDef.FARMHAND)) == role)
	if hires.is_empty():
		return false
	var since := Game.sim.clock.elapsed_game_seconds - (hires[hires.size() - 1] as SimEvent).game_time
	return since < FRESH_HIRE_HOURS * SimClock.GAME_SECONDS_PER_HOUR
