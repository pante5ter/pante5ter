class_name LordAshcombe
extends Interactable


func hover_text() -> String:
	return "%s — поговорить" % UiText.LORD


func interact(level: Level) -> void:
	level.hud.play_dialogue(UiText.lord_lines(Game.sim))
