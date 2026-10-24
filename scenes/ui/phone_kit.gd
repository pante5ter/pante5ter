class_name PhoneKit
extends RefCounted

## Building blocks for the phone screens. Colours are swatches from assets/textures/palette.json.

const SCREEN: Color = Color("26272A")  # pot_black
const CARD: Color = Color("3A3A3C")  # dark_grey
const BEZEL: Color = Color("1C1C1E")  # black
const TEXT: Color = Color("EDEBE6")  # white
const MUTED: Color = Color("B5B5B0")  # light_grey
const GOLD: Color = Color("F2C46B")  # lamp_warm
const INK: Color = Color("2A2420")  # hair_dark
const DANGER: Color = Color("B83A32")  # alert_red
const WARNING: Color = Color("C9A23A")  # hazard_yellow
const GOOD: Color = Color("6E8F5E")  # money_green
const INFO: Color = Color("4A4F57")  # slate

const TITLE_SIZE: int = 17
const BODY_SIZE: int = 15
const SMALL_SIZE: int = 13
const PRIMARY_HEIGHT: float = 40.0
const SECONDARY_HEIGHT: float = 34.0


static func label(text: String, size: int = BODY_SIZE, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


static func rounded(color: Color, radius: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


## A card holds one thing: a person, an item, a call. Children go into the returned box.
static func card(parent: Container, accent: Color = CARD) -> VBoxContainer:
	var frame := PanelContainer.new()
	var style := rounded(CARD, 10, 10.0)
	if accent != CARD:
		style.border_color = accent
		style.border_width_left = 4
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	frame.add_child(rows)
	parent.add_child(frame)
	return rows


## A title on the left and a figure (price, wage) on the right.
static func heading(parent: Container, title: String, figure: String = "", color: Color = TEXT) -> void:
	var row := HBoxContainer.new()
	row.add_child(label(title, TITLE_SIZE, color))
	if not figure.is_empty():
		var value := label(figure, TITLE_SIZE, GOLD)
		value.size_flags_horizontal = Control.SIZE_SHRINK_END
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(value)
	parent.add_child(row)


static func primary(text: String, on_pressed: Callable, enabled: bool = true) -> Button:
	return _button(text, on_pressed, enabled, GOLD, INK, PRIMARY_HEIGHT)


static func secondary(text: String, on_pressed: Callable, enabled: bool = true) -> Button:
	return _button(text, on_pressed, enabled, Color("4C5157"), TEXT, SECONDARY_HEIGHT)  # steel_dark


static func danger(text: String, on_pressed: Callable, enabled: bool = true) -> Button:
	return _button(text, on_pressed, enabled, DANGER, TEXT, SECONDARY_HEIGHT)


## A see-through button that reads on any coloured background, such as an alert.
static func ghost(text: String, on_pressed: Callable, ink: Color) -> Button:
	return _button(text, on_pressed, true, Color(0.0, 0.0, 0.0, 0.3), ink, SECONDARY_HEIGHT)


## Buttons sit side by side and share the width equally.
static func row(parent: Container, buttons: Array[Button]) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	for button: Button in buttons:
		line.add_child(button)
	parent.add_child(line)


static func clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


static func _button(text: String, on_pressed: Callable, enabled: bool, fill: Color, ink: Color, height: float) -> Button:
	var result := Button.new()
	result.text = text
	result.disabled = not enabled
	result.focus_mode = Control.FOCUS_NONE
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.custom_minimum_size = Vector2(0.0, height)
	result.add_theme_font_size_override("font_size", BODY_SIZE)
	result.add_theme_stylebox_override("normal", rounded(fill, 8, 6.0))
	result.add_theme_stylebox_override("hover", rounded(fill.lightened(0.12), 8, 6.0))
	result.add_theme_stylebox_override("pressed", rounded(fill.darkened(0.15), 8, 6.0))
	result.add_theme_stylebox_override("disabled", rounded(CARD.lightened(0.06), 8, 6.0))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		result.add_theme_color_override(state, ink)
	result.add_theme_color_override("font_disabled_color", MUTED.darkened(0.25))
	result.pressed.connect(on_pressed)
	return UiRefresh.press_on_down(result)
