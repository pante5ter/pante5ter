class_name StoryGuest
extends Node3D

## Someone who is in the house only while their story is waiting or on screen:
## the vicar on the living-room armchair, Reggie by the cork board in the study.

@export var story_id: String = ""


func _ready() -> void:
	visible = is_here()


func _process(_delta: float) -> void:
	visible = is_here()


func is_here() -> bool:
	if Game.sim == null or story_id.is_empty():
		return false
	if Game.sim.stories.pending_id == story_id:
		return true
	var level := owner as Level
	return level != null and level.hud != null and level.hud.story_presenter != null and level.hud.story_presenter.presenting() == story_id
