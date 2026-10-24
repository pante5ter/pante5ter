class_name PhoneGlyphs
extends RefCounted

## Flat pictograms drawn from primitives, so the UI needs no icon pack.
## Shapes are laid out in a unit square and stretched over the target rect.

const CALLS: String = "calls"
const MESSAGES: String = "messages"
const SHOP: String = "shop"
const STOCK: String = "stock"
const PEOPLE: String = "people"
const EMPIRE: String = "empire"
const MAP: String = "map"
const DANGER: String = "danger"
const INSPECTION: String = "inspection"
const MONEY: String = "money"

const ARC_POINTS: int = 18


static func draw(canvas: CanvasItem, glyph: String, rect: Rect2, ink: Color, back: Color) -> void:
	var stroke := rect.size.x * 0.09
	match glyph:
		CALLS:
			_arc(canvas, rect, Vector2(0.7, 0.3), 0.4, PI * 0.5, PI, ink, stroke * 1.4)
			canvas.draw_circle(_at(rect, 0.7, 0.7), rect.size.x * 0.12, ink)
			canvas.draw_circle(_at(rect, 0.3, 0.3), rect.size.x * 0.12, ink)
		MESSAGES:
			canvas.draw_rect(_box(rect, 0.14, 0.2, 0.86, 0.66), ink)
			canvas.draw_colored_polygon(_points(rect, [0.28, 0.64, 0.24, 0.86, 0.48, 0.64]), ink)
			for x: float in [0.32, 0.5, 0.68]:
				canvas.draw_circle(_at(rect, x, 0.43), rect.size.x * 0.05, back)
		SHOP:
			canvas.draw_rect(_box(rect, 0.2, 0.38, 0.8, 0.86), ink)
			_arc(canvas, rect, Vector2(0.5, 0.4), 0.16, PI, TAU, ink, stroke)
		STOCK:
			canvas.draw_rect(_box(rect, 0.16, 0.24, 0.84, 0.84), ink)
			canvas.draw_line(_at(rect, 0.16, 0.44), _at(rect, 0.84, 0.44), back, stroke * 0.6)
			canvas.draw_line(_at(rect, 0.5, 0.24), _at(rect, 0.5, 0.44), back, stroke * 0.8)
		PEOPLE:
			canvas.draw_circle(_at(rect, 0.66, 0.36), rect.size.x * 0.1, ink.darkened(0.2))
			canvas.draw_colored_polygon(_dome(rect, Vector2(0.66, 0.82), 0.19), ink.darkened(0.2))
			canvas.draw_circle(_at(rect, 0.4, 0.34), rect.size.x * 0.13, ink)
			canvas.draw_colored_polygon(_dome(rect, Vector2(0.4, 0.86), 0.25), ink)
		EMPIRE:
			canvas.draw_colored_polygon(_points(rect, [0.16, 0.7, 0.16, 0.28, 0.35, 0.48, 0.5, 0.2, 0.65, 0.48, 0.84, 0.28, 0.84, 0.7]), ink)
			canvas.draw_rect(_box(rect, 0.16, 0.75, 0.84, 0.85), ink)
		MAP:
			canvas.draw_colored_polygon(_points(rect, [0.12, 0.26, 0.38, 0.16, 0.62, 0.26, 0.88, 0.16, 0.88, 0.76, 0.62, 0.86, 0.38, 0.76, 0.12, 0.86]), ink)
			canvas.draw_line(_at(rect, 0.38, 0.16), _at(rect, 0.38, 0.76), back, stroke * 0.5)
			canvas.draw_line(_at(rect, 0.62, 0.26), _at(rect, 0.62, 0.86), back, stroke * 0.5)
			canvas.draw_circle(_at(rect, 0.5, 0.44), rect.size.x * 0.09, back)
		DANGER:
			canvas.draw_colored_polygon(_points(rect, [0.5, 0.12, 0.92, 0.86, 0.08, 0.86]), ink)
			canvas.draw_rect(_box(rect, 0.45, 0.36, 0.55, 0.64), back)
			canvas.draw_circle(_at(rect, 0.5, 0.75), rect.size.x * 0.055, back)
		INSPECTION:
			canvas.draw_colored_polygon(_points(rect, [0.5, 0.1, 0.86, 0.22, 0.8, 0.6, 0.5, 0.9, 0.2, 0.6, 0.14, 0.22]), ink)
			canvas.draw_circle(_at(rect, 0.5, 0.45), rect.size.x * 0.12, back)
		MONEY:
			canvas.draw_circle(rect.get_center(), rect.size.x * 0.38, ink)
			canvas.draw_circle(rect.get_center(), rect.size.x * 0.28, back)
			canvas.draw_circle(rect.get_center(), rect.size.x * 0.18, ink)


static func _at(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + rect.size * Vector2(x, y)


static func _box(rect: Rect2, x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var from := _at(rect, x0, y0)
	return Rect2(from, _at(rect, x1, y1) - from)


static func _points(rect: Rect2, coords: Array[float]) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index: int in range(0, coords.size(), 2):
		result.append(_at(rect, coords[index], coords[index + 1]))
	return result


## Shoulders: the upper half of a disc.
static func _dome(rect: Rect2, base: Vector2, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for step: int in ARC_POINTS + 1:
		var angle := PI + PI * float(step) / float(ARC_POINTS)
		result.append(_at(rect, base.x + cos(angle) * radius, base.y + sin(angle) * radius))
	return result


static func _arc(canvas: CanvasItem, rect: Rect2, centre: Vector2, radius: float, from: float, to: float, ink: Color, width: float) -> void:
	canvas.draw_arc(_at(rect, centre.x, centre.y), rect.size.x * radius, from, to, ARC_POINTS, ink, width, true)
