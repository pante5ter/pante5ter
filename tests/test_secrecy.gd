extends GutTest

## Secrecy rule: only Jack's crew knows where the farm is. Visitors in stories meet Jack at his
## cottage, at the manor or on the phone — never at the container. The gang's raid is the exception
## the rat hunt is about, so its opening story is not checked here.

const BALANCE_PATH: String = "res://content/balance.tres"
const GIVEAWAYS: Array[String] = ["контейнер", "стеллаж", "бункер", "лифт"]

var _balance: BalanceConfig


func before_all() -> void:
	_balance = load(BALANCE_PATH) as BalanceConfig


func _visitor_stories() -> Array[StoryDef]:
	var stories: Array[StoryDef] = []
	stories.append_array(_balance.director.stories)
	for story: StoryDef in [_balance.first_day.lord_story, _balance.first_day.trouble_story, _balance.courier_theft_story]:
		if story != null and not stories.has(story):
			stories.append(story)
	return stories


func _texts(story: StoryDef) -> PackedStringArray:
	var texts := PackedStringArray()
	for line: DialogueLineDef in story.lines:
		texts.append(line.text)
	for choice: StoryChoiceDef in story.choices:
		texts.append(choice.label)
		for line: DialogueLineDef in choice.reply + choice.fail_reply:
			texts.append(line.text)
	return texts


func test_no_visitor_story_gives_the_farm_away() -> void:
	var stories := _visitor_stories()
	assert_gt(stories.size(), 5)
	for story: StoryDef in stories:
		for text: String in _texts(story):
			for word: String in GIVEAWAYS:
				assert_false(text.to_lower().contains(word), "%s: «%s» mentions %s" % [story.id, text, word])


func test_the_reporter_calls_instead_of_driving_up() -> void:
	var reporter: StoryDef = null
	for story: StoryDef in _balance.director.stories:
		if story.id == "reporter":
			reporter = story
	assert_not_null(reporter)
	assert_string_contains(reporter.lines[0].text.to_lower(), "звон")


func test_manor_talks_happen_face_to_face() -> void:
	for story: StoryDef in _visitor_stories():
		if story.place != StoryDef.MANOR:
			continue
		for line: DialogueLineDef in story.lines:
			assert_false(line.text.to_lower().contains("звон"), "%s happens at the manor, not on the phone: «%s»" % [story.id, line.text])
