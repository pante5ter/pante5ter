class_name PhoneStatusBar
extends HBoxContainer

var _time: Label
var _day: Label
var _money: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_time = PhoneKit.label("", PhoneKit.SMALL_SIZE + 1)
	_day = PhoneKit.label("", PhoneKit.SMALL_SIZE, PhoneKit.MUTED)
	_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money = PhoneKit.label("", PhoneKit.SMALL_SIZE + 1, PhoneKit.GOLD)
	_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label: Label in [_time, _day, _money]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(label)


func refresh(sim: SimState) -> void:
	_time.text = PhoneNews.time_of_day(sim.clock.elapsed_game_seconds)
	_day.text = "День %d" % (sim.clock.day() + 1)
	_money.text = UiText.money(sim.economy.money)
