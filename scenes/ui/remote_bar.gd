class_name RemoteBar
extends PanelContainer

## Shown while the view is somewhere Jack is not (a night alarm, a loaded save): drive here, go back to
## Jack, or, at night, sleep on.

const WIDTH: float = 640.0
const BOTTOM: float = 70.0

## Set by the HUD.
var hud: Hud
var text_label: Label
var drive_button: Button
var back_button: Button
var sleep_button: Button


func _ready() -> void:
	name = "RemoteBar"
	visible = false
	add_theme_stylebox_override("panel", UiStyle.panel())
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = -BOTTOM - 76.0
	offset_bottom = -BOTTOM
	var rows := VBoxContainer.new()
	add_child(rows)
	text_label = UiStyle.label("", 15, UiStyle.ACCENT)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(text_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	rows.add_child(buttons)
	drive_button = UiStyle.button("Поехать сюда", _drive_here)
	back_button = UiStyle.button("Вернуться к Джеку", Travel.back_to_jack)
	sleep_button = UiStyle.button("Спать дальше", _sleep_on)
	for button: Button in [drive_button, back_button, sleep_button]:
		buttons.add_child(button)


func _process(_delta: float) -> void:
	var sim := Game.sim
	var away := not hud.place.is_empty() and (sim.day.place != hud.place or sim.day.travelling())
	visible = away and not hud.is_dialogue_open() and not hud.night.is_open()
	if not visible:
		return
	text_label.text = "Вы смотрите: %s. Джека здесь нет — %s." % [Travel.NAMES.get(hud.place, hud.place), UiText.where_is_jack(sim)]
	drive_button.disabled = sim.day.travelling() or SceneRouter.is_busy()
	sleep_button.visible = sim.day.can_sleep(sim.clock.elapsed_game_seconds).is_empty()


func _drive_here() -> void:
	var result := Travel.go(hud.place)
	if not result.ok:
		hud.show_message(UiText.error(result.error))


func _sleep_on() -> void:
	hud.night.sleep()
