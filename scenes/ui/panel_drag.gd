class_name PanelDrag
extends Node

## Lets the player drag the parent panel by its background and remembers where it was left.

const SECTION: String = "panels"

@export var settings_key: String = ""

var _panel: Control
var _dragging: bool = false
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_panel = get_parent() as Control
	if _panel == null:
		push_error("PanelDrag must be a child of a Control")
		return
	_panel.gui_input.connect(_on_gui_input)
	_panel.visibility_changed.connect(_on_visibility_changed)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_dragging = true
			_grab_offset = button.global_position - _panel.global_position
		elif _dragging:
			_dragging = false
			_save()
		_panel.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_panel.global_position = _clamped(motion.global_position - _grab_offset)
		_panel.accept_event()


## The panel places itself when it opens, so the remembered place is applied right after.
func _on_visibility_changed() -> void:
	if _panel.visible:
		_restore.call_deferred()
	else:
		_dragging = false


func _restore() -> void:
	var config := ConfigFile.new()
	if config.load(Game.ui_settings_path) != OK or not config.has_section_key(SECTION, settings_key):
		return
	var saved: Variant = config.get_value(SECTION, settings_key)
	if saved is Vector2:
		_panel.global_position = _clamped(saved as Vector2)


func _save() -> void:
	var config := ConfigFile.new()
	config.load(Game.ui_settings_path)
	config.set_value(SECTION, settings_key, _panel.global_position)
	config.save(Game.ui_settings_path)


func _clamped(at: Vector2) -> Vector2:
	var limit := _panel.get_viewport_rect().size - _panel.size
	return Vector2(clampf(at.x, 0.0, maxf(limit.x, 0.0)), clampf(at.y, 0.0, maxf(limit.y, 0.0)))
