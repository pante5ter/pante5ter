class_name IntrigueAccusation
extends RefCounted

## Reggie lays out what he has and asks for a name: everyone Jack has met, then «nobody yet».


## The last choice: nobody yet.
static func wait_choice(intrigue: Intrigue) -> int:
	return intrigue.accusable().size()


## The choice that names this suspect; -1 when he is not on the list.
static func choice_for(intrigue: Intrigue, suspect_id: String) -> int:
	var names := intrigue.accusable()
	for index: int in names.size():
		if names[index].id == suspect_id:
			return index
	return -1


static func build(intrigue: Intrigue) -> StoryDef:
	var def := intrigue.definition()
	var story := StoryDef.new()
	story.id = Intrigue.ACCUSE_STORY_ID
	story.kind = StoryDef.SCRIPT
	var lines: Array[DialogueLineDef] = []
	lines.append_array(def.accuse_lines)
	for key: String in intrigue.given_clues():
		var text := intrigue.clue_text(key)
		if not text.is_empty():
			lines.append(DialogueLineDef.make(def.crew_speaker, text))
	var rat := intrigue.rat_suspect()
	if intrigue.boss_named and rat != null:
		lines.append(DialogueLineDef.make(def.boss_speaker, def.boss_name_line % rat.display_name))
	story.lines = lines
	var choices: Array[StoryChoiceDef] = []
	for person: SuspectDef in intrigue.accusable():
		var choice := StoryChoiceDef.new()
		choice.label = person.accuse_label
		choice.reply = person.guilty_reply if person == rat else person.innocent_reply
		choices.append(choice)
	var wait := StoryChoiceDef.new()
	wait.label = def.wait_label
	wait.reply = def.wait_reply
	choices.append(wait)
	story.choices = choices
	return story
