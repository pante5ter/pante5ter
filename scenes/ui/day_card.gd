class_name DayCard
extends PanelContainer

## At midnight a card says the day is over and what it brought, so days underground do not slip by unnoticed.

const SHOW_SECONDS: float = 4.5
const FADE_SECONDS: float = 0.8
const WIDTH: float = 560.0
## Below the alert banner, which owns the top of the screen.
const TOP: float = 150.0
const INK: Color = Color("EDEBE6")  # white
const GOLD: Color = Color("F2C46B")  # lamp_warm
const MUTED: Color = Color("B5B5B0")  # light_grey
const BACK: Color = Color("26272A")  # pot_black

## Set by the HUD so the card can stay out of a dialogue's way.
var hud: Hud
var _title: Label
var _summary: Label
var _next: Label
var _left: float = 0.0
var _sim: SimState
var _day: int = 0


func _ready() -> void:
	name = "DayCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(BACK, 0.92)
	style.border_color = GOLD
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16.0)
	add_theme_stylebox_override("panel", style)
	custom_minimum_size = Vector2(WIDTH, 0.0)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 4)
	add_child(rows)
	_title = _line(rows, 34, GOLD)
	_summary = _line(rows, 18, INK)
	_next = _line(rows, 15, MUTED)


func _line(parent: Container, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(WIDTH - 32.0, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color("1C1C1E"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label


## A dialogue owns the screen: the card and its countdown wait under it and come back when it closes.
func _process(delta: float) -> void:
	watch(Game.sim)
	visible = _left > 0.0 and not (hud != null and hud.is_dialogue_open())
	if not visible:
		return
	_left = maxf(_left - delta, 0.0)
	modulate.a = clampf(_left / FADE_SECONDS, 0.0, 1.0)


## A new day since the last look shows the card for the day just ended; a fresh game or a load only resets the count.
func watch(sim: SimState) -> void:
	var day := sim.clock.day()
	if sim != _sim:
		_sim = sim
		_day = day
		return
	if day <= _day:
		_day = day
		return
	_day = day
	# Jack went to bed during that day: the bedtime summary already told it.
	if sim.day.slept_at >= float(day - 1) * SimClock.GAME_SECONDS_PER_DAY:
		return
	show_for(sim, day - 1)


func show_for(sim: SimState, ended_day: int) -> void:
	_title.text = title(ended_day)
	_summary.text = summary(sim, ended_day)
	_next.text = "Начинается день %d" % (ended_day + 2)
	visible = true
	modulate.a = 1.0
	_left = SHOW_SECONDS
	reset_size()
	var screen := get_viewport_rect().size
	position = Vector2((screen.x - size.x) / 2.0, TOP)


func is_showing() -> bool:
	return visible and _left > 0.0


func is_waiting() -> bool:
	return _left > 0.0


static func title(ended_day: int) -> String:
	return "День %d окончен" % (ended_day + 1)


static func summary(sim: SimState, ended_day: int) -> String:
	var start := float(ended_day) * SimClock.GAME_SECONDS_PER_DAY
	var totals := MoneyLedger.totals(sim, start, start + SimClock.GAME_SECONDS_PER_DAY)
	if totals == Vector2i.ZERO:
		return "Денег не пришло и не ушло. На руках %s." % UiText.money(sim.economy.money)
	return "Заработано %s · потрачено %s · итог %s" % [UiText.money(totals.x), UiText.money(totals.y), PhoneFinance.signed(totals.x - totals.y)]
