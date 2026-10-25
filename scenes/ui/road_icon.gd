class_name RoadIcon
extends Control

## A tiny figure in the person's coat colour, as STYLE.md codes the characters.

const SIZE: Vector2 = Vector2(22.0, 22.0)
const BACK: Color = Color("D8CFBE")  # plaster
const SKIN: Color = Color("E0B08C")  # skin_2
const JACK_COAT: Color = Color("A88A62")  # camel_coat
const REGGIE_COAT: Color = Color("3A3A3D")  # charcoal
const REGGIE_CAP: Color = Color("6A6660")  # cap_grey
const COURIER_COAT: Color = Color("5A5F44")  # tweed_green
const ARC_POINTS: int = 12

var who: String = ""


func _init(person: String = "") -> void:
	who = person
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func coat() -> Color:
	match who:
		DayCycle.JACK:
			return JACK_COAT
		Helper.ACTOR:
			return REGGIE_COAT
	return COURIER_COAT


func _draw() -> void:
	var box := Rect2(Vector2.ZERO, size)
	var centre := box.get_center()
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(centre, radius, BACK)
	var head := centre + Vector2(0.0, -radius * 0.28)
	draw_circle(head, radius * 0.26, SKIN)
	var shoulders := PackedVector2Array()
	var base := centre + Vector2(0.0, radius * 0.85)
	for step: int in ARC_POINTS + 1:
		var angle := PI + PI * float(step) / float(ARC_POINTS)
		shoulders.append(base + Vector2(cos(angle), sin(angle)) * radius * 0.55)
	draw_colored_polygon(shoulders, coat())
	if who == Helper.ACTOR:
		draw_rect(Rect2(head + Vector2(-radius * 0.3, -radius * 0.32), Vector2(radius * 0.6, radius * 0.18)), REGGIE_CAP)
