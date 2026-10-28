class_name ClimateControls
extends RefCounted

## The bunker's air on the computer's «Ферма» tab: the sensor readings, the ventilation switch and the sensor to buy.

const FARM_TAB: String = "компьютер в бункере → вкладка «Ферма»"
const PLACE: String = FARM_TAB + " → «Вентиляция»"


static func fill(box: VBoxContainer, sim: SimState, set_level: Callable, buy_sensor: Callable) -> void:
	if not sim.climate.exists():
		return
	var def := sim.climate.definition()
	box.add_child(UiStyle.label("Вентиляция", 16, UiStyle.ACCENT))
	box.add_child(UiStyle.label(UiText.climate_report(sim), 14, UiStyle.MUTED))
	var advice := damp_advice(sim)
	if not advice.is_empty():
		box.add_child(UiStyle.label(advice, 14, UiStyle.ACCENT))
	for level: int in def.ventilation.size():
		var air := def.ventilation[level]
		var cost := "бесплатно" if air.power_per_hour <= 0 else "%s/ч за электричество" % UiText.money(air.power_per_hour)
		var current := level == sim.climate.ventilation
		var label := "%s%s — %s, влажность −%d%%" % ["● " if current else "", air.display_name, cost, roundi(air.humidity_drop)]
		var button := UiStyle.button(label, set_level.bind(level), not current)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(button)
	if not sim.climate.sensor_installed:
		box.add_child(UiStyle.button("Поставить датчик влажности — %s" % UiText.money(def.sensor_price), buy_sensor, sim.economy.money >= def.sensor_price))


## Too damp for the beds: what to do and where; empty when the air is fine.
static func damp_advice(sim: SimState) -> String:
	if not sim.climate.exists() or sim.climate.mold_factor() <= 0.0:
		return ""
	return what_to_do(sim)


## The fix for damp air, naming the control; used by the mold news as well.
static func what_to_do(sim: SimState) -> String:
	if not sim.climate.exists():
		return ""
	var def := sim.climate.definition()
	if sim.suspicion.quiet:
		return "Ферма затихла — вытяжка стоит, вот и сыро. Вернуть ферму к работе: %s, кнопка «Вернуться к работе»." % FARM_TAB
	var next := sim.climate.ventilation + 1
	if next < def.ventilation.size():
		var air := def.ventilation[next]
		return "Прибавьте вентиляцию: %s, «%s» (%s/ч за электричество)." % [PLACE, air.display_name, UiText.money(air.power_per_hour)]
	return "Вентиляция и так на полную. Убирайте плесень сразу — и не ставьте в бункер больше грядок, чем вытянет осушитель."
