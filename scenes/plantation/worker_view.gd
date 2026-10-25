class_name WorkerView
extends Walker

const RETRY_SECONDS: float = 1.0
const ARRIVE_DISTANCE: float = 0.8
const WORK_OFFSET: Vector3 = Vector3(0.7, 0.0, 0.0)
const WORKER_LAYER: int = 0b100
const FRESH_HIRE_HOURS: float = 1.0
const BENCH_GROUP: StringName = &"packing_bench"
const FOLLOW_OFFSET: Vector3 = Vector3(1.3, 0.0, 0.9)
## Jack has to walk this far before Reggie sets off after him again.
const FOLLOW_SLACK: float = 1.0
## Further than this from Jack, Reggie hurries to catch up.
const CATCH_UP_DISTANCE: float = 4.0
const CATCH_UP_SPEED: float = 2.0
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
## The bunker's Worker node is the first gardener and spawns Reggie and the rest of the crew at start;
## the packer stands at the stash.
@export_enum("farmhand", "helper", "packer") var role: String = WorkerDef.FARMHAND
## Which gardener of the crew this figure shows, in hire order.
@export var gardener_index: int = 0
## With nothing to do he keeps at Jack's side instead of waiting at the idle spot.
@export var follow_jack: bool = false
## Up top he is only seen while free: busy means busy in the bunker.
@export var only_when_free: bool = false

var _target: Vector3 = Vector3.INF
var _retry_left: float = 0.0
var _was_present: bool = false
var _seen_absent: bool = false
var _walk_speed: float = 0.0


func _ready() -> void:
	_walk_speed = speed
	if role != WorkerDef.FARMHAND or gardener_index != 0 or scene_file_path.is_empty():
		return
	var scene := load(scene_file_path) as PackedScene
	_spawn(scene, WorkerDef.HELPER, 0, "Helper")
	for index: int in range(1, Game.sim.workers.capacity()):
		_spawn(scene, WorkerDef.FARMHAND, index, "Gardener%d" % index)


func _spawn(scene: PackedScene, extra_role: String, index: int, node_name: String) -> void:
	var extra := scene.instantiate() as WorkerView
	extra.role = extra_role
	extra.gardener_index = index
	extra.follow_jack = extra_role == WorkerDef.HELPER
	extra.name = node_name
	extra.plots_grid = plots_grid
	extra.idle_spot = idle_spot
	extra.arrival_spot = arrival_spot
	get_parent().add_child.call_deferred(extra)


func _gardener() -> Gardener:
	var crew := Game.sim.workers.gardeners()
	return crew[gardener_index] if gardener_index < crew.size() else null


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
		var arrives := arrival_spot != null and (_seen_absent or _hired_recently())
		global_position = arrival_spot.global_position if arrives else _desired_target()
		_target = Vector3.INF
	var target := _desired_target()
	var far := global_position.distance_to(target) > ARRIVE_DISTANCE
	var following := _following()
	speed = _walk_speed * (CATCH_UP_SPEED if following and global_position.distance_to(target) > CATCH_UP_DISTANCE else 1.0)
	var moved := _target == Vector3.INF or (target.distance_to(_target) > FOLLOW_SLACK if following else not target.is_equal_approx(_target))
	_retry_left -= delta
	if moved or (far and not is_moving() and _retry_left <= 0.0):
		_target = target
		_retry_left = RETRY_SECONDS
		move_to(target)
	status_label.text = status_text()
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
	var gardener := _gardener()
	return gardener.definition() if gardener != null else Game.sim.workers.definition()


func _present() -> bool:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.present() and (not only_when_free or Game.sim.helper.task == Workers.Task.NONE)
		WorkerDef.PACKER:
			return Game.sim.packer.hired
	return _gardener() != null


func _following() -> bool:
	return follow_jack and _task() == Workers.Task.NONE and _jack() != null


func _jack() -> Walker:
	var node := get_parent()
	while node != null:
		var level := node as Level
		if level != null:
			return level.jack
		node = node.get_parent()
	return null


func _task() -> Workers.Task:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.task
		WorkerDef.PACKER:
			return Workers.Task.PACK if Game.sim.packer.working else Workers.Task.NONE
	var gardener := _gardener()
	return gardener.task if gardener != null else Workers.Task.NONE


func _task_plot_id() -> int:
	match role:
		WorkerDef.HELPER:
			return Game.sim.helper.task_plot_id
		WorkerDef.PACKER:
			return -1
	var gardener := _gardener()
	return gardener.task_plot_id if gardener != null else -1


func status_text() -> String:
	match role:
		WorkerDef.HELPER:
			return PeopleText.helper_status(Game.sim)
		WorkerDef.PACKER:
			return PeopleText.packer_status(Game.sim)
	var gardener := _gardener()
	return UiText.gardener_status(gardener) if gardener != null else UiText.worker_status(Game.sim.workers)


func _bench() -> PackingBench:
	return get_tree().get_first_node_in_group(BENCH_GROUP) as PackingBench


func _idle_point() -> Vector3:
	if _following():
		return _jack().global_position + FOLLOW_OFFSET
	if idle_spot == null:
		return global_position
	return idle_spot.global_position + IDLE_OFFSETS.get(role, Vector3.ZERO) + Vector3(0.0, 0.0, 1.1 * float(gardener_index))


func _desired_target() -> Vector3:
	var task := _task()
	if task == Workers.Task.NONE:
		return _idle_point()
	if task == Workers.Task.PACK:
		var bench := _bench()
		return bench.approach_position() if bench != null else _idle_point()
	var view := plots_grid.view_for(_task_plot_id()) if plots_grid != null else null
	if view == null:
		return _idle_point()
	return view.approach_position() + WORK_OFFSET


func _work_point() -> Vector3:
	if _task() == Workers.Task.PACK:
		var bench := _bench()
		return bench.global_position if bench != null else global_position
	var view := plots_grid.view_for(_task_plot_id()) if plots_grid != null else null
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
