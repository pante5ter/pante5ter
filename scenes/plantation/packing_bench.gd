class_name PackingBench
extends Interactable

## Loose harvest on the bench: one more heap shows at each step of unpacked units. Boxes only exist on the shelf.
const PILE_STEPS: Array[int] = [1, 3, 6]

@export var pile: Node3D
@export var progress_label: Label3D


func _ready() -> void:
	add_to_group(WorkerView.BENCH_GROUP)


func _process(_delta: float) -> void:
	var packing := Game.sim.packing
	show_pile(packing.unpacked_count())
	if packing.busy():
		progress_label.text = "Фасовка… %s" % UiText.real_duration(packing.ends_at - Game.sim.clock.elapsed_game_seconds, Game.sim)
	elif packing.unpacked_count() > 0:
		progress_label.text = "Урожай: %d шт." % packing.unpacked_count()
	else:
		progress_label.text = "Стол фасовки"


func show_pile(units: int) -> void:
	var heaps := pile.get_children()
	for index: int in heaps.size():
		(heaps[index] as Node3D).visible = index < PILE_STEPS.size() and units >= PILE_STEPS[index]
	pile.visible = units > 0


func shown_heaps() -> int:
	if not pile.visible:
		return 0
	return pile.get_children().filter(func(heap: Node) -> bool: return (heap as Node3D).visible).size()


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
