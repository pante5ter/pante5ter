class_name DialogueBox
extends Control

signal finished

const LINE_COLOR: Color = Color("d8cfbe")
const NARRATION_COLOR: Color = Color("a9b2b5")
const DEFAULT_SPEAKER_COLOR: Color = Color("f2c46b")
## Playtesters mixed up who said what, so every regular speaker gets a colour of their own.
const SPEAKER_COLORS: Dictionary[String, Color] = {
	"Лорд Эшкомб": Color("f2c46b"),
	"Финн": Color("8fb3d9"),
	"Джек": Color("d98f6b"),
}

@export var speaker_label: Label
@export var text_label: Label

var _lines: Array[DialogueLineDef] = []
var _index: int = -1


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(lines: Array[DialogueLineDef]) -> void:
	_lines = lines.duplicate()
	_index = 0
	if _lines.is_empty():
		_finish()
		return
	visible = true
	_show_line()


func is_open() -> bool:
	return visible


func line_index() -> int:
	return _index


func current_line() -> DialogueLineDef:
	return _lines[_index] if is_open() else null


func advance() -> void:
	if not is_open():
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


func skip() -> void:
	if is_open():
		_finish()


func _show_line() -> void:
	var line := _lines[_index]
	speaker_label.text = line.speaker
	speaker_label.visible = not line.speaker.is_empty()
	speaker_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(line.speaker, DEFAULT_SPEAKER_COLOR))
	text_label.text = line.text
	text_label.add_theme_color_override("font_color", NARRATION_COLOR if line.speaker.is_empty() else LINE_COLOR)


func _finish() -> void:
	visible = false
	_lines = []
	_index = -1
	finished.emit()
