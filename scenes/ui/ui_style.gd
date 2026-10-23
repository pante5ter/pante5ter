class_name UiStyle
extends RefCounted

const ACCENT: Color = Color(0.96, 0.84, 0.45)
const MUTED: Color = Color(0.75, 0.78, 0.75)
const PANEL: Color = Color(0.07, 0.06, 0.05, 0.92)


static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14.0)
	return style


static func label(text: String, size: int = 15, color: Color = Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result


static func button(text: String, on_pressed: Callable, enabled: bool = true) -> Button:
	var result := Button.new()
	result.text = text
	result.disabled = not enabled
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(on_pressed)
	return result
