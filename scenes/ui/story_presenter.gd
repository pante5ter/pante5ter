class_name StoryPresenter
extends Node

## Shows the sim's pending choice story in the HUD dialogue box and sends the answer back.
## The lord's rent call and the rent talk at the manor go through here too.

var hud: Hud
var _story_id: String = ""
## RentTalk.CALL or RentTalk.MANOR while a rent question is on screen.
var _rent_talk: String = ""


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
	# Only Jack's people know where the farm is: the lord's talks wait for Jack at the manor.
	elif story.place != StoryDef.MANOR:
		_present(story)
		return
	if sim.rent.call_pending() and not hud.night.is_open():
		_present_rent(RentTalk.CALL)


## Called by the lord when Jack walks up to him; false when the lord has nothing to discuss.
func present_at_manor() -> bool:
	if Game.sim.rent.visit_promised():
		_present_rent(RentTalk.MANOR)
		return true
	var story := Game.sim.stories.pending()
	if story == null or story.place != StoryDef.MANOR:
		return false
	_present(story)
	return true


func _present(story: StoryDef) -> void:
	_story_id = story.id
	hud.play_dialogue(story.lines, story.choice_labels())
	hud.dialogue_box.set_choices_enabled(Game.sim.stories.affordable(story))


func _present_rent(talk: String) -> void:
	var sim := Game.sim
	_rent_talk = talk
	if talk == RentTalk.CALL:
		hud.play_dialogue(RentTalk.call_lines(sim), RentTalk.call_choices(sim))
	else:
		hud.play_dialogue(RentTalk.manor_lines(sim), RentTalk.manor_choices(sim))
	hud.dialogue_box.set_choices_enabled(RentTalk.pay_flags(sim))


func _on_chosen(index: int) -> void:
	if not _rent_talk.is_empty():
		_on_rent_chosen(index)
		return
	if _story_id.is_empty():
		return
	var story := Game.sim.stories.find(_story_id)
	if story == null or index < 0 or index >= story.choices.size():
		return
	var choice := story.choices[index]
	var result := Game.sim.apply(ChooseCommand.new(_story_id, index))
	if not result.ok:
		var refusal: Array[DialogueLineDef] = [DialogueLineDef.make(UiText.REGGIE, StoryText.refusal(result.error, choice))]
		hud.play_dialogue(refusal, story.choice_labels())
		hud.dialogue_box.set_choices_enabled(Game.sim.stories.affordable(story))
		return
	_story_id = ""
	hud.play_dialogue(StoryText.reply(choice, result.value == 1))


## At the manor «later» changes nothing: the promise and its deadline stand.
func _on_rent_chosen(index: int) -> void:
	var talk := _rent_talk
	var sim := Game.sim
	if index == RentTalk.PAY_INDEX or talk == RentTalk.CALL:
		var answer := Rent.PAY if index == RentTalk.PAY_INDEX else Rent.VISIT
		var result := sim.apply(RentCommand.new(answer))
		if not result.ok:
			hud.show_message(UiText.error(result.error))
			hud.dialogue_box.set_choices_enabled(RentTalk.pay_flags(sim))
			return
	_rent_talk = ""
	hud.play_dialogue(RentTalk.reply(talk, index, sim))
