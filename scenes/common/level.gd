class_name Level
extends Node3D

const CLICK_MASK: int = 0b111
const DRAG_THRESHOLD: float = 8.0
const RAY_LENGTH: float = 500.0
const PROLOGUE_PATH: String = "res://content/prologue.tres"

@export var nav_region: NavigationRegion3D
@export var jack: Walker
@export var camera_rig: IsoCameraRig
@export var hud: Hud
@export var spawn_points: Node3D
@export var default_spawn: String = "start"

## While a Land Rover carries Jack he is hidden and clicks on the world do nothing.
var jack_in_vehicle: bool = false
var _navigation_ready: bool = false
var _pressing: bool = false
var _dragging: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _hovered: Interactable = null


func _ready() -> void:
	nav_region.bake_navigation_mesh(false)
	var spawn := _spawn_position(SceneRouter.take_spawn())
	jack.global_position = spawn
	camera_rig.focus(spawn)
	hud.jack_focus_requested.connect(centre_on_jack)
	Game.is_running = true
	hud.underground = not _is_opening_level()
	if _is_opening_level() and Game.take_fresh_start():
		hud.play_dialogue((load(PROLOGUE_PATH) as DialogueDef).lines)


## A new game starts in the main scene, so only that level opens with the prologue.
func _is_opening_level() -> bool:
	return scene_file_path == str(ProjectSettings.get_setting("application/run/main_scene"))


func is_navigation_ready() -> bool:
	return _navigation_ready


func _refresh_navigation_ready() -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	_navigation_ready = NavigationServer3D.map_get_closest_point_owner(map, jack.global_position) == nav_region.get_rid()


func centre_on_jack(follow: bool = false) -> void:
	if follow:
		camera_rig.follow(jack)
	else:
		camera_rig.glide_to(jack.global_position)


func show_message(text: String) -> void:
	hud.show_message(text)


func rebake_navigation() -> void:
	nav_region.bake_navigation_mesh(false)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and _pressing:
		if not _dragging and motion.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			camera_rig.drag(motion.relative)
			get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	if button.pressed:
		_pressing = true
		_dragging = false
		_press_position = button.position
		return
	var was_click := _pressing and not _dragging
	_pressing = false
	_dragging = false
	if was_click:
		_click(button.position)


func _click(screen_position: Vector2) -> void:
	if hud.is_blocking_world():
		hud.close_actions()
		return
	if SceneRouter.is_busy() or not _navigation_ready or jack_in_vehicle:
		return
	if jack_away():
		var back := Game.sim.couriers.busy_until.get(Couriers.JACK, 0.0) as float
		show_message("Джек в дороге с заказом. Вернётся через %s." % UiText.real_duration(back - Game.sim.clock.elapsed_game_seconds, Game.sim))
		return
	var hit := _pick(screen_position)
	if hit.is_empty():
		return
	var interactable := hit["collider"] as Interactable
	if interactable != null:
		jack.move_to(interactable.approach_position(), interactable.interact.bind(self))
	else:
		jack.move_to(hit["position"] as Vector3)


func jack_away() -> bool:
	return not Game.sim.couriers.is_free(Couriers.JACK, Game.sim.clock.elapsed_game_seconds)


func _physics_process(_delta: float) -> void:
	if not _navigation_ready:
		_refresh_navigation_ready()
	jack.visible = not jack_away() and not jack_in_vehicle
	var hit := _pick(get_viewport().get_mouse_position())
	var interactable: Interactable = null
	if not hit.is_empty():
		interactable = hit["collider"] as Interactable
	if get_viewport().gui_get_hovered_control() != null:
		interactable = null
	_set_hovered(interactable)
	hud.set_hover(interactable.hover_text() if interactable != null else "")


func _set_hovered(interactable: Interactable) -> void:
	if interactable == _hovered:
		return
	if is_instance_valid(_hovered):
		_hovered.hovered = false
	_hovered = interactable
	if interactable != null:
		interactable.hovered = true


func _pick(screen_position: Vector2) -> Dictionary:
	var camera := camera_rig.camera
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, CLICK_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query)


func _spawn_position(spawn_name: String) -> Vector3:
	var marker := spawn_points.get_node_or_null(spawn_name) as Node3D
	if marker == null:
		marker = spawn_points.get_node(default_spawn) as Node3D
	return marker.global_position
