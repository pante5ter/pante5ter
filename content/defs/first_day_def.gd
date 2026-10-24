class_name FirstDayDef
extends Resource

@export_group("First call")
## Real seconds after the first planting until the guaranteed client calls.
@export var call_after_real_seconds: float = 60.0
@export var call_quantity: int = 1
@export var call_min_quality: int = 0
@export var call_reward: int = 300
@export var call_answer_hours: float = 6.0

@export_group("Schedule (game hours from the start)")
@export var lord_hour: float = 19.0
@export var trouble_hour: float = 33.0

@export_group("Stories")
@export var lord_story: StoryDef
## Day-two trouble when no bed is growing for the pests to land on.
@export var trouble_story: StoryDef

@export_group("Reggie")
@export_multiline var plant_field_line: String = ""
@export_multiline var plant_bunker_line: String = ""
@export_multiline var call_line: String = ""
@export_multiline var answer_line: String = ""
@export_multiline var harvest_line: String = ""
@export_multiline var haul_line: String = ""
@export_multiline var pack_line: String = ""
@export_multiline var send_line: String = ""
@export_multiline var paid_line: String = ""
@export_multiline var evening_line: String = ""
@export_multiline var morning_line: String = ""
@export_multiline var trouble_line: String = ""
