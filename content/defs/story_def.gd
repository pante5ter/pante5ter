class_name StoryDef
extends Resource

const VILLAGE: String = "village"
const LORD: String = "lord"
const SCRIPT: String = "script"
const ANYWHERE: String = "anywhere"
const MANOR: String = "manor"

@export var id: String = ""
## The director brings "lord" stories as the lord's visit and "village" ones as local trouble;
## "script" stories only come from the first-day script.
@export_enum("village", "lord", "script") var kind: String = VILLAGE
## "manor": the lord sends for Jack and the talk happens when Jack walks up to him.
@export_enum("anywhere", "manor") var place: String = ANYWHERE
## A summons left unanswered this many game hours expires.
@export var wait_hours: float = 6.0
## Lord relation change when Jack never turns up.
@export var ignored_relation: int = -1
## The director brings it only after all of these stories have been told...
@export var after_stories: PackedStringArray = PackedStringArray()
## ...and once suspicion has climbed this high.
@export var min_suspicion: float = 0.0
## Told only between these hours of the game day; from > until wraps past midnight, 0–24 is any hour.
@export_range(0.0, 24.0) var from_hour: float = 0.0
@export_range(0.0, 24.0) var until_hour: float = 24.0
## A plot thread's beat comes this many game hours after the last of `after_stories` was answered.
@export var delay_hours: float = 0.0
## Someone who walks up to the farm. With Jack away, Reggie goes out to meet them.
@export var visitor_name: String = ""
@export var visitor_model: PackedScene
@export var lines: Array[DialogueLineDef] = []
@export var choices: Array[StoryChoiceDef] = []


func choice_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for choice: StoryChoiceDef in choices:
		labels.append(choice.label)
	return labels


func has_visitor() -> bool:
	return not visitor_name.is_empty()


func is_open_at(game_time: float) -> bool:
	if (from_hour <= 0.0 and until_hour >= 24.0) or is_equal_approx(from_hour, until_hour):
		return true
	var hour := fmod(game_time, SimClock.GAME_SECONDS_PER_DAY) / SimClock.GAME_SECONDS_PER_HOUR
	if from_hour < until_hour:
		return hour >= from_hour and hour < until_hour
	return hour >= from_hour or hour < until_hour


## The first moment at or after `game_time` when the story may be told.
func opens_at(game_time: float) -> float:
	if is_inf(game_time) or is_open_at(game_time):
		return game_time
	var day_start := floorf(game_time / SimClock.GAME_SECONDS_PER_DAY) * SimClock.GAME_SECONDS_PER_DAY
	var at := day_start + from_hour * SimClock.GAME_SECONDS_PER_HOUR
	if at <= game_time:
		at += SimClock.GAME_SECONDS_PER_DAY
	return at
