class_name DaySummaryPanel
extends Control

## The summary of the day: a clean card with the numbers, then the day's key facts fly in as stickers.

signal next_pressed

const WIDTH: float = 640.0
const TOP: float = 56.0
const STICKER_GAP: float = 18.0
const FIRST_STICKER_DELAY: float = 0.35
const STICKER_STAGGER: float = 0.22
const FLIGHT_SECONDS: float = 0.55
## Fixed per slot so the same day always looks the same; no dice in the view.
const TILTS: Array[float] = [-5.0, 4.0, -2.5, 6.0, -4.0]
const DROPS: Array[float] = [0.0, 12.0, -6.0, 9.0, -3.0]
const INK: Color = Color("EDEBE6")  # white
const GOLD: Color = Color("F2C46B")  # lamp_warm
const MUTED: Color = Color("B5B5B0")  # light_grey
const BACK: Color = Color("26272A")  # pot_black
const GAIN: Color = Color("6E8F5E")  # money_green
const LOSS: Color = Color("B83A32")  # alert_red

var title_label: Label
var next_button: Button
var stickers: Control
var _card: PanelContainer
var _figures: GridContainer
var _lines: VBoxContainer
var _tween: Tween


func _ready() -> void:
	name = "DaySummaryPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.custom_minimum_size = Vector2(WIDTH, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BACK, 0.97)
	style.border_color = GOLD
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	_card.add_child(rows)
	title_label = UiStyle.label("", 32, GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size = Vector2(WIDTH - 44.0, 0.0)
	rows.add_child(title_label)
	_figures = GridContainer.new()
	_figures.columns = 5
	_figures.add_theme_constant_override("h_separation", 10)
	rows.add_child(_figures)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 3)
	rows.add_child(_lines)
	next_button = UiStyle.button("Дальше", next_pressed.emit)
	next_button.custom_minimum_size = Vector2(220.0, 40.0)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(next_button)
	stickers = Control.new()
	stickers.name = "Stickers"
	stickers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stickers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stickers)


func show_day(summary: DaySummary, notes: Array[DayStickers.Note], button_text: String) -> void:
	title_label.text = summary.title()
	next_button.text = button_text
	_clear(_figures)
	for figure: PackedStringArray in summary.figures():
		_figures.add_child(_figure(figure[0], figure[1], _figure_colour(figure[0], summary)))
	_clear(_lines)
	for line: String in summary.lines():
		var row := UiStyle.label(line, 15, MUTED)
		row.custom_minimum_size = Vector2(WIDTH - 44.0, 0.0)
		_lines.add_child(row)
	_clear(stickers)
	for note: DayStickers.Note in notes:
		stickers.add_child(DaySticker.make(note))
	visible = true
	_card.reset_size()
	_place.call_deferred()


func _figure(caption: String, value: String, colour: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2((WIDTH - 44.0 - 40.0) / 5.0, 0.0)
	var number := UiStyle.label(value, 24, colour)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(number)
	var name_label := UiStyle.label(caption, 13, MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return box


static func _figure_colour(caption: String, summary: DaySummary) -> Color:
	match caption:
		"Итог":
			return GAIN if summary.net() > 0 else (LOSS if summary.net() < 0 else INK)
		"Потери":
			return LOSS if not summary.losses.is_empty() else INK
	return INK


func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


## The card on top, the stickers in a row under it; then they fly in one by one.
func _place() -> void:
	var screen := get_viewport_rect().size
	_card.reset_size()
	_card.position = Vector2(maxf((screen.x - _card.size.x) / 2.0, 0.0), TOP)
	var count := stickers.get_child_count()
	if count == 0:
		return
	var step := DaySticker.SIZE.x + STICKER_GAP
	if count > 1:
		step = minf(step, (screen.x - 40.0 - DaySticker.SIZE.x) / float(count - 1))
	var row_width := DaySticker.SIZE.x + step * float(count - 1)
	var left := (screen.x - row_width) / 2.0
	var top := minf(_card.position.y + _card.size.y + 28.0, screen.y - DaySticker.SIZE.y - 24.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	for index: int in count:
		var sticker := stickers.get_child(index) as DaySticker
		var slot := Vector2(left + step * float(index), top + DROPS[index % DROPS.size()])
		var tilt := deg_to_rad(TILTS[index % TILTS.size()])
		sticker.position = Vector2(slot.x + (60.0 if index % 2 == 0 else -60.0), -DaySticker.SIZE.y - 40.0)
		sticker.rotation = -tilt * 4.0
		sticker.scale = Vector2(1.25, 1.25)
		sticker.modulate.a = 0.0
		var delay := FIRST_STICKER_DELAY + STICKER_STAGGER * float(index)
		_tween.tween_property(sticker, "position", slot, FLIGHT_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(sticker, "rotation", tilt, FLIGHT_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(sticker, "scale", Vector2.ONE, FLIGHT_SECONDS).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(sticker, "modulate:a", 1.0, 0.15).set_delay(delay)


func sticker_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for child: Node in stickers.get_children():
		var sticker := child as DaySticker
		if sticker != null and not sticker.is_queued_for_deletion():
			texts.append(sticker.text())
	return texts


func body_text() -> String:
	var texts := PackedStringArray()
	for node: Node in _card.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion():
			texts.append((node as Label).text)
	return "\n".join(texts)
