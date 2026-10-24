class_name PhoneRinger
extends AudioStreamPlayer

## Buzzes the phone it belongs to and plays the ring.

const SHAKE_ANGLE: float = 0.045
const SHAKE_STEP_SECONDS: float = 0.05
const SHAKE_STEPS: int = 8
const SHAKE_PAUSE_SECONDS: float = 0.2
const BURSTS: int = 2

var _shake: Tween


func _ready() -> void:
	stream = PhoneRingtone.make()


func ring(phone: Control) -> void:
	silence(phone)
	phone.pivot_offset = phone.size / 2.0
	_shake = phone.create_tween()
	for burst: int in BURSTS:
		for step: int in SHAKE_STEPS:
			_shake.tween_property(phone, "rotation", SHAKE_ANGLE * (1.0 if step % 2 == 0 else -1.0), SHAKE_STEP_SECONDS)
		_shake.tween_property(phone, "rotation", 0.0, SHAKE_STEP_SECONDS)
		_shake.tween_interval(SHAKE_PAUSE_SECONDS)
	play()


func is_ringing() -> bool:
	return _shake != null and _shake.is_running()


func silence(phone: Control) -> void:
	if _shake != null:
		_shake.kill()
	phone.rotation = 0.0
	stop()
