class_name IntroPresenter
extends Node

## First meetings: a character's backstory plays once, as soon as the screen is free.
## It runs before the story presenter, so an introduction comes before that character's story.

var hud: Hud


func _ready() -> void:
	process_priority = -1


func _process(_delta: float) -> void:
	var sim := Game.sim
	if sim == null or _busy():
		return
	var character := sim.meetings.next_due(_jack_place(sim))
	if character != null:
		_play(character.intro, [character])


## The opening night: the prologue, then what the opening cast has to say about themselves.
func play_opening(prologue: Array[DialogueLineDef]) -> void:
	var cast := Game.sim.meetings.opening()
	var lines: Array[DialogueLineDef] = prologue.duplicate()
	for character: CharacterDef in cast:
		lines.append_array(character.intro)
	_play(lines, cast)


func _play(lines: Array[DialogueLineDef], cast: Array[CharacterDef]) -> void:
	for character: CharacterDef in cast:
		Game.sim.apply(MeetCommand.new(character.id))
	if not lines.is_empty():
		hud.play_dialogue(lines)


## Where Jack stands in this view; empty while he is elsewhere or on the road.
func _jack_place(sim: SimState) -> String:
	if sim.day.travelling() or sim.day.place != hud.place:
		return ""
	return hud.place


func _busy() -> bool:
	if SceneRouter.is_busy() or hud.is_dialogue_open() or hud.night.is_open():
		return true
	return hud.phone.visible or hud.computer.visible or hud.pause_menu.visible or hud.action_menu.visible
