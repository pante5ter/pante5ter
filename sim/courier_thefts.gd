class_name CourierThefts
extends RefCounted

## A courier ran off with a parcel: Reggie calls, and Jack decides whether Reggie has a word with him.
## The story is built from the content template with the thief's name, one per thief.

const ACTOR: String = "reggie"
const STORY_PREFIX: String = "courier_theft:"
## The template's choices, in this order.
const HAVE_A_WORD: int = 0
const LET_GO: int = 1
const NAME_MARK: String = "%s"

## Thieves Reggie has not called about yet, oldest first.
var waiting: Array[String] = []
var seen_events: int = 0

var _config: BalanceConfig
var _stories: Stories
var _event_log: EventLog


func _init(config: BalanceConfig, stories: Stories, event_log: EventLog) -> void:
	_config = config
	_stories = stories
	_event_log = event_log
	seen_events = event_log.size()


func update(now: float) -> void:
	for event: SimEvent in _event_log.since(seen_events):
		if event.type == EventLog.COURIER_STOLE and _config.courier_theft_story != null:
			waiting.append(String(event.data["courier_id"]))
	seen_events = _event_log.size()
	if waiting.is_empty() or _stories.is_pending():
		return
	var story := story_for(waiting.pop_front())
	_stories.register(story)
	_stories.start(story, now, ACTOR)


func story_for(courier_id: String) -> StoryDef:
	var template := _config.courier_theft_story
	var courier := _config.find_courier(courier_id)
	var name := courier.display_name if courier != null else courier_id
	var story := StoryDef.new()
	story.id = STORY_PREFIX + courier_id
	story.kind = StoryDef.SCRIPT
	story.lines = _named(template.lines, name)
	var choices: Array[StoryChoiceDef] = []
	for choice: StoryChoiceDef in template.choices:
		var copy := choice.duplicate() as StoryChoiceDef
		copy.label = choice.label.replace(NAME_MARK, name)
		copy.reply = _named(choice.reply, name)
		copy.fail_reply = _named(choice.fail_reply, name)
		choices.append(copy)
	story.choices = choices
	return story


static func _named(lines: Array[DialogueLineDef], name: String) -> Array[DialogueLineDef]:
	var named: Array[DialogueLineDef] = []
	for line: DialogueLineDef in lines:
		named.append(DialogueLineDef.make(line.speaker, line.text.replace(NAME_MARK, name)))
	return named


func to_dict() -> Dictionary:
	return {"waiting": waiting.duplicate(), "seen_events": seen_events}


## Stories must be loaded first: every theft call already told is rebuilt so a pending one can be answered.
func load_dict(data: Dictionary) -> void:
	waiting.clear()
	for courier_id: Variant in data["waiting"] as Array:
		waiting.append(String(courier_id))
	seen_events = int(data["seen_events"])
	if _config.courier_theft_story == null:
		return
	for story_id: String in _stories.used:
		if story_id.begins_with(STORY_PREFIX):
			_stories.register(story_for(story_id.trim_prefix(STORY_PREFIX)))
