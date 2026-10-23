extends CanvasLayer

const FADE_SECONDS: float = 0.35
const OVERLAY_LAYER: int = 100

var _overlay: ColorRect
var _busy: bool = false
var _pending_spawn: String = ""


func _ready() -> void:
	layer = OVERLAY_LAYER
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


func is_busy() -> bool:
	return _busy


func take_spawn() -> String:
	var spawn := _pending_spawn
	_pending_spawn = ""
	return spawn


func go_to(scene_path: String, spawn: String) -> void:
	if _busy:
		return
	_busy = true
	_pending_spawn = spawn
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	get_tree().change_scene_to_file(scene_path)
	await get_tree().scene_changed
	await _fade_to(0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
