class_name IsoCameraRig
extends Node3D

const GLIDE_DONE_DISTANCE: float = 0.02

@export var camera: Camera3D
@export var pitch_degrees: float = 45.0
@export var fov_degrees: float = 28.0
## Camera distance from the focus point; the wheel moves between the limits.
@export var distance: float = 36.0
@export var pan_speed: float = 14.0
@export var edge_scroll: bool = false
@export var edge_margin: float = 12.0
@export var zoom_min: float = 14.0
@export var zoom_max: float = 80.0
@export var zoom_step: float = 4.0
@export var smoothing: float = 10.0
@export var bounds: Rect2 = Rect2(-30.0, -30.0, 60.0, 60.0)
## How fast a glide to a point closes in; the camera eases out like a map recentring on you.
@export var glide_speed: float = 6.0

var _target_yaw: float = 0.0
var _target_zoom: float = 36.0
var _gliding: bool = false
var _glide_target: Vector3 = Vector3.ZERO
## While set the camera keeps Jack (or whoever) in the middle until the player pans away.
var _followed: Node3D = null


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov_degrees
	camera.near = 0.5
	camera.far = zoom_max * 4.0
	distance = clampf(distance, zoom_min, zoom_max)
	_target_yaw = rotation.y
	_target_zoom = distance
	_place_camera()


func zoom() -> float:
	return distance


func _place_camera() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _view_height() -> float:
	return 2.0 * distance * tan(deg_to_rad(fov_degrees) / 2.0)


func focus(point: Vector3) -> void:
	position = _clamped(Vector3(point.x, 0.0, point.z))


func glide_to(point: Vector3) -> void:
	_followed = null
	_glide_target = _clamped(Vector3(point.x, 0.0, point.z))
	_gliding = true


func follow(target: Node3D) -> void:
	_followed = target
	_glide_target = _clamped(Vector3(target.global_position.x, 0.0, target.global_position.z))
	_gliding = true


func is_gliding() -> bool:
	return _gliding


func is_following() -> bool:
	return _followed != null


func stop_gliding() -> void:
	_gliding = false
	_followed = null


func drag(screen_delta: Vector2) -> void:
	var world_per_pixel := _view_height() / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	var right := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
	var pitch := deg_to_rad(pitch_degrees)
	var move := -right * screen_delta.x * world_per_pixel + forward * screen_delta.y * world_per_pixel / maxf(sin(pitch), 0.1)
	stop_gliding()
	position = _clamped(position + move)


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.physical_keycode == KEY_Q:
			_target_yaw += PI / 2.0
		elif key.physical_keycode == KEY_E:
			_target_yaw -= PI / 2.0


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-smoothing * delta)
	rotation.y = lerp_angle(rotation.y, _target_yaw, weight)
	distance = lerpf(distance, _target_zoom, weight)
	_place_camera()
	var input := _pan_input()
	if input != Vector2.ZERO:
		stop_gliding()
		var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		var right := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
		var speed := pan_speed * _view_height() / 16.0
		position = _clamped(position + (right * input.x + forward * input.y) * speed * delta)
	_glide(delta)


func _glide(delta: float) -> void:
	if not _gliding:
		return
	if _followed != null:
		if not is_instance_valid(_followed):
			stop_gliding()
			return
		_glide_target = _clamped(Vector3(_followed.global_position.x, 0.0, _followed.global_position.z))
	position = position.lerp(_glide_target, 1.0 - exp(-glide_speed * delta))
	if _followed == null and position.distance_to(_glide_target) < GLIDE_DONE_DISTANCE:
		position = _glide_target
		_gliding = false


func _pan_input() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if edge_scroll and DisplayServer.window_is_focused():
		input += _edge_input()
	return input.limit_length(1.0)


func _edge_input() -> Vector2:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	if not Rect2(Vector2.ZERO, size).has_point(mouse):
		return Vector2.ZERO
	var input := Vector2.ZERO
	if mouse.x < edge_margin:
		input.x -= 1.0
	elif mouse.x > size.x - edge_margin:
		input.x += 1.0
	if mouse.y < edge_margin:
		input.y += 1.0
	elif mouse.y > size.y - edge_margin:
		input.y -= 1.0
	return input


func _clamped(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, bounds.position.x, bounds.end.x),
		0.0,
		clampf(point.z, bounds.position.y, bounds.end.y))
