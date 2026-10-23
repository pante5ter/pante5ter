class_name Level
extends Node3D

const CLICK_MASK: int = 0b11
const RAY_LENGTH: float = 500.0

@export var nav_region: NavigationRegion3D
@export var jack: Walker
@export var camera_rig: IsoCameraRig
@export var hud: Hud
@export var spawn_points: Node3D
@export var default_spawn: String = "start"

var _navigation_ready: bool = false


func _ready() -> void:
	nav_region.bake_navigation_mesh(false)
	var spawn := _spawn_position(SceneRouter.take_spawn())
	jack.global_position = spawn
	camera_rig.focus(spawn)
	Game.is_running = true


func is_navigation_ready() -> bool:
	return _navigation_ready


func _refresh_navigation_ready() -> void:
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	_navigation_ready = NavigationServer3D.map_get_closest_point_owner(map, jack.global_position) == nav_region.get_rid()


func show_message(text: String) -> void:
	hud.show_message(text)


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if SceneRouter.is_busy() or not _navigation_ready:
		return
	var hit := _pick(click.position)
	if hit.is_empty():
		return
	var interactable := hit["collider"] as Interactable
	if interactable != null:
		jack.move_to(interactable.approach_position(), interactable.interact.bind(self))
	else:
		jack.move_to(hit["position"] as Vector3)
	get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not _navigation_ready:
		_refresh_navigation_ready()
	var hit := _pick(get_viewport().get_mouse_position())
	var interactable: Interactable = null
	if not hit.is_empty():
		interactable = hit["collider"] as Interactable
	hud.set_hover(interactable.hover_text() if interactable != null else "")


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
