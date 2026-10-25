class_name PhoneMap
extends Control

## The «Карта» app: a schematic of the estate with what needs attention marked on it.
## World coordinates mirror the field layout in tools/scene_gen/gen_scenes.py.

const WORLD: Rect2 = Rect2(-86.0, -66.0, 172.0, 132.0)
const ROAD_Z: float = 44.0
const MANOR: Rect2 = Rect2(-64.3, -41.5, 26.6, 11.0)
const WHEAT: Rect2 = Rect2(14.0, -27.0, 43.0, 58.0)
const COTTAGE: Rect2 = Rect2(16.2, 51.0, 7.6, 6.1)
const CONTAINER: Vector2 = Vector2(61.0, 2.0)
const PARCEL: Vector2 = Vector2(63.4, 6.2)
const RAIDERS: Vector2 = Vector2(64.5, 13.0)
const DROP_POINT: Vector2 = Vector2(-72.0, 47.6)
const INSPECTOR_ROAD: Vector2 = Vector2(78.0, 44.0)
## grass_mid, path_dirt, wheat, cotswold, container_red, police_blue
const GRASS: Color = Color("56724A")
const ROAD: Color = Color("7D6650")
const WHEAT_COLOR: Color = Color("D2BE84")
const HOUSE: Color = Color("C9B27E")
const CONTAINER_COLOR: Color = Color("A14A35")
const POLICE: Color = Color("2F5D9E")
const CAPTIONS: Array[String] = ["Эшкомб-холл", "Пшеница", "Контейнер", "Дорога"]
## Bottom-left of each caption in world coordinates, before it is pushed clear of the others.
const CAPTION_ANCHORS: Array[Vector2] = [Vector2(-64.0, -44.0), Vector2(20.0, 0.0), Vector2(52.0, 16.0), Vector2(-80.0, ROAD_Z - 3.0)]
const CAPTION_MARGIN: float = 2.0
const CAPTION_TRIES: int = 12

var _sim: SimState
var _origin: Vector2 = Vector2.ZERO
var _scale: float = 1.0


class Spot:
	var title: String
	var where: String
	var colour: Color
	var world: Vector2

	func _init(spot_title: String, spot_where: String, spot_colour: Color, at: Vector2) -> void:
		title = spot_title
		where = spot_where
		colour = spot_colour
		world = at


static func fill(box: VBoxContainer, sim: SimState) -> void:
	var map := PhoneMap.new()
	map.name = "EstateMap"
	map._sim = sim
	map.custom_minimum_size = Vector2(0.0, 236.0)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(map)
	for spot: Spot in spots(sim):
		var line := PhoneKit.card(box, spot.colour)
		line.add_child(PhoneKit.label(spot.title, PhoneKit.BODY_SIZE))
		line.add_child(PhoneKit.label(spot.where, PhoneKit.SMALL_SIZE, PhoneKit.MUTED))


## Everything worth walking to right now, plus the fixed places people ask about.
static func spots(sim: SimState) -> Array[Spot]:
	var result: Array[Spot] = []
	if sim.raids.pending:
		result.append(Spot.new("Гопники", "У контейнера, на краю пшеничного поля", PhoneKit.DANGER, RAIDERS))
	if not sim.supplies.parcel().is_empty():
		result.append(Spot.new("Посылка", "Ящик у двери контейнера", PhoneKit.GOLD, PARCEL))
	if sim.suspicion.inspection_pending():
		result.append(Spot.new("Проверка", "Приедет по дороге с востока к контейнеру", POLICE, INSPECTOR_ROAD))
	result.append(Spot.new("Точка передачи", "Лэй-бай у деревни, далеко от фермы: курьеры ждут здесь, товар им привозит Реджи", PhoneKit.INFO, DROP_POINT))
	return result


func _draw() -> void:
	_scale = minf(size.x / WORLD.size.x, size.y / WORLD.size.y)
	_origin = (size - WORLD.size * _scale) / 2.0
	draw_style_box(PhoneKit.rounded(GRASS, 10, 0.0), Rect2(_origin, WORLD.size * _scale))
	var road_width := maxf(3.0 * _scale, 3.0)
	draw_line(_to_map(Vector2(-83.0, ROAD_Z)), _to_map(Vector2(83.0, ROAD_Z)), ROAD, road_width)
	draw_line(_to_map(Vector2(-51.0, ROAD_Z)), _to_map(Vector2(-51.0, -20.0)), ROAD, road_width * 0.7)
	draw_line(_to_map(Vector2(61.0, ROAD_Z)), _to_map(Vector2(61.0, 8.0)), ROAD, road_width * 0.7)
	draw_rect(_rect(WHEAT), WHEAT_COLOR)
	draw_rect(_rect(MANOR), HOUSE)
	draw_rect(_rect(COTTAGE), HOUSE)
	var box_at := _to_map(CONTAINER)
	draw_rect(Rect2(box_at - Vector2(4.0, 7.0), Vector2(8.0, 14.0)), CONTAINER_COLOR)
	var font := get_theme_default_font()
	var boxes := caption_boxes(size, font)
	for index: int in boxes.size():
		_caption(boxes[index].position + Vector2(0.0, font.get_ascent(PhoneKit.SMALL_SIZE)), CAPTIONS[index])
	if _sim == null:
		return
	for spot: Spot in spots(_sim):
		var at := _to_map(spot.world)
		draw_circle(at, 8.0, PhoneKit.BEZEL)
		draw_circle(at, 6.0, spot.colour)


## Where each of CAPTIONS goes on a map of this size: inside the map, none on top of another.
static func caption_boxes(map_size: Vector2, font: Font) -> Array[Rect2]:
	var scale := minf(map_size.x / WORLD.size.x, map_size.y / WORLD.size.y)
	var origin := (map_size - WORLD.size * scale) / 2.0
	var bounds := Rect2(Vector2.ZERO, map_size).grow(-CAPTION_MARGIN)
	var boxes: Array[Rect2] = []
	for index: int in CAPTIONS.size():
		var text_size := font.get_string_size(CAPTIONS[index], HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.SMALL_SIZE)
		var at := origin + (CAPTION_ANCHORS[index] - WORLD.position) * scale
		var box := _clamped(Rect2(at - Vector2(0.0, text_size.y), text_size), bounds)
		var tries := 0
		while _overlaps(box, boxes) and tries < CAPTION_TRIES:
			box.position.y += text_size.y + CAPTION_MARGIN
			if box.end.y > bounds.end.y:
				box.position.y = bounds.position.y + float(tries) * (text_size.y + CAPTION_MARGIN)
			box = _clamped(box, bounds)
			tries += 1
		boxes.append(box)
	return boxes


static func _clamped(box: Rect2, bounds: Rect2) -> Rect2:
	box.position.x = clampf(box.position.x, bounds.position.x, maxf(bounds.end.x - box.size.x, bounds.position.x))
	box.position.y = clampf(box.position.y, bounds.position.y, maxf(bounds.end.y - box.size.y, bounds.position.y))
	return box


static func _overlaps(box: Rect2, placed: Array[Rect2]) -> bool:
	for other: Rect2 in placed:
		if box.intersects(other):
			return true
	return false


func _caption(at: Vector2, text: String) -> void:
	var font := get_theme_default_font()
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.SMALL_SIZE, 4, PhoneKit.BEZEL)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.SMALL_SIZE, PhoneKit.TEXT)


func _to_map(world: Vector2) -> Vector2:
	return _origin + (world - WORLD.position) * _scale


func _rect(world: Rect2) -> Rect2:
	return Rect2(_to_map(world.position), world.size * _scale)
