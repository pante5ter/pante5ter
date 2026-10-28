class_name DaySticker
extends Control

## A paper note taped to the screen: one key fact of the day.

const SIZE: Vector2 = Vector2(230.0, 132.0)
const TAPE_SIZE: Vector2 = Vector2(70.0, 18.0)
const TAPE: Color = Color("B5B5B0")  # light_grey
const SHADOW: Color = Color("1C1C1E")  # black
const INK: Color = Color("1C1C1E")  # black

var heading_label: Label
var text_label: Label


static func make(note: DayStickers.Note) -> DaySticker:
	var sticker := DaySticker.new()
	sticker._build(note)
	return sticker


func _build(note: DayStickers.Note) -> void:
	name = "Sticker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	var paper := PanelContainer.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.size = SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = note.paper
	style.shadow_color = Color(SHADOW, 0.45)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3.0, 4.0)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 10.0
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	paper.add_child(rows)
	heading_label = UiStyle.label(note.heading.to_upper(), 13, note.ink)
	heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(heading_label)
	text_label = UiStyle.label(note.text, 14, INK)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.custom_minimum_size = Vector2(SIZE.x - 28.0, 0.0)
	text_label.max_lines_visible = 4
	rows.add_child(text_label)
	var tape := ColorRect.new()
	tape.color = Color(TAPE, 0.75)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape.size = TAPE_SIZE
	tape.position = Vector2((SIZE.x - TAPE_SIZE.x) / 2.0, -TAPE_SIZE.y / 2.0)
	tape.pivot_offset = TAPE_SIZE / 2.0
	tape.rotation = deg_to_rad(-4.0)
	add_child(tape)


func text() -> String:
	return "%s\n%s" % [heading_label.text, text_label.text]
