class_name CharacterModel
extends Node3D

const IDLE: StringName = &"idle"
const WALK: StringName = &"walk"
const WORK: StringName = &"interact-right"
const LOOPED: Array[StringName] = [IDLE, WALK, WORK]

var _player: AnimationPlayer


func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_player = players[0] as AnimationPlayer
	for animation_name: StringName in LOOPED:
		if _player.has_animation(animation_name):
			_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	play_idle()


func play_idle() -> void:
	_play(IDLE)


func play_walk() -> void:
	_play(WALK)


func play_work() -> void:
	_play(WORK)


func _play(animation_name: StringName) -> void:
	if _player == null or not _player.has_animation(animation_name):
		return
	if _player.current_animation != animation_name:
		_player.play(animation_name, 0.2)
