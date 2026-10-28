class_name FlashbackProp
extends Node3D
## Something in the bunker the gang knocks over for the camera: a lamp stand, a bucket. Display only.

const FALL_SECONDS: float = 0.35
const FALL_DEGREES: float = 84.0

var knocked: bool = false


## Tips it over away from `from`; seconds until it lies still, zero when it already does.
func knock(from: Vector3) -> float:
	if knocked:
		return 0.0
	knocked = true
	var away := Vector3(global_position.x - from.x, 0.0, global_position.z - from.z)
	if away.length() < 0.01:
		away = Vector3.RIGHT
	away = away.normalized()
	var tilt := Vector3(away.z, 0.0, -away.x) * deg_to_rad(FALL_DEGREES)
	var tween := create_tween()
	tween.tween_property(self, "rotation", rotation + tilt, FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return FALL_SECONDS
