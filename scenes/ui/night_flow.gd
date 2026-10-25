class_name NightFlow
extends Control

## Bedtime at home: the screen goes dark, the night runs in the sim, then the summary of the day and the
## morning briefing. A farm alarm wakes Jack instead, and Reggie asks what to do.

const FADE_SECONDS: float = 0.4
const DRIVE: int = 0
const LOOK: int = 1
const SLEEP_ON: int = 2
const ALARM_CHOICES: PackedStringArray = ["Ехать на ферму", "Посмотреть, что там", "Спать дальше — Реджи справится"]
const ALARM_REPLIES: PackedStringArray = ["Машина у двери. Поехали.", "Сейчас покажу. Ты пока не одевайся.", "Спи. Разберусь — расскажу утром."]

## Set by the HUD.
var hud: Hud
var card: DayReportCard
var _veil: ColorRect
var _page: int = 0
var _day_from: float = 0.0
var _night_from: float = 0.0
var _was_running: bool = false
var _alarm_pending: bool = false
var _alarm_choice: int = -1


func _ready() -> void:
	name = "NightFlow"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil = ColorRect.new()
	_veil.color = Color(0.03, 0.03, 0.05)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)
	card = DayReportCard.new()
	card.visible = false
	card.next_pressed.connect(_next)
	add_child(card)


func is_open() -> bool:
	return card.visible


func _process(_delta: float) -> void:
	if card.visible:
		var screen := get_viewport_rect().size
		card.position = ((screen - card.size) / 2.0).max(Vector2.ZERO)


## The bed calls this; a refusal is just a message.
func sleep() -> void:
	if is_open() or hud.is_dialogue_open():
		return
	var sim := Game.sim
	var refused := sim.day.can_sleep(sim.clock.elapsed_game_seconds)
	if not refused.is_empty():
		hud.show_message(UiText.error(refused))
		return
	var day_from := sim.day.day_started_at
	var result := sim.apply(SleepCommand.new())
	if not result.ok:
		hud.show_message(UiText.error(result.error))
		return
	if result.value >= 0:
		_alarm(sim.event_log.entries()[result.value])
		return
	_open(day_from, _first_sleep_since(sim, day_from))


## Bedtime of this night: the first time Jack lay down since he last woke (an alarm may have cut in).
static func _first_sleep_since(sim: SimState, day_from: float) -> float:
	for event: SimEvent in sim.event_log.of_type(EventLog.JACK_SLEPT):
		if event.game_time >= day_from:
			return event.game_time
	return sim.day.slept_at


func _alarm(event: SimEvent) -> void:
	_alarm_pending = true
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, alarm_line(event, Game.sim))]
	hud.play_dialogue(lines, ALARM_CHOICES)
	hud.dialogue_box.chosen.connect(_on_alarm_choice, CONNECT_ONE_SHOT)


static func alarm_line(event: SimEvent, sim: SimState) -> String:
	var at := UiText.clock(sim.clock).get_slice("· ", 1)
	if event.type == EventLog.INSPECTION_WARNED:
		return "%s. Джек, просыпайся. Сосед настучал — едет проверка. Свет я погашу сам, если успею. Едем?" % at
	return "%s. Джек, просыпайся. У контейнера «Молочные зубы» — в балаклавах, снимают клип. Едем туда или я сам?" % at


## Reggie answers first; the box closes on his line and only then Jack acts.
func _on_alarm_choice(index: int) -> void:
	_alarm_pending = false
	_alarm_choice = index
	hud.dialogue_finished.connect(_act_on_alarm, CONNECT_ONE_SHOT)
	var reply: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, ALARM_REPLIES[index])]
	hud.play_dialogue(reply)


func _act_on_alarm() -> void:
	match _alarm_choice:
		DRIVE:
			var result := Travel.go(DayCycle.FARM)
			if not result.ok:
				hud.show_message(UiText.error(result.error))
		LOOK:
			Travel.look_at(DayCycle.FARM)
		SLEEP_ON:
			sleep()


func is_waiting_for_alarm_choice() -> bool:
	return _alarm_pending


func _open(day_from: float, night_from: float) -> void:
	_day_from = day_from
	_night_from = night_from
	_was_running = true
	Game.is_running = false
	hud.close_actions()
	hud.phone.close()
	_page = 0
	_veil.modulate.a = 1.0
	hud.skip_news()
	_show_summary()


func _show_summary() -> void:
	var sim := Game.sim
	var sections: Array[Dictionary] = [{"heading": "", "lines": DayText.summary(sim, _day_from, _night_from)}]
	card.show_page(DayText.summary_title(sim, _day_from), sections, "Утро →")


func _show_briefing() -> void:
	var sim := Game.sim
	var sections: Array[Dictionary] = [
		{"heading": "За ночь", "lines": DayText.night(sim, _night_from, sim.clock.elapsed_game_seconds)},
		{"heading": "Сегодня", "lines": DayText.today(sim)},
	]
	var at_home := DayText.home_night(sim, _night_from, sim.clock.elapsed_game_seconds)
	if not at_home.is_empty():
		sections.insert(1, {"heading": "Ночь дома", "lines": at_home})
	card.show_page(DayText.briefing_title(sim), sections, "Начать день")


func _next() -> void:
	if _page == 0:
		_page = 1
		_show_briefing()
		return
	close()


func close() -> void:
	if not card.visible:
		return
	card.visible = false
	Game.is_running = _was_running
	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", 0.0, FADE_SECONDS)
	if hud.place != Game.sim.day.place:
		Travel.back_to_jack()
		return
	var woke_at_home := _home_night_since(_night_from)
	if woke_at_home != null and hud.place == DayCycle.HOME:
		hud.play_dialogue(Vivienne.morning_lines(woke_at_home))


static func _home_night_since(from: float) -> SimEvent:
	var nights := Game.sim.event_log.of_type(EventLog.HOME_NIGHT)
	if nights.is_empty() or nights[nights.size() - 1].game_time < from:
		return null
	return nights[nights.size() - 1]


## Space or Enter turns the page.
func handle_key(key: InputEventKey) -> bool:
	if not card.visible:
		return false
	if key.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_next()
	return true
