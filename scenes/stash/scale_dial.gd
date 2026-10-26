class_name ScaleDial
extends Control

## The kitchen scale's face: a 3/4 dial with the target bands and a needle.

## 150° to 390°, clockwise through the top.
const START_ANGLE: float = PI * 5.0 / 6.0
const END_ANGLE: float = PI * 13.0 / 6.0
const RING_WIDTH: float = 16.0
const TICK_STEP_GRAMS: float = 5.0
const FACE_COLOR: Color = Color(0.93, 0.9, 0.82)
const RING_COLOR: Color = Color(0.25, 0.22, 0.2)
const FAIR_COLOR: Color = Color(0.62, 0.5, 0.3)
const GOOD_COLOR: Color = UiStyle.ACCENT
const PERFECT_COLOR: Color = Color(0.45, 0.78, 0.4)
const NEEDLE_COLOR: Color = Color(0.72, 0.16, 0.12)
const INK_COLOR: Color = Color(0.18, 0.15, 0.13)

var def: HandPackingDef
## What the needle shows; the view eases it, the recorded weight is kept elsewhere.
var shown_grams: float = 0.0:
	set(value):
		shown_grams = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(380.0, 250.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func angle_for(grams: float) -> float:
	var top := def.scale_max_grams if def != null else 1.0
	return lerpf(START_ANGLE, END_ANGLE, clampf(grams / maxf(top, 0.001), 0.0, 1.05))


func _draw() -> void:
	if def == null:
		return
	var centre := Vector2(size.x * 0.5, size.y * 0.58)
	var radius := minf(size.x * 0.42, size.y * 0.52)
	draw_circle(centre, radius + 10.0, RING_COLOR)
	draw_circle(centre, radius + 4.0, FACE_COLOR)
	_band(centre, radius, def.fair_grams, FAIR_COLOR)
	_band(centre, radius, def.good_grams, GOOD_COLOR)
	_band(centre, radius, def.perfect_grams, PERFECT_COLOR)
	_ticks(centre, radius)
	var tip := centre + Vector2.from_angle(angle_for(shown_grams)) * (radius - 6.0)
	var tail := centre - Vector2.from_angle(angle_for(shown_grams)) * 14.0
	draw_line(tail, tip, NEEDLE_COLOR, 4.0, true)
	draw_circle(centre, 9.0, INK_COLOR)
	draw_circle(centre, 4.0, NEEDLE_COLOR)


func _band(centre: Vector2, radius: float, half_grams: float, color: Color) -> void:
	var from := angle_for(def.target_grams - half_grams)
	var to := angle_for(def.target_grams + half_grams)
	draw_arc(centre, radius - RING_WIDTH * 0.5, from, to, 24, color, RING_WIDTH, true)


func _ticks(centre: Vector2, radius: float) -> void:
	var font := get_theme_default_font()
	var grams := 0.0
	while grams <= def.scale_max_grams + 0.001:
		var direction := Vector2.from_angle(angle_for(grams))
		draw_line(centre + direction * (radius - RING_WIDTH - 10.0), centre + direction * (radius - RING_WIDTH), INK_COLOR, 2.0, true)
		var text := "%d" % roundi(grams)
		var at := centre + direction * (radius - RING_WIDTH - 26.0) - Vector2(8.0, -5.0)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 16.0, 13, INK_COLOR)
		grams += TICK_STEP_GRAMS
	var target_direction := Vector2.from_angle(angle_for(def.target_grams))
	draw_line(centre + target_direction * (radius - RING_WIDTH - 4.0), centre + target_direction * (radius + 6.0), INK_COLOR, 3.0, true)
