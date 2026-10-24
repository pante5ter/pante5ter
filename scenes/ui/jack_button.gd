class_name JackButton
extends Button

## Jack's portrait in a crosshair: a click brings the camera back to him, a double click keeps it on him.

signal centre_requested
signal follow_requested

const SIZE: Vector2 = Vector2(60.0, 60.0)
const BACK: Color = Color("3A3A3C")  # dark_grey
const RING: Color = Color("F2C46B")  # lamp_warm
const SKIN: Color = Color("E0B08C")  # skin_2
const HAIR: Color = Color("2A2420")  # hair_dark
const COAT: Color = Color("A88A62")  # camel_coat
const SHIRT: Color = Color("E9E2D0")  # shirt_cream


func _ready() -> void:
	name = "JackButton"
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = SIZE
	flat = true
	tooltip_text = "Камера к Джеку  [Пробел / Home]\nДвойной клик — держать Джека в кадре"
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	if button.double_click:
		follow_requested.emit()
	else:
		centre_requested.emit()


func _draw() -> void:
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 2.0
	var ring := RING.lightened(0.15) if is_hovered() else RING
	var frame := _disc(centre, radius)
	draw_colored_polygon(frame, BACK)
	for shoulders: PackedVector2Array in Geometry2D.intersect_polygons(_disc(centre + Vector2(0.0, radius * 0.8), radius * 0.62), frame):
		draw_colored_polygon(shoulders, COAT)
	draw_colored_polygon(PackedVector2Array([centre + Vector2(-radius * 0.16, radius * 0.26), centre + Vector2(radius * 0.16, radius * 0.26), centre + Vector2(0.0, radius * 0.62)]), SHIRT)
	draw_circle(centre + Vector2(0.0, -radius * 0.08), radius * 0.34, SKIN)
	draw_arc(centre + Vector2(0.0, -radius * 0.14), radius * 0.34, PI * 1.05, PI * 1.95, 12, HAIR, radius * 0.2, true)
	draw_arc(centre, radius, 0.0, TAU, 40, ring, 3.0, true)
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2.from_angle(angle)
		draw_line(centre + direction * (radius - 7.0), centre + direction * (radius + 1.0), ring, 3.0, true)


static func _disc(centre: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step: int in 32:
		points.append(centre + Vector2.from_angle(TAU * float(step) / 32.0) * radius)
	return points
