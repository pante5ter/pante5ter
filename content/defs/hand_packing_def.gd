class_name HandPackingDef
extends Resource

## «Весы»: Jack weighs a few bags himself at the stash bench; a steady hand lifts the batch a little.

@export_group("Scale")
@export var target_grams: float = 28.0
## The needle runs off the dial here: the bag spills and counts as sloppy.
@export var scale_max_grams: float = 40.0
## Real seconds the pour takes to reach the target; each bag gets its own pace in this range.
@export var fill_seconds_min: float = 1.6
@export var fill_seconds_max: float = 2.6

@export_group("Round")
## Bags weighed per round: the batch size, held within these bounds.
@export var min_bags: int = 3
@export var max_bags: int = 5

@export_group("Grades (grams off the target)")
@export var perfect_grams: float = 0.5
@export var good_grams: float = 1.5
@export var fair_grams: float = 3.0
## Points per bag: perfect 1, fair 0; the round's accuracy is their mean.
@export var good_points: float = 0.5
@export var sloppy_points: float = -1.0

@export_group("Bonus")
## Quality added to every unit of the batch at full accuracy.
@export var max_quality_bonus: int = 3
## Quality taken at worst; a sloppy round costs no more than this.
@export var max_quality_penalty: int = 1
## The bonus never lifts a unit above this.
@export var quality_ceiling: int = 100
