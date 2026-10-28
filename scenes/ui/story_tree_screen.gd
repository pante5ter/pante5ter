class_name StoryTreeScreen
extends PanelContainer

## «Развилки»: the story's forks as a flowchart with how far each storyline has come. Read-only; after the
## summary of the day it shows that day, from the pause menu the whole game.

signal next_pressed

const MARGIN: float = 40.0
const MAX_SIZE: Vector2 = Vector2(1080.0, 820.0)
const GOLD: Color = Color("F2C46B")  # lamp_warm
const MUTED: Color = Color("B5B5B0")  # light_grey
const BACK: Color = Color("26272A")  # pot_black

var title_label: Label
var progress_label: Label
var empty_label: Label
var view: StoryTreeView
var next_button: Button
var _scroll: ScrollContainer
var _beats: Array[StoryTree.Beat] = []


func _ready() -> void:
	name = "StoryTreeScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BACK, 0.97)
	style.border_color = GOLD
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18.0)
	add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)
	title_label = UiStyle.label("", 28, GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title_label)
	progress_label = UiStyle.label("", 14, MUTED)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(progress_label)
	empty_label = UiStyle.label("Развилок пока не было. Всё ещё впереди.", 16, MUTED)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(empty_label)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(_scroll)
	view = StoryTreeView.new()
	view.name = "Tree"
	_scroll.add_child(view)
	next_button = UiStyle.button("Дальше", next_pressed.emit)
	next_button.custom_minimum_size = Vector2(220.0, 40.0)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(next_button)


## The forks of one day, after its summary.
func show_day(sim: SimState, from: float, to: float, button_text: String) -> void:
	_show(sim, StoryTree.beats(sim, from, to), false, "Развилки дня %d" % DayEndWatch.day_number(from), button_text)


## Every fork so far, by day.
func show_all(sim: SimState) -> void:
	_show(sim, StoryTree.beats(sim, 0.0, INF), true, "Развилки", "Закрыть")


func beats() -> Array[StoryTree.Beat]:
	return _beats


func _show(sim: SimState, found: Array[StoryTree.Beat], by_day: bool, heading: String, button_text: String) -> void:
	_beats = found
	title_label.text = heading
	progress_label.text = progress_text(sim)
	next_button.text = button_text
	empty_label.visible = found.is_empty()
	view.show_beats(found, by_day)
	visible = true
	_fit.call_deferred()


static func progress_text(sim: SimState) -> String:
	var parts := PackedStringArray()
	var lines := StoryTree.progress(sim)
	for line: String in StoryTree.STORYLINES:
		var done: Vector2i = lines.get(line, Vector2i.ZERO)
		if done.y > 0:
			parts.append("%s %d%%" % [line, StoryTree.percent(done)])
	return "Сюжет пройден на %d%% · %s" % [StoryTree.overall_percent(sim), " · ".join(parts)]


func _fit() -> void:
	var screen := get_viewport_rect().size
	var room := (screen - Vector2(MARGIN, MARGIN) * 2.0).min(MAX_SIZE)
	_scroll.custom_minimum_size = Vector2(minf(view.custom_minimum_size.x, room.x - 36.0), minf(view.custom_minimum_size.y, room.y - 190.0))
	reset_size()
	position = ((screen - size) / 2.0).max(Vector2.ZERO)


func close() -> void:
	visible = false
