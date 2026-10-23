class_name Hud
extends CanvasLayer

const MESSAGE_SECONDS: float = 4.0
const MESSAGE_FADE_SECONDS: float = 0.6
const HOVER_OFFSET: Vector2 = Vector2(18.0, 14.0)

@export var money_label: Label
@export var time_label: Label
@export var stock_label: Label
@export var worker_label: Label
@export var objective_label: Label
@export var message_label: Label
@export var hover_label: Label

var _message_left: float = 0.0
var _watched_sim: SimState
var _seen_events: int = 0


func _ready() -> void:
	message_label.modulate.a = 0.0
	hover_label.visible = false


func _process(delta: float) -> void:
	var sim := Game.sim
	money_label.text = UiText.money(sim.economy.money)
	time_label.text = UiText.clock(sim.clock)
	stock_label.text = "Урожай на руках: %d шт." % sim.inventory.count()
	worker_label.text = UiText.worker_status(sim.workers)
	objective_label.text = "Цель: " + UiText.objective(sim)
	_announce_new_events(sim)
	_message_left = maxf(_message_left - delta, 0.0)
	message_label.modulate.a = clampf(_message_left / MESSAGE_FADE_SECONDS, 0.0, 1.0)
	if hover_label.visible:
		hover_label.position = hover_label.get_viewport().get_mouse_position() + HOVER_OFFSET


func _announce_new_events(sim: SimState) -> void:
	if sim != _watched_sim:
		_watched_sim = sim
		_seen_events = sim.event_log.size()
		return
	for event: SimEvent in sim.event_log.since(_seen_events):
		var text := UiText.announcement(event, sim)
		if not text.is_empty():
			show_message(text)
	_seen_events = sim.event_log.size()


func show_message(text: String) -> void:
	message_label.text = text
	_message_left = MESSAGE_SECONDS


func set_hover(text: String) -> void:
	hover_label.text = text
	hover_label.visible = not text.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_F5:
		show_message("Игра сохранена." if Game.save_game() == OK else "Не удалось сохранить игру.")
	elif key.physical_keycode == KEY_F9:
		show_message("Игра загружена." if Game.load_game() == OK else "Сохранения нет или оно повреждено.")
