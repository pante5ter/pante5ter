class_name RaiderGang
extends Interactable

const RAIDER_LAYER: int = 0b100
const GANG: String = "«Молочные зубы»"

@export var visual: Node3D


func _process(_delta: float) -> void:
	var pending := Game.sim.raids.pending
	visual.visible = pending
	collision_layer = RAIDER_LAYER if pending else 0


func hover_text() -> String:
	return "Гопники — разобраться"


## The talk stops the clock, so walking up is enough to get a say before the deadline.
func interact(level: Level) -> void:
	if not Game.sim.raids.pending or level.hud.is_dialogue_open():
		return
	var raids := Game.sim.raids
	var left := UiText.real_duration(raids.deadline - Game.sim.clock.elapsed_game_seconds, Game.sim)
	var lines: Array[DialogueLineDef] = [
		DialogueLineDef.make(GANG, "Слышь, фермер. Делиться надо. Не поделишься — через %s унесём все ящики с фермы. На камеру, для клипа." % left),
	]
	level.hud.play_dialogue(lines, choice_labels(Game.sim))
	var enabled: Array[bool] = [Game.sim.economy.money >= raids.bribe(), true, true]
	level.hud.dialogue_box.set_choices_enabled(enabled)
	level.hud.dialogue_box.chosen.connect(_on_chosen.bind(level), CONNECT_ONE_SHOT)


## Pay, give, chase — in the order Raids expects them.
static func choice_labels(sim: SimState) -> PackedStringArray:
	var raids := sim.raids
	var half := ceili(float(sim.inventory.farm_crates().size()) / 2.0)
	return PackedStringArray([
		"Откупиться (%s)" % UiText.money(raids.bribe()),
		"Отдать половину товара с фермы (%d шт.)" % half,
		"Прогнать (шанс %d%%, будет шумно)" % roundi(raids.chase_chance() * 100.0),
	])


func _on_chosen(index: int, level: Level) -> void:
	var choice: String = [Raids.PAY, Raids.GIVE, Raids.CHASE][index]
	var seen := Game.sim.event_log.size()
	var result := Game.sim.apply(RaidCommand.new(choice))
	var reply := UiText.error(result.error) if not result.ok else _outcome_since(seen)
	var lines: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, reply)]
	level.hud.play_dialogue(lines)


static func _outcome_since(seq: int) -> String:
	for event: SimEvent in Game.sim.event_log.since(seq):
		if event.type == EventLog.RAID_RESOLVED:
			return UiText.announcement(event, Game.sim)
	return "Разобрались."
