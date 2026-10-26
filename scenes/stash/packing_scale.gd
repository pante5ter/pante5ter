class_name PackingScale
extends Control

## «Весы»: hold to pour, let go on the target weight. The game clock stands still meanwhile.
## The round only reports how far each bag missed; the bench sends that to the sim.

signal finished(misses: Array[float])
signal auto_chosen
signal cancelled

enum Phase { WAITING, POURING, SETTLING, SUMMARY }

const SETTLE_SECONDS: float = 1.1
const NEEDLE_EASE: float = 18.0
## Indexed by HandPacking.Grade: perfect, good, fair, sloppy.
const GRADE_TEXTS: Array[String] = ["ИДЕАЛЬНО", "Точно", "Сойдёт", "Мимо"]
const GRADE_COLORS: Array[Color] = [ScaleDial.PERFECT_COLOR, UiStyle.ACCENT, Color(0.85, 0.75, 0.6), Color(1.0, 0.5, 0.4)]
const GRADE_TONES: Array[float] = [1046.5, 784.0, 523.3, 220.0]

var phase: Phase = Phase.WAITING
var bag: int = 0
var bags: int = 0
var grams: float = 0.0
var streak: int = 0
var best_streak: int = 0
var misses: Array[float] = []

var _def: HandPackingDef
var _seed: int = 0
var _units: int = 0
var _settle_left: float = 0.0
var _was_running: bool = false
var _closed: bool = false
var _dial: ScaleDial
var _readout: Label
var _bag_label: Label
var _combo_label: Label
var _hint: Label
var _stamp: Label
var _summary: Label
var _play_buttons: HBoxContainer
var _done_button: Button
var _pour_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _stamp_tween: Tween


func open(def: HandPackingDef, seed_value: int, bag_count: int, units: int) -> void:
	_def = def
	_seed = seed_value
	bags = bag_count
	_units = units
	_was_running = Game.is_running
	Game.is_running = false
	_build()
	_show_bag()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.custom_minimum_size = Vector2(440.0, 0.0)
	panel.add_child(rows)
	rows.add_child(UiStyle.label("Весы — фасуем сами", 20, UiStyle.ACCENT))
	_hint = UiStyle.label("Зажми ЛКМ или Пробел — сыплется. Отпусти ровно на %s г." % _grams_text(_def.target_grams), 14, UiStyle.MUTED)
	rows.add_child(_hint)
	var status := HBoxContainer.new()
	_bag_label = UiStyle.label("", 15)
	_bag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(_bag_label)
	_combo_label = UiStyle.label("", 15, ScaleDial.PERFECT_COLOR)
	status.add_child(_combo_label)
	rows.add_child(status)
	_dial = ScaleDial.new()
	_dial.def = _def
	rows.add_child(_dial)
	_stamp = UiStyle.label("", 40)
	_stamp.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp.modulate.a = 0.0
	_dial.add_child(_stamp)
	_readout = UiStyle.label("", 26)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_readout)
	_summary = UiStyle.label("", 16)
	_summary.visible = false
	rows.add_child(_summary)
	_play_buttons = HBoxContainer.new()
	_play_buttons.add_theme_constant_override("separation", 8)
	_play_buttons.add_child(UiStyle.button("Фасовать автоматически", choose_auto))
	_play_buttons.add_child(UiStyle.button("Отмена  [Esc]", cancel))
	rows.add_child(_play_buttons)
	_done_button = UiStyle.button("Готово — фасуем  [Пробел]", confirm)
	_done_button.visible = false
	rows.add_child(_done_button)
	_pour_player = AudioStreamPlayer.new()
	_pour_player.stream = ScaleSounds.pour()
	add_child(_pour_player)
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)


func _show_bag() -> void:
	grams = 0.0
	phase = Phase.WAITING
	_bag_label.text = "Пакет %d из %d" % [bag + 1, bags]
	_combo_label.text = "Серия ×%d" % streak if streak >= 2 else ""
	_readout.text = "%s г" % _grams_text(0.0)


func current_fill_seconds() -> float:
	return HandPacking.fill_seconds(_def, _seed, bag)


func press() -> void:
	if phase != Phase.WAITING or _closed:
		return
	phase = Phase.POURING
	_pour_player.play()


func release() -> void:
	if phase == Phase.POURING:
		_stop_bag()


func _process(delta: float) -> void:
	if _def == null or _closed:
		return
	if phase == Phase.POURING:
		grams += _def.target_grams / maxf(current_fill_seconds(), 0.05) * delta
		_readout.text = "%s г" % _grams_text(grams)
		if grams >= _def.scale_max_grams:
			grams = _def.scale_max_grams
			_stop_bag()
	elif phase == Phase.SETTLING:
		_settle_left -= delta
		if _settle_left <= 0.0:
			_next_bag()
	_dial.shown_grams = lerpf(_dial.shown_grams, grams, clampf(delta * NEEDLE_EASE, 0.0, 1.0))


func _stop_bag() -> void:
	_pour_player.stop()
	var miss := grams - _def.target_grams
	misses.append(miss)
	var grade := HandPacking.grade(_def, miss)
	streak = streak + 1 if grade == HandPacking.Grade.PERFECT else 0
	best_streak = maxi(best_streak, streak)
	_readout.text = "%s г  (%s)" % [_grams_text(grams), _miss_text(miss)]
	_combo_label.text = "Серия ×%d" % streak if streak >= 2 else ""
	_play_stamp(grade, grams >= _def.scale_max_grams)
	phase = Phase.SETTLING
	_settle_left = SETTLE_SECONDS


func _next_bag() -> void:
	bag += 1
	if bag < bags:
		_show_bag()
		return
	phase = Phase.SUMMARY
	var accuracy := HandPacking.accuracy(_def, misses)
	var bonus := HandPacking.quality_bonus(_def, misses)
	var verdict := "качество партии %+d" % bonus if bonus != 0 else "без надбавки"
	_summary.text = "Точность %d%% · лучшая серия %d · %s (%d шт.)" % [roundi(maxf(accuracy, 0.0) * 100.0), best_streak, verdict, _units]
	_summary.visible = true
	_hint.text = "Ровные пакеты — дороже товар." if bonus > 0 else "Рука дрогнула — в следующий раз ровнее."
	_play_buttons.visible = false
	_done_button.visible = true


func _play_stamp(grade: HandPacking.Grade, spilled: bool) -> void:
	_stamp.text = "Просыпал!" if spilled else GRADE_TEXTS[grade]
	_stamp.add_theme_color_override("font_color", GRADE_COLORS[grade])
	_stamp.reset_size()
	_stamp.pivot_offset = _stamp.size * 0.5
	_stamp.position = (_dial.size - _stamp.size) * Vector2(0.5, 0.32)
	_stamp.rotation = -0.2 if grade == HandPacking.Grade.PERFECT else 0.0
	_sfx_player.stream = ScaleSounds.thud() if grade == HandPacking.Grade.PERFECT else ScaleSounds.blip(GRADE_TONES[grade])
	_sfx_player.play()
	if _stamp_tween != null:
		_stamp_tween.kill()
	_stamp.modulate.a = 1.0
	_stamp.scale = Vector2.ONE * (2.2 if grade == HandPacking.Grade.PERFECT else 1.4)
	_stamp_tween = create_tween()
	_stamp_tween.tween_property(_stamp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_interval(0.5)
	_stamp_tween.tween_property(_stamp, "modulate:a", 0.0, 0.3)


func confirm() -> void:
	if phase != Phase.SUMMARY or _closed:
		return
	var result := misses.duplicate()
	_close()
	finished.emit(result)


func choose_auto() -> void:
	if _closed or phase == Phase.SUMMARY:
		return
	_close()
	auto_chosen.emit()


func cancel() -> void:
	if _closed:
		return
	_close()
	cancelled.emit()


func is_closed() -> bool:
	return _closed


func _close() -> void:
	_closed = true
	_pour_player.stop()
	Game.is_running = _was_running
	visible = false
	queue_free()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		press()
	else:
		release()
	accept_event()


## Keys the HUD would take otherwise (phone, speed, save) wait until the scale is put away.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or _closed or key.echo:
		return
	match key.physical_keycode:
		KEY_SPACE:
			if phase == Phase.SUMMARY:
				if key.pressed:
					confirm()
			elif key.pressed:
				press()
			else:
				release()
		KEY_ENTER, KEY_KP_ENTER:
			if key.pressed:
				confirm()
		KEY_ESCAPE:
			if key.pressed and phase == Phase.SUMMARY:
				confirm()
			elif key.pressed:
				cancel()
		KEY_TAB, KEY_1, KEY_2, KEY_3, KEY_F5, KEY_F9, KEY_HOME:
			pass
		_:
			return
	get_viewport().set_input_as_handled()


static func _grams_text(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


static func _miss_text(miss: float) -> String:
	return "%s%s г" % ["+" if miss >= 0.0 else "−", _grams_text(absf(miss))]
