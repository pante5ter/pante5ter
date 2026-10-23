class_name RaiderGang
extends Interactable

const RAIDER_LAYER: int = 0b100

@export var visual: Node3D


func _process(_delta: float) -> void:
	var pending := Game.sim.raids.pending
	visual.visible = pending
	collision_layer = RAIDER_LAYER if pending else 0


func hover_text() -> String:
	return "Гопники — разобраться"


func interact(level: Level) -> void:
	if not Game.sim.raids.pending:
		return
	var raids := Game.sim.raids
	var left := UiText.real_duration(raids.deadline - Game.sim.clock.elapsed_game_seconds, Game.sim)
	var title := "«Слышь, фермер. Делиться надо».\nЕсли ничего не сделать, через %s обчистят всё." % left
	level.hud.show_actions(title, actions(level))


func actions(level: Level) -> Array[UiAction]:
	var raids := Game.sim.raids
	var result: Array[UiAction] = [
		UiAction.make("Откупиться (%s)" % UiText.money(raids.bribe()), _respond.bind(level, Raids.PAY), Game.sim.economy.money >= raids.bribe()),
		UiAction.make("Отдать половину товара (%d шт.)" % ceili(float(Game.sim.inventory.count()) / 2.0), _respond.bind(level, Raids.GIVE)),
		UiAction.make("Прогнать (шанс %d%%, будет шумно)" % roundi(raids.chase_chance() * 100.0), _respond.bind(level, Raids.CHASE)),
	]
	return result


func _respond(level: Level, choice: String) -> void:
	var result := Game.sim.apply(RaidCommand.new(choice))
	if not result.ok:
		level.show_message(UiText.error(result.error))
