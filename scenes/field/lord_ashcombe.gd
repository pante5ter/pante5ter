class_name LordAshcombe
extends Interactable


func hover_text() -> String:
	return "%s — поговорить" % UiText.LORD


func interact(level: Level) -> void:
	if not level.hud.story_presenter.present_at_manor():
		level.hud.play_dialogue(UiText.lord_lines(Game.sim))
