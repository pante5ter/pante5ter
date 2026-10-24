class_name StoryPresenter
extends Node

## Shows the sim's pending choice story in the HUD dialogue box and sends the answer back.

var hud: Hud
var _story_id: String = ""


func _ready() -> void:
	hud.dialogue_box.chosen.connect(_on_chosen)


func presenting() -> String:
	return _story_id


func _process(_delta: float) -> void:
	var sim := Game.sim
	if sim == null or hud.is_dialogue_open():
		return
	var story := sim.stories.pending()
	if story == null:
		_story_id = ""
		return
	_story_id = story.id
	hud.play_dialogue(story.lines, story.choice_labels())


func _on_chosen(index: int) -> void:
	if _story_id.is_empty():
		return
	var story := Game.sim.stories.find(_story_id)
	if story == null or index < 0 or index >= story.choices.size():
		return
	var choice := story.choices[index]
	var result := Game.sim.apply(ChooseCommand.new(_story_id, index))
	if not result.ok:
		var refusal: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.FINN, StoryText.refusal(result.error, choice))]
		hud.play_dialogue(refusal, story.choice_labels())
		return
	_story_id = ""
	hud.play_dialogue(StoryText.reply(choice, result.value == 1))
