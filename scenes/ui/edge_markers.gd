class_name EdgeMarkers
extends Control

## Points at live alert targets: a bobbing arrow over them when on screen,
## an arrow pinned to the screen edge with the distance when they are off it.

const MARGIN: float = 56.0
const HEAD_HEIGHT: float = 2.6
const ARROW: float = 26.0
const BOB_SPEED: float = 4.0
const BOB_PIXELS: float = 6.0

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Where an arrow for a point goes: the point itself when it is inside the margin,
## else where the line from the screen centre towards it crosses the margin.
static func edge_point(screen: Vector2, point: Vector2, margin: float) -> Vector2:
	var centre := screen / 2.0
	var offset := point - centre
	var half := centre - Vector2(margin, margin)
	var scale := 1.0
	if absf(offset.x) > half.x:
		scale = minf(scale, half.x / absf(offset.x))
	if absf(offset.y) > half.y:
		scale = minf(scale, half.y / absf(offset.y))
	return centre + offset * scale


static func is_on_screen(screen: Vector2, point: Vector2, margin: float) -> bool:
	return Rect2(Vector2.ZERO, screen).grow(-margin).has_point(point)


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var font := get_theme_default_font()
	var screen := get_viewport_rect().size
	for node: Node in get_tree().get_nodes_in_group(AlertTarget.GROUP):
		var target := node as AlertTarget
		if target == null or not target.is_live():
			continue
		var colour := Alert.fill_color(Alert.topic_severity(target.topic))
		var head := target.global_position + Vector3.UP * HEAD_HEIGHT
		var behind := camera.is_position_behind(head)
		var point := camera.unproject_position(head)
		if behind:
			point = screen - point
		if not behind and is_on_screen(screen, point, MARGIN):
			var tip := point + Vector2(0.0, sin(_time * BOB_SPEED) * BOB_PIXELS)
			_arrow(tip, Vector2.DOWN, colour)
			continue
		var pin := edge_point(screen, point, MARGIN)
		var direction := (point - screen / 2.0).normalized()
		_arrow(pin + direction * ARROW * 0.6, direction, colour)
		var label := "%s · %d м" % [Alert.topic_title(target.topic), roundi(_distance(camera, target))]
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.BODY_SIZE).x + 16.0
		var inward := Vector2(-direction.x * (width / 2.0 + 10.0), -direction.y * 30.0)
		var box := Rect2(pin + inward - Vector2(width / 2.0, 14.0), Vector2(width, 28.0))
		draw_style_box(PhoneKit.rounded(colour, 8, 0.0), box)
		draw_string(font, box.position + Vector2(8.0, 20.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.BODY_SIZE, Alert.ink_color(Alert.topic_severity(target.topic)))


func _arrow(tip: Vector2, direction: Vector2, colour: Color) -> void:
	var side := direction.orthogonal() * ARROW * 0.6
	var base := tip - direction * ARROW
	draw_colored_polygon(PackedVector2Array([tip + direction * 2.0, base + side * 1.25, base - side * 1.25]), PhoneKit.BEZEL)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), colour)


## Metres from the spot the camera looks at, which is where the player is looking.
static func _distance(camera: Camera3D, target: Node3D) -> float:
	var focus := camera.get_parent() as Node3D
	var from := focus.global_position if focus != null else camera.global_position
	return Vector2(from.x, from.z).distance_to(Vector2(target.global_position.x, target.global_position.z))
