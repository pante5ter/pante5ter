class_name PhoneHome
extends VBoxContainer

## The phone's home screen: a big clock, the app grid with badges and Finn's latest word.

signal app_chosen(app: int)

const COLUMNS: int = 3

var _clock: Label
var _date: Label
var _icons: Array[PhoneAppIcon] = []
var _finn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 4)
	_clock = PhoneKit.label("", 44)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_clock)
	_date = PhoneKit.label("", PhoneKit.SMALL_SIZE, PhoneKit.MUTED)
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_date)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for app: int in Phone.APP_TITLES.size():
		var icon := PhoneAppIcon.make(app, Phone.APP_TITLES[app], Phone.APP_GLYPHS[app], Phone.APP_COLORS[app])
		icon.name = "App%d" % app
		icon.pressed.connect(app_chosen.emit.bind(app))
		grid.add_child(icon)
		_icons.append(icon)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	_finn = Button.new()
	_finn.name = "FinnCard"
	_finn.focus_mode = Control.FOCUS_NONE
	_finn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_finn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_finn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_finn.custom_minimum_size = Vector2(0.0, 64.0)
	_finn.add_theme_font_size_override("font_size", PhoneKit.SMALL_SIZE + 1)
	var card := PhoneKit.rounded(PhoneKit.CARD, 12, 10.0)
	card.border_color = PhoneKit.GOLD
	card.border_width_left = 4
	_finn.add_theme_stylebox_override("normal", card)
	_finn.add_theme_stylebox_override("hover", PhoneKit.rounded(PhoneKit.CARD.lightened(0.08), 12, 10.0))
	_finn.add_theme_stylebox_override("pressed", card)
	_finn.add_theme_color_override("font_color", PhoneKit.TEXT)
	_finn.add_theme_color_override("font_hover_color", PhoneKit.TEXT)
	_finn.pressed.connect(app_chosen.emit.bind(Phone.APP_MESSAGES))
	add_child(_finn)


func icon(app: int) -> PhoneAppIcon:
	return _icons[app]


func refresh(sim: SimState, underground: bool, unread: int) -> void:
	_clock.text = PhoneNews.time_of_day(sim.clock.elapsed_game_seconds)
	_date.text = "День %d · поместье Эшкомб" % (sim.clock.day() + 1)
	for app_icon: PhoneAppIcon in _icons:
		app_icon.badge = badge(app_icon.app, sim, unread)
	_finn.text = "%s: %s" % [UiText.FINN, _first_sentence(UiText.objective(sim, underground))]


## Red counts on the icons; "!" where something needs a look rather than a number.
static func badge(app: int, sim: SimState, unread: int) -> String:
	match app:
		Phone.APP_CALLS:
			return _count(sim.orders.with_status(Order.Status.OFFERED).size())
		Phone.APP_MESSAGES:
			return _count(unread)
		Phone.APP_STOCK:
			return "1" if not sim.supplies.parcel().is_empty() else ""
		Phone.APP_PEOPLE:
			return "!" if sim.helper.exists() and sim.helper.wage_debt > 0 else ""
		Phone.APP_EMPIRE:
			return "!" if sim.rent.missed > 0 or sim.suspicion.inspection_pending() else ""
		Phone.APP_MAP:
			return "!" if sim.raids.pending else ""
	return ""


static func _count(value: int) -> String:
	if value <= 0:
		return ""
	return str(value) if value < 10 else "9+"


## The home card is a teaser; the whole message is one tap away.
static func _first_sentence(text: String) -> String:
	var stop := text.find(". ")
	return text if stop < 0 else text.substr(0, stop + 1)
