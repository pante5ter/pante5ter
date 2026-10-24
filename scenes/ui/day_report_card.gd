class_name DayReportCard
extends PanelContainer

## A page of the bedtime summary or the morning briefing: a title, sections of lines and one button.

signal next_pressed

const WIDTH: float = 620.0
const INK: Color = Color("EDEBE6")  # white
const GOLD: Color = Color("F2C46B")  # lamp_warm
const MUTED: Color = Color("B5B5B0")  # light_grey
const BACK: Color = Color("26272A")  # pot_black

var title_label: Label
var next_button: Button
var _body: VBoxContainer


func _ready() -> void:
	name = "DayReportCard"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BACK, 0.96)
	style.border_color = GOLD
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	title_label = UiStyle.label("", 30, GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A wrapping label with no width asks for a tower of one-letter lines; the card would grow to the screen.
	title_label.custom_minimum_size = Vector2(WIDTH - 44.0, 0.0)
	rows.add_child(title_label)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 4)
	rows.add_child(_body)
	next_button = UiStyle.button("Дальше", next_pressed.emit)
	next_button.custom_minimum_size = Vector2(220.0, 40.0)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(next_button)


## sections: heading -> lines; an empty heading prints the lines alone.
func show_page(title: String, sections: Array[Dictionary], button_text: String) -> void:
	title_label.text = title
	next_button.text = button_text
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	for section: Dictionary in sections:
		var heading := String(section.get("heading", ""))
		if not heading.is_empty():
			var head := UiStyle.label(heading, 18, GOLD)
			head.custom_minimum_size = Vector2(WIDTH - 44.0, 0.0)
			_body.add_child(head)
		for line: String in section.get("lines", PackedStringArray()) as PackedStringArray:
			var row := UiStyle.label(line, 16, INK if not line.begins_with("•") else MUTED)
			row.custom_minimum_size = Vector2(WIDTH - 44.0, 0.0)
			_body.add_child(row)
	visible = true
	reset_size.call_deferred()


func body_text() -> String:
	var lines := PackedStringArray()
	for child: Node in _body.get_children():
		var row := child as Label
		if row != null:
			lines.append(row.text)
	return "\n".join(lines)
