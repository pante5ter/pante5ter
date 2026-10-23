class_name CharacterModel
extends Node3D

const IDLE: StringName = &"idle"
const WALK: StringName = &"walk"
const WORK: StringName = &"interact-right"
const LOOPED: Array[StringName] = [IDLE, WALK, WORK]

## Palette models are static meshes without a rig, so they are animated by moving the whole body.
const STEP_SPEED: float = 11.0
const STEP_HEIGHT: float = 0.05
const STEP_SWAY_DEGREES: float = 4.0
const WORK_SPEED: float = 5.0
const WORK_BOW_DEGREES: float = 18.0
const BREATH_SPEED: float = 1.6
const BREATH_HEIGHT: float = 0.01

var _player: AnimationPlayer
var _state: StringName = IDLE
var _phase: float = 0.0
var _rest_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_rest_position = position
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_player = players[0] as AnimationPlayer
	for animation_name: StringName in LOOPED:
		if _player.has_animation(animation_name):
			_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	play_idle()


func current_state() -> StringName:
	return _state


func play_idle() -> void:
	_play(IDLE)


func play_walk() -> void:
	_play(WALK)


func play_work() -> void:
	_play(WORK)


func _play(animation_name: StringName) -> void:
	_state = animation_name
	if _player == null or not _player.has_animation(animation_name):
		return
	if _player.current_animation != animation_name:
		_player.play(animation_name, 0.2)


func _process(delta: float) -> void:
	if _player != null:
		return
	_phase += delta
	var offset := Vector3.ZERO
	var tilt := Vector3.ZERO
	match _state:
		WALK:
			offset.y = absf(sin(_phase * STEP_SPEED)) * STEP_HEIGHT
			tilt.z = deg_to_rad(sin(_phase * STEP_SPEED) * STEP_SWAY_DEGREES)
		WORK:
			tilt.x = deg_to_rad((0.5 + 0.5 * sin(_phase * WORK_SPEED)) * WORK_BOW_DEGREES)
		_:
			offset.y = sin(_phase * BREATH_SPEED) * BREATH_HEIGHT
	position = _rest_position + offset
	rotation.x = tilt.x
	rotation.z = tilt.z
