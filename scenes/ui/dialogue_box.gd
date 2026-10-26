class_name DialogueBox
extends Control

signal finished
signal chosen(index: int)

const LINE_COLOR: Color = Color("d8cfbe")
const NARRATION_COLOR: Color = Color("a9b2b5")
const DEFAULT_SPEAKER_COLOR: Color = Color("f2c46b")
## Playtesters mixed up who said what, so every regular speaker gets a colour of their own.
const SPEAKER_COLORS: Dictionary[String, Color] = {
	"Лорд Эшкомб": Color("f2c46b"),
	"Джек": Color("d98f6b"),
	"Реджи": Color("9fc98a"),
	"Вивьен": Color("d9909a"),
}
const HINT_TEXT: String = "Пробел / ЛКМ — дальше    Esc — пропустить"
const CHOICE_HINT_TEXT: String = "Выберите ответ: клик или клавиши 1–2"

@export var speaker_label: Label
@export var text_label: Label

var _lines: Array[DialogueLineDef] = []
var _index: int = -1
var _choices: PackedStringArray = PackedStringArray()
## Empty means every choice is available.
var _enabled: Array[bool] = []
var _choice_row: HBoxContainer
var _hint: Label
var _voice: AudioStreamPlayer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = get_node_or_null("BottomBar/Hint") as Label
	_choice_row = HBoxContainer.new()
	_choice_row.name = "Choices"
	_choice_row.add_theme_constant_override("separation", 16)
	_choice_row.visible = false
	speaker_label.get_parent().add_child(_choice_row)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = "Master"
	add_child(_voice)


func play(lines: Array[DialogueLineDef], choices: PackedStringArray = PackedStringArray()) -> void:
	_lines = lines.duplicate()
	_choices = choices.duplicate()
	_enabled = []
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


## On the last line of a dialogue with choices, waiting for one.
func is_choosing() -> bool:
	return is_open() and not _choices.is_empty() and _index == _lines.size() - 1


func choice_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in _choice_row.get_children():
		var button := child as Button
		if button != null and not button.is_queued_for_deletion():
			buttons.append(button)
	return buttons


## Greys out choices, e.g. the ones Jack cannot pay for; the next play() makes all available again.
func set_choices_enabled(flags: Array[bool]) -> void:
	_enabled = flags.duplicate()
	_refresh_choices()


func is_choice_enabled(index: int) -> bool:
	return index >= _enabled.size() or _enabled[index]


func choose(index: int) -> void:
	if not is_choosing() or index < 0 or index >= _choices.size() or not is_choice_enabled(index):
		return
	chosen.emit(index)


func advance() -> void:
	if not is_open() or is_choosing():
		return
	_stop_voice()
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


## A choice cannot be skipped: Esc jumps to it instead.
func skip() -> void:
	if not is_open():
		return
	_stop_voice()
	if _choices.is_empty():
		_finish()
		return
	_index = _lines.size() - 1
	_show_line()


func _show_line() -> void:
	var line := _lines[_index]
	speaker_label.text = line.speaker
	speaker_label.visible = not line.speaker.is_empty()
	speaker_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(line.speaker, DEFAULT_SPEAKER_COLOR))
	text_label.text = line.text
	text_label.add_theme_color_override("font_color", NARRATION_COLOR if line.speaker.is_empty() else LINE_COLOR)
	_refresh_choices()
	_play_voice(line)


func _play_voice(line: DialogueLineDef) -> void:
	_stop_voice()
	if line.speaker.is_empty() or line.text.is_empty():
		return
	var stream: AudioStream = VoiceBank.stream_for(line.speaker, line.text)
	if stream == null:
		return
	_voice.stream = stream
	_voice.play()


func _stop_voice() -> void:
	if _voice != null and _voice.playing:
		_voice.stop()


func _refresh_choices() -> void:
	for child: Node in _choice_row.get_children():
		_choice_row.remove_child(child)
		child.queue_free()
	var choosing := is_choosing()
	_choice_row.visible = choosing
	if _hint != null:
		_hint.text = CHOICE_HINT_TEXT if choosing else HINT_TEXT
	if not choosing:
		return
	for index: int in _choices.size():
		var button := UiStyle.button("%d. %s" % [index + 1, _choices[index]], choose.bind(index), is_choice_enabled(index))
		button.add_theme_font_size_override("font_size", 20)
		_choice_row.add_child(button)


func _finish() -> void:
	_stop_voice()
	visible = false
	_lines = []
	_choices = PackedStringArray()
	_index = -1
	_refresh_choices()
	finished.emit()
