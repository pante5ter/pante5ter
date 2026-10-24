class_name PackingBench
extends Interactable

@export var sacks: Node3D
@export var progress_label: Label3D


func _ready() -> void:
	add_to_group(WorkerView.BENCH_GROUP)


func _process(_delta: float) -> void:
	var packing := Game.sim.packing
	sacks.visible = packing.unpacked_count() > 0
	if packing.busy():
		progress_label.text = "Фасовка… %s" % UiText.real_duration(packing.ends_at - Game.sim.clock.elapsed_game_seconds, Game.sim)
	elif packing.unpacked_count() > 0:
		progress_label.text = "Урожай: %d шт." % packing.unpacked_count()
	else:
		progress_label.text = "Стол фасовки"


func hover_text() -> String:
	return "Стол фасовки — нефасованного: %d" % Game.sim.packing.unpacked_count()


func interact(level: Level) -> void:
	level.hud.show_actions("Стол фасовки", actions(level))


func actions(level: Level) -> Array[UiAction]:
	var packing := Game.sim.packing
	var units := packing.unpacked_count()
	var minutes := Game.sim.config.orders.pack_minutes_per_unit * 60.0 * float(units)
	var label := "Расфасовать урожай (%d шт., %s)" % [units, UiText.real_duration(minutes, Game.sim)]
	if packing.busy():
		label = "Уже фасуется…"
	var result: Array[UiAction] = [UiAction.make(label, _pack.bind(level), units > 0 and not packing.busy())]
	return result


func _pack(level: Level) -> void:
	var result := Game.sim.apply(PackCommand.new())
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	level.show_message("Фасуем %d шт. Коробки появятся на полке." % result.value)
