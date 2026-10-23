class_name IsoCameraRig
extends Node3D

@export var camera: Camera3D
@export var pitch_degrees: float = 35.264
@export var distance: float = 60.0
@export var pan_speed: float = 14.0
@export var edge_scroll: bool = true
@export var edge_margin: float = 12.0
@export var zoom_min: float = 6.0
@export var zoom_max: float = 40.0
@export var zoom_step: float = 2.0
@export var smoothing: float = 10.0
@export var bounds: Rect2 = Rect2(-30.0, -30.0, 60.0, 60.0)

var _target_yaw: float = 0.0
var _target_zoom: float = 16.0


func _ready() -> void:
	var pitch := deg_to_rad(pitch_degrees)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(-pitch, 0.0, 0.0)
	camera.near = 0.1
	camera.far = distance * 3.0
	_target_yaw = rotation.y
	_target_zoom = clampf(camera.size, zoom_min, zoom_max)


func focus(point: Vector3) -> void:
	position = _clamped(Vector3(point.x, 0.0, point.z))


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
	camera.size = lerpf(camera.size, _target_zoom, weight)
	var input := _pan_input()
	if input != Vector2.ZERO:
		var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
		var right := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
		var speed := pan_speed * camera.size / 16.0
		position = _clamped(position + (right * input.x + forward * input.y) * speed * delta)


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
