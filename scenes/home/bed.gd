class_name Bed
extends Interactable
## Jack and Vivienne's bed: the day ends here.


func hover_text() -> String:
	var refused := Game.sim.day.can_sleep(Game.sim.clock.elapsed_game_seconds)
	if refused == CommandResult.TOO_EARLY_TO_SLEEP:
		return "Кровать — рано, день ещё не кончился"
	return "Кровать — лечь спать до утра"


func interact(level: Level) -> void:
	level.hud.night.sleep()
