class_name PauseMenu
extends PanelContainer

const CONTROLS_TEXT: String = "Управление\n\nЛКМ — идти / выбрать действие\nЗажать ЛКМ и тянуть — двигать камеру\nWASD — двигать камеру\nКолесо — приблизить / отдалить\nQ / E — повернуть камеру\nTab — телефон (магазин, склад, империя)\nКомпьютер на плантации — звонки, заказы, курьеры\n1 / 2 / 3 — скорость времени x1 / x2 / x4\nF5 / F9 — быстрое сохранение / загрузка\nEsc — это меню"

signal message(text: String)
signal forks_requested

var _controls: Label
var _was_running: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UiStyle.panel())
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(340.0, 0.0)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)
	rows.add_child(UiStyle.label("Пауза", 20, UiStyle.ACCENT))
	rows.add_child(UiStyle.button("Продолжить", close))
	rows.add_child(UiStyle.button("Сохранить", _save))
	rows.add_child(UiStyle.button("Загрузить", _load))
	rows.add_child(UiStyle.button("Развилки", _show_forks))
	rows.add_child(UiStyle.button("Управление", _toggle_controls))
	rows.add_child(UiStyle.button("Выйти из игры", _quit))
	_controls = UiStyle.label(CONTROLS_TEXT, 14, UiStyle.MUTED)
	_controls.visible = false
	rows.add_child(_controls)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_was_running = Game.is_running
	Game.is_running = false
	visible = true
	reset_size()
	position = (get_viewport_rect().size - size) / 2.0


func close() -> void:
	if not visible:
		return
	visible = false
	Game.is_running = _was_running


func _save() -> void:
	message.emit("Игра сохранена." if Game.save_game() == OK else "Не удалось сохранить игру.")
	close()


func _load() -> void:
	message.emit("Игра загружена." if Game.load_game() == OK else "Сохранения нет или оно повреждено.")
	close()


## The menu steps aside but time stays stopped while the forks are open.
func _show_forks() -> void:
	visible = false
	forks_requested.emit()


func resume() -> void:
	Game.is_running = _was_running


func _toggle_controls() -> void:
	_controls.visible = not _controls.visible
	reset_size()


func _quit() -> void:
	get_tree().quit()
