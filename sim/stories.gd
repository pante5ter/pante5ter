class_name Stories
extends RefCounted

const LORD: String = "lord"
const VILLAGE: String = "village"
const CREW: String = "crew"

## The story waiting for Jack's choice; empty when none.
var pending_id: String = ""
var used: Array[String] = []
var relations: Dictionary[String, int] = {}

var _config: BalanceConfig
var _economy: Economy
var _suspicion: Suspicion
var _rent: Rent
var _rng: SimRng
var _event_log: EventLog


func _init(config: BalanceConfig, economy: Economy, suspicion: Suspicion, rent: Rent, rng: SimRng, event_log: EventLog) -> void:
	_config = config
	_economy = economy
	_suspicion = suspicion
	_rent = rent
	_rng = rng
	_event_log = event_log


func all() -> Array[StoryDef]:
	var found: Array[StoryDef] = []
	if _config.director != null:
		found.append_array(_config.director.stories)
	var first_day := _config.first_day
	if first_day != null:
		for story: StoryDef in [first_day.lord_story, first_day.trouble_story]:
			if story != null and not found.has(story):
				found.append(story)
	return found


func find(story_id: String) -> StoryDef:
	for story: StoryDef in all():
		if story.id == story_id:
			return story
	return null


func pending() -> StoryDef:
	return find(pending_id) if not pending_id.is_empty() else null


func is_pending() -> bool:
	return not pending_id.is_empty()


func relation(key: String) -> int:
	return relations.get(key, 0)


## Director stories of this kind that have not been told yet, in content order.
func untold(kind: String) -> Array[StoryDef]:
	var found: Array[StoryDef] = []
	if _config.director == null:
		return found
	for story: StoryDef in _config.director.stories:
		if story.kind == kind and not used.has(story.id):
			found.append(story)
	return found


func start(story: StoryDef, now: float, actor: String) -> bool:
	if story == null or is_pending() or used.has(story.id) or story.choices.is_empty():
		return false
	pending_id = story.id
	used.append(story.id)
	_event_log.record(EventLog.STORY_STARTED, now, PackedStringArray([actor]), {"story_id": story.id, "kind": story.kind})
	return true


func choose(story_id: String, index: int, now: float, actor: String) -> CommandResult:
	var story := pending()
	if story == null or story.id != story_id:
		return CommandResult.failure(CommandResult.NO_STORY)
	if index < 0 or index >= story.choices.size():
		return CommandResult.failure(CommandResult.UNKNOWN_CHOICE)
	var choice := story.choices[index]
	if _economy.money < choice.cost():
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	var worked := choice.chance >= 1.0 or _rng.randf() < choice.chance
	var money := choice.money if worked else choice.fail_money
	_move_money(money)
	_suspicion.add(choice.suspicion if worked else choice.fail_suspicion)
	if not choice.relation.is_empty():
		relations[choice.relation] = relation(choice.relation) + (choice.relation_change if worked else choice.fail_relation_change)
	if worked and choice.rent_credit > 0:
		_rent.add_credit(choice.rent_credit)
	pending_id = ""
	_event_log.record(EventLog.STORY_RESOLVED, now, PackedStringArray([actor]), {
		"story_id": story.id,
		"choice": index,
		"worked": worked,
		"money": _economy.money,
	})
	return CommandResult.success(1 if worked else 0)


func _move_money(amount: int) -> void:
	if amount >= 0:
		_economy.earn(amount)
	else:
		_economy.spend(mini(-amount, _economy.money))


func to_dict() -> Dictionary:
	var saved_relations: Dictionary = {}
	for key: String in relations:
		saved_relations[key] = relations[key]
	return {"pending_id": pending_id, "used": used.duplicate(), "relations": saved_relations}


func load_dict(data: Dictionary) -> void:
	pending_id = String(data["pending_id"])
	used.clear()
	for story_id: Variant in data["used"] as Array:
		used.append(String(story_id))
	relations.clear()
	var saved := data["relations"] as Dictionary
	for key: Variant in saved:
		relations[String(key)] = int(saved[key])
