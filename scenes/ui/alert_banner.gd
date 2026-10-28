class_name AlertBanner
extends VBoxContainer

## Urgent news at the top of the screen, newest first. A new alert pops in with a pulse;
## dangerous ones keep throbbing until acknowledged or resolved.

signal action_requested(topic: String)

const WIDTH: float = 620.0
const MAX_ROWS: int = 3
const FADE_SECONDS: float = 0.6
const POP_SECONDS: float = 0.35
const THROB_SPEED: float = 5.0


class Row:
	var alert: Alert
	var panel: PanelContainer
	var style: StyleBoxFlat
	var age: float = 0.0


var _rows: Array[Row] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 12.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_theme_constant_override("separation", 8)


func push(alert: Alert) -> void:
	acknowledge(alert.topic)
	var row := Row.new()
	row.alert = alert
	row.style = PhoneKit.rounded(Alert.fill_color(alert.severity), 12, 12.0)
	row.style.set_border_width_all(3)
	row.style.border_color = Alert.fill_color(alert.severity).lightened(0.35)
	row.panel = _build(alert, row.style)
	add_child(row.panel)
	move_child(row.panel, 0)
	_rows.insert(0, row)
	while _rows.size() > MAX_ROWS:
		_remove(_oldest_dismissable())
	row.panel.pivot_offset = Vector2(WIDTH / 2.0, 30.0)
	row.panel.scale = Vector2(1.08, 1.08)
	var pop := row.panel.create_tween()
	pop.tween_property(row.panel, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func acknowledge(topic: String) -> void:
	for row: Row in _rows.duplicate():
		if row.alert.topic == topic:
			_remove(row)


func clear() -> void:
	for row: Row in _rows.duplicate():
		_remove(row)


func topics() -> PackedStringArray:
	var result := PackedStringArray()
	for row: Row in _rows:
		result.append(row.alert.topic)
	return result


func find_alert(topic: String) -> Alert:
	for row: Row in _rows:
		if row.alert.topic == topic:
			return row.alert
	return null


func _process(delta: float) -> void:
	var sim := Game.sim
	for row: Row in _rows.duplicate():
		row.age += delta
		var alert := row.alert
		if not Alert.is_live(alert.topic, sim):
			_remove(row)
			continue
		if not alert.sticky:
			var left := alert.seconds - row.age
			row.panel.modulate.a = clampf(left / FADE_SECONDS, 0.0, 1.0)
			if left <= 0.0:
				_remove(row)
			continue
		if alert.severity == Alert.Severity.DANGER:
			var throb := 0.5 + 0.5 * sin(row.age * THROB_SPEED)
			row.style.border_color = Alert.fill_color(alert.severity).lerp(PhoneKit.TEXT, throb * 0.8)


func _build(alert: Alert, style: StyleBoxFlat) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Alert_" + alert.topic
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	panel.add_child(line)
	var icon := AlertIcon.new()
	icon.glyph = alert.glyph
	icon.ink = Alert.ink_color(alert.severity)
	icon.back = Alert.fill_color(alert.severity)
	line.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	words.add_child(PhoneKit.label(alert.title, 21, Alert.ink_color(alert.severity)))
	if not alert.body.is_empty():
		words.add_child(PhoneKit.label(alert.body, PhoneKit.BODY_SIZE, Alert.ink_color(alert.severity)))
	line.add_child(words)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var ink := Alert.ink_color(alert.severity)
	if not alert.action.is_empty() and (alert.topic == Alert.CALL or alert.topic == Alert.HOME or Alert.is_unanswered_call(alert.topic) or AlertTarget.find_live(get_tree(), alert.topic) != null):
		buttons.add_child(_button(alert.action, action_requested.emit.bind(alert.topic), ink))
	elif Alert.is_farm_trouble(alert.topic) and AlertTarget.find_live(get_tree(), alert.topic) == null and not _on_the_farm():
		buttons.add_child(_button(Alert.LOOK_AT_FARM, action_requested.emit.bind(alert.topic), ink))
	if Alert.is_unanswered_call(alert.topic):
		pass
	elif alert.sticky:
		buttons.add_child(_button("Понял", acknowledge.bind(alert.topic), ink))
	else:
		buttons.add_child(_button("×", acknowledge.bind(alert.topic), ink))
	line.add_child(buttons)
	return panel


## Away from the farm a raid or an inspection offers to switch the view there.
func _on_the_farm() -> bool:
	var hud := get_parent() as Hud
	return hud == null or hud.place == DayCycle.FARM


func _button(text: String, on_pressed: Callable, ink: Color) -> Button:
	var button := PhoneKit.ghost(text, on_pressed, ink)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = Vector2(96.0 if text.length() > 1 else 40.0, 34.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return button


func _oldest_dismissable() -> Row:
	for index: int in range(_rows.size() - 1, -1, -1):
		if not _rows[index].alert.sticky:
			return _rows[index]
	return _rows[_rows.size() - 1]


func _remove(row: Row) -> void:
	_rows.erase(row)
	if is_instance_valid(row.panel):
		remove_child(row.panel)
		row.panel.queue_free()


class AlertIcon:
	extends Control

	const SIZE: Vector2 = Vector2(48.0, 48.0)

	var glyph: String = ""
	var ink: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _ready() -> void:
		custom_minimum_size = SIZE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		PhoneGlyphs.draw(self, glyph, Rect2(Vector2.ZERO, SIZE), ink, back)
