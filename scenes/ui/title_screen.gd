class_name TitleScreen
extends Control

## Cold English dusk over a wheat field; one warm lamp in the container. Then the deal begins.

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const FADE_IN: float = 0.9
const LAMP_PERIOD: float = 2.8

const SKY_TOP: Color = Color("232A33")
const SKY_MID: Color = Color("5E6A7A")
const SKY_LOW: Color = Color("6E7480")
const FIELD: Color = Color("3E5A3A")
const HEDGE: Color = Color("2F4A33")
const CONTAINER: Color = Color("3A3A3C")
const LAMP: Color = Color("F2C46B")
const INK: Color = Color("EDEBE6")
const MUTED: Color = Color("B5B5B0")
const PANEL: Color = Color(0.07, 0.06, 0.05, 0.88)

var _canvas: Control
var _lamp_glow: ColorRect
var _title: Label
var _tag: Label
var _buttons: VBoxContainer
var _continue_btn: Button
var _hint: Label
var _busy: bool = false
var _lamp_phase: float = 0.0


func _ready() -> void:
	name = "TitleScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Game.is_running = false
	_build()
	_refresh_continue()
	_play_intro()


func _process(delta: float) -> void:
	_lamp_phase += delta
	if _lamp_glow != null:
		var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_lamp_phase * TAU / LAMP_PERIOD))
		_lamp_glow.modulate.a = pulse


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_new_game()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE:
		get_tree().quit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_backdrop)
	add_child(_canvas)
	resized.connect(_canvas.queue_redraw)

	_lamp_glow = ColorRect.new()
	_lamp_glow.color = Color(LAMP, 0.35)
	_lamp_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lamp_glow)

	var centre := VBoxContainer.new()
	centre.set_anchors_preset(Control.PRESET_CENTER)
	centre.grow_horizontal = Control.GROW_DIRECTION_BOTH
	centre.grow_vertical = Control.GROW_DIRECTION_BOTH
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", 14)
	centre.custom_minimum_size = Vector2(520.0, 0.0)
	add_child(centre)

	_title = UiStyle.label("OLD MONEY", 64, INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_title)

	var rule := ColorRect.new()
	rule.color = LAMP
	rule.custom_minimum_size = Vector2(220.0, 2.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centre.add_child(rule)

	_tag = UiStyle.label("Тихая империя под полями английских лордов", 18, MUTED)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_tag)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	centre.add_child(_buttons)

	_buttons.add_child(_menu_button("Новая игра", _new_game))
	_continue_btn = _menu_button("Продолжить", _continue_game)
	_buttons.add_child(_continue_btn)
	_buttons.add_child(_menu_button("Выйти", _quit))

	_hint = UiStyle.label("Enter — новая игра · Esc — выход", 13, Color(MUTED, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_hint)

	_place_lamp()
	resized.connect(_place_lamp)


func _menu_button(text: String, on_pressed: Callable) -> Button:
	var btn := UiStyle.button(text, on_pressed)
	btn.custom_minimum_size = Vector2(260.0, 40.0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL
	normal.border_color = Color(LAMP, 0.35)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.set_content_margin_all(10.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.11, 0.09, 0.95)
	hover.border_color = LAMP
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(PANEL, 0.45)
	disabled.border_color = Color(MUTED, 0.2)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", LAMP)
	btn.add_theme_color_override("font_pressed_color", LAMP)
	btn.add_theme_color_override("font_disabled_color", Color(MUTED, 0.45))
	return btn


func _place_lamp() -> void:
	var screen := size
	if screen.x < 1.0 or screen.y < 1.0:
		return
	var glow := mini(screen.x, screen.y) * 0.28
	_lamp_glow.size = Vector2(glow, glow)
	_lamp_glow.position = Vector2(screen.x * 0.72 - glow * 0.5, screen.y * 0.58 - glow * 0.5)
	_canvas.queue_redraw()


func _draw_backdrop() -> void:
	var screen := size
	if screen.x < 1.0 or screen.y < 1.0:
		return
	var horizon := screen.y * 0.62
	_canvas.draw_rect(Rect2(Vector2.ZERO, Vector2(screen.x, horizon * 0.55)), SKY_TOP, true)
	_canvas.draw_rect(Rect2(0.0, horizon * 0.45, screen.x, horizon * 0.35), SKY_MID, true)
	_canvas.draw_rect(Rect2(0.0, horizon * 0.7, screen.x, horizon * 0.3), SKY_LOW, true)
	_canvas.draw_rect(Rect2(0.0, horizon, screen.x, screen.y - horizon), FIELD, true)
	# Hedge line
	_canvas.draw_rect(Rect2(0.0, horizon - 10.0, screen.x, 14.0), HEDGE, true)
	# Wheat stems
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i: int in 90:
		var x := rng.randf() * screen.x
		var h := 18.0 + rng.randf() * 36.0
		var top := horizon + 8.0 + rng.randf() * 20.0
		_canvas.draw_line(Vector2(x, top + h), Vector2(x + rng.randf_range(-3.0, 3.0), top), Color(HEDGE, 0.85), 1.2)
	# Shipping container on the field edge, slit of warm light
	var box := Rect2(screen.x * 0.66, horizon - 38.0, screen.x * 0.16, 48.0)
	_canvas.draw_rect(box, CONTAINER, true)
	_canvas.draw_rect(Rect2(box.position.x + box.size.x * 0.42, box.position.y + 10.0, 4.0, box.size.y - 16.0), LAMP, true)
	# Soft rain strokes
	rng.seed = 7
	for i: int in 40:
		var x := rng.randf() * screen.x
		var y := rng.randf() * horizon
		_canvas.draw_line(Vector2(x, y), Vector2(x - 2.0, y + 10.0), Color(INK, 0.08), 1.0)


func _play_intro() -> void:
	_title.modulate.a = 0.0
	_tag.modulate.a = 0.0
	_buttons.modulate.a = 0.0
	_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_title, "modulate:a", 1.0, FADE_IN)
	tween.tween_property(_tag, "modulate:a", 1.0, FADE_IN).set_delay(0.25)
	tween.tween_property(_buttons, "modulate:a", 1.0, FADE_IN).set_delay(0.45)
	tween.tween_property(_hint, "modulate:a", 1.0, FADE_IN).set_delay(0.65)


func _refresh_continue() -> void:
	_continue_btn.disabled = not FileAccess.file_exists(Game.save_path)


func _new_game() -> void:
	if _busy or SceneRouter.is_busy():
		return
	_busy = true
	Game.new_game(int(Time.get_unix_time_from_system()), true)
	SceneRouter.go_to(FIELD_SCENE, "start")


func _continue_game() -> void:
	if _busy or SceneRouter.is_busy() or _continue_btn.disabled:
		return
	if Game.load_game() != OK:
		_refresh_continue()
		return
	_busy = true
	Travel.back_to_jack()


func _quit() -> void:
	get_tree().quit()
