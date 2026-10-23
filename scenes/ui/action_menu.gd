class_name ActionMenu
extends PanelContainer

const SCREEN_MARGIN: float = 12.0
const CURSOR_OFFSET: Vector2 = Vector2(16.0, 8.0)

var _title: Label
var _buttons: VBoxContainer
var _actions: Array[UiAction] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	add_child(rows)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", UiStyle.ACCENT)
	rows.add_child(_title)
	_buttons = VBoxContainer.new()
	rows.add_child(_buttons)


func open(title: String, actions: Array[UiAction], near: Vector2) -> void:
	_title.text = title
	_actions = actions
	for child: Node in _buttons.get_children():
		child.queue_free()
	for action: UiAction in actions:
		var button := Button.new()
		button.text = action.label
		button.disabled = not action.enabled
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(choose.bind(action))
		_buttons.add_child(button)
	var cancel := Button.new()
	cancel.text = "Закрыть"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close)
	_buttons.add_child(cancel)
	visible = true
	reset_size()
	var screen := get_viewport_rect().size
	position = (near + CURSOR_OFFSET).clamp(Vector2(SCREEN_MARGIN, SCREEN_MARGIN), screen - size - Vector2(SCREEN_MARGIN, SCREEN_MARGIN))


func actions() -> Array[UiAction]:
	return _actions.duplicate()


func choose(action: UiAction) -> void:
	close()
	if action.enabled and action.callback.is_valid():
		action.callback.call()


func choose_label(label: String) -> bool:
	for action: UiAction in _actions:
		if action.label.begins_with(label):
			choose(action)
			return true
	return false


func close() -> void:
	visible = false
	_actions.clear()
