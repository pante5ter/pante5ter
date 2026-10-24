class_name PhoneAppView
extends VBoxContainer

## One app filling the phone screen: a «‹ Домой» header in the app's colour and content that scrolls.

signal home_requested

var _title: Label
var _strip: ColorRect
var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", 6)
	var header := HBoxContainer.new()
	var back_button := PhoneKit.secondary("‹ Домой", home_requested.emit)
	back_button.name = "Back"
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_button.custom_minimum_size = Vector2(96.0, 32.0)
	header.add_child(back_button)
	_title = PhoneKit.label("", 20)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_title)
	var balance := Control.new()
	balance.custom_minimum_size = Vector2(40.0, 0.0)
	header.add_child(balance)
	add_child(header)
	_strip = ColorRect.new()
	_strip.custom_minimum_size = Vector2(0.0, 3.0)
	add_child(_strip)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)


func show_app(title: String, colour: Color) -> void:
	_title.text = title
	_strip.color = colour
	_scroll.scroll_vertical = 0


## Takes a freshly built screen; keeps the old one (and any press in progress) if nothing changed.
func fill(fresh: VBoxContainer) -> void:
	UiRefresh.swap_if_changed(_content, fresh)
