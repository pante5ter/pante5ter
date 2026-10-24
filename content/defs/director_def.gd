class_name DirectorDef
extends Resource

## Real seconds without anything notable before the director steps in.
@export var quiet_real_seconds: float = 90.0
## Event types that count as "something happened". Story, director and first-day events always count.
@export var notable_events: PackedStringArray = PackedStringArray()

@export_group("Weights")
@export var urgent_order_weight: float = 3.0
@export var lord_visit_weight: float = 1.0
@export var rumour_weight: float = 1.5
@export var breakdown_weight: float = 1.0
@export var courier_trouble_weight: float = 1.0
@export var story_weight: float = 3.0

@export_group("Urgent order")
@export var urgent_quantity_min: int = 1
@export var urgent_quantity_max: int = 2
@export var urgent_min_quality: int = 40
## On top of the usual call price.
@export var urgent_reward_multiplier: float = 2.0
@export var urgent_answer_hours: float = 0.75
@export var urgent_deadline_hours: float = 4.0

@export_group("Rumour")
## Reggie hears about an inspection only once the farm is this suspicious; below it the rumour is about raiders.
@export var rumour_inspection_min_suspicion: float = 25.0
@export var rumour_inspection_hours: float = 3.0

@export_group("Courier trouble")
@export var courier_delay_hours: float = 1.0

@export_group("Stories")
@export var stories: Array[StoryDef] = []


func weight(kind: String) -> float:
	match kind:
		Director.URGENT_ORDER:
			return urgent_order_weight
		Director.LORD_VISIT:
			return lord_visit_weight
		Director.RUMOUR:
			return rumour_weight
		Director.BREAKDOWN:
			return breakdown_weight
		Director.COURIER_TROUBLE:
			return courier_trouble_weight
		Director.STORY:
			return story_weight
	return 0.0
