class_name RoadPanel
extends PanelContainer

## Top right, under the menu: who is on the road, doing what, and how long until they turn up.
## Gone while everyone is in.

const REFRESH_SECONDS: float = 0.25
const WIDTH: float = 330.0
const TOP: float = 56.0
const RIGHT: float = 14.0
const FONT_SIZE: int = 14

## Set by the HUD.
var hud: Hud

var _rows: VBoxContainer
var _shown: PackedStringArray = PackedStringArray()
var _refresh_left: float = 0.0


func _ready() -> void:
	name = "RoadPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiStyle.panel()
	style.set_content_margin_all(8.0)
	add_theme_stylebox_override("panel", style)
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -RIGHT - WIDTH
	offset_right = -RIGHT
	offset_top = TOP
	offset_bottom = TOP
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var title := UiStyle.label("В дороге", 12, UiStyle.MUTED)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", 4)
	column.add_child(_rows)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh()


func refresh() -> void:
	_refresh_left = REFRESH_SECONDS
	var sim := Game.sim
	var trips := RoadText.trips(sim)
	var blocked := hud != null and (hud.is_dialogue_open() or hud.night.is_open())
	visible = not trips.is_empty() and not blocked
	var who := PackedStringArray()
	for trip: RoadText.Trip in trips:
		who.append(trip.who)
	if who != _shown:
		_rebuild(trips)
		_shown = who
	for index: int in trips.size():
		var row := _rows.get_child(index) as Control
		var trip := trips[index]
		(row.get_node("Doing") as Label).text = trip.line()
		(row.get_node("Left") as Label).text = trip.countdown(sim)
		row.tooltip_text = trip.tooltip(sim)


func row_count() -> int:
	return _rows.get_child_count()


func row_tooltip(index: int) -> String:
	return (_rows.get_child(index) as Control).tooltip_text


func _rebuild(trips: Array[RoadText.Trip]) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for trip: RoadText.Trip in trips:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_theme_constant_override("separation", 8)
		row.add_child(RoadIcon.new(trip.who))
		var doing := UiStyle.label("", FONT_SIZE)
		doing.name = "Doing"
		doing.autowrap_mode = TextServer.AUTOWRAP_OFF
		doing.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		doing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		doing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(doing)
		var left := UiStyle.label("", FONT_SIZE, UiStyle.ACCENT)
		left.name = "Left"
		left.autowrap_mode = TextServer.AUTOWRAP_OFF
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(left)
		_rows.add_child(row)
	reset_size.call_deferred()
