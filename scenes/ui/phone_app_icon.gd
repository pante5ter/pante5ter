class_name PhoneAppIcon
extends Button

## A home-screen app: coloured tile with a pictogram, the name underneath and a red count badge.

const TILE: float = 62.0
const ICON_SIZE: Vector2 = Vector2(92.0, 96.0)

var app: int = 0
var glyph: String = ""
var tile_color: Color = Color.WHITE
var title: String = ""
var badge: String = "":
	set(value):
		if value != badge:
			badge = value
			queue_redraw()


static func make(app_id: int, app_title: String, app_glyph: String, color: Color) -> PhoneAppIcon:
	var icon := PhoneAppIcon.new()
	icon.app = app_id
	icon.title = app_title
	icon.glyph = app_glyph
	icon.tile_color = color
	icon.tooltip_text = app_title
	return icon


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = ICON_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var tile := Rect2(Vector2((size.x - TILE) / 2.0, 4.0), Vector2(TILE, TILE))
	var fill := tile_color.lightened(0.1) if is_hovered() else tile_color
	draw_style_box(PhoneKit.rounded(fill, 16, 0.0), tile)
	var ink := PhoneKit.INK if tile_color.get_luminance() > 0.5 else PhoneKit.TEXT
	PhoneGlyphs.draw(self, glyph, tile.grow(-14.0), ink, fill)
	var font := get_theme_default_font()
	var text_y := tile.end.y + 20.0
	draw_string(font, Vector2(0.0, text_y), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, PhoneKit.SMALL_SIZE + 1, PhoneKit.TEXT)
	if badge.is_empty():
		return
	var centre := Vector2(tile.end.x - 4.0, tile.position.y + 4.0)
	var radius := 12.0 if badge.length() < 2 else 14.0
	draw_circle(centre, radius + 2.0, PhoneKit.SCREEN)
	draw_circle(centre, radius, PhoneKit.DANGER)
	draw_string(font, centre + Vector2(-radius, 5.0), badge, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, PhoneKit.SMALL_SIZE, PhoneKit.TEXT)
