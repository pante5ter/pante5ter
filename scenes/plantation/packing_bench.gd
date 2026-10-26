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
	var label := "Расфасовать автоматически (%d шт., %s)" % [units, UiText.real_duration(minutes, Game.sim)]
	if packing.busy():
		label = "Уже фасуется…"
	var result: Array[UiAction] = []
	var hand := Game.sim.hand_packing
	if hand.available() and not packing.busy():
		var hand_label := "Фасовать самому: «Весы» (до +%d к качеству)" % hand.definition().max_quality_bonus
		result.append(UiAction.make(hand_label, open_scale.bind(level), units > 0))
	result.append(UiAction.make(label, _pack.bind(level), units > 0 and not packing.busy()))
	return result


## The scale only reports the round; the sim decides what it is worth.
func open_scale(level: Level) -> PackingScale:
	var hand := Game.sim.hand_packing
	level.hud.close_actions()
	level.hud.phone.close()
	var game := PackingScale.new()
	game.name = "PackingScale"
	level.hud.add_child(game)
	game.open(hand.definition(), hand.round_seed(), hand.bags_now(), Game.sim.packing.unpacked_count())
	game.finished.connect(_pack_by_hand.bind(level))
	game.auto_chosen.connect(_pack.bind(level))
	return game


func _pack_by_hand(misses: Array[float], level: Level) -> void:
	var result := Game.sim.apply(PackByHandCommand.new(misses))
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	var scored := Game.sim.event_log.of_type(EventLog.PACKING_HAND_SCORED)
	var bonus := int((scored.back() as SimEvent).data["quality_bonus"]) if not scored.is_empty() else 0
	var verdict := "качество %+d" % bonus if bonus != 0 else "без надбавки"
	level.show_message("Фасуем %d шт. своими руками — %s. Коробки появятся на полке." % [result.value, verdict])


func _pack(level: Level) -> void:
	var result := Game.sim.apply(PackCommand.new())
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	level.show_message("Фасуем %d шт. Коробки появятся на полке." % result.value)
