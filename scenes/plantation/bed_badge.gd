class_name BedBadge
extends RefCounted

## Round pictograms that float over a bed needing a hand: dry soil, a problem, a ripe crop.
## Drawn from primitives at first use so the world needs no icon textures.

const DRY: String = "dry"
const PROBLEM: String = "problem"
const READY: String = "ready"

const SIZE: int = 64
const SAMPLES: int = 3
const OUTLINE: float = 3.0
const INK: Color = Color("EDEBE6")  # white
const RIM: Color = Color("1C1C1E")  # black
const FILLS: Dictionary[String, Color] = {
	DRY: Color("2F5D9E"),  # police_blue
	PROBLEM: Color("B83A32"),  # alert_red
	READY: Color("5A8A45"),  # plant_mid
}

static var _cache: Dictionary[String, ImageTexture] = {}


static func texture(kind: String) -> ImageTexture:
	if not _cache.has(kind):
		_cache[kind] = ImageTexture.create_from_image(_draw(kind))
	return _cache[kind]


static func _draw(kind: String) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var fill: Color = FILLS.get(kind, RIM)
	var centre := Vector2(SIZE, SIZE) / 2.0
	var radius := float(SIZE) / 2.0 - 1.0
	for y: int in SIZE:
		for x: int in SIZE:
			var disc := 0.0
			var inner := 0.0
			var glyph := 0.0
			for sy: int in SAMPLES:
				for sx: int in SAMPLES:
					var point := Vector2(float(x) + (float(sx) + 0.5) / float(SAMPLES), float(y) + (float(sy) + 0.5) / float(SAMPLES))
					var from_centre := point.distance_to(centre)
					if from_centre <= radius:
						disc += 1.0
					if from_centre <= radius - OUTLINE:
						inner += 1.0
						if _in_glyph(kind, point):
							glyph += 1.0
			var samples := float(SAMPLES * SAMPLES)
			var colour := RIM.lerp(fill, inner / maxf(disc, 1.0)).lerp(INK, glyph / maxf(disc, 1.0))
			colour.a = disc / samples
			image.set_pixel(x, y, colour)
	return image


static func _in_glyph(kind: String, point: Vector2) -> bool:
	match kind:
		DRY:
			return point.distance_to(Vector2(32.0, 39.0)) <= 11.0 or _in_triangle(point, Vector2(32.0, 13.0), Vector2(21.5, 35.0), Vector2(42.5, 35.0))
		PROBLEM:
			return Rect2(28.0, 13.0, 8.0, 25.0).has_point(point) or point.distance_to(Vector2(32.0, 47.0)) <= 4.8
		READY:
			return _near_segment(point, Vector2(19.0, 33.0), Vector2(28.0, 43.0), 4.0) or _near_segment(point, Vector2(28.0, 43.0), Vector2(46.0, 22.0), 4.0)
	return false


static func _in_triangle(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (point - b).cross(a - b)
	var d2 := (point - c).cross(b - c)
	var d3 := (point - a).cross(c - a)
	var negative := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var positive := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (negative and positive)


static func _near_segment(point: Vector2, a: Vector2, b: Vector2, half_width: float) -> bool:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) <= half_width
