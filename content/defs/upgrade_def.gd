class_name UpgradeDef
extends Resource

## A piece of kit for the bunker from the phone shop. Comes with the daily delivery and costs its
## running bill every day; the effects only work while the bill is paid.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var price: int = 0
## Empire levels (milestones reached) needed before the shop sells it.
@export var level: int = 0
## Sold only to a bunker that already has this upgrade.
@export var requires: String = ""
## Installing it takes this upgrade out: the next tier of the same thing.
@export var replaces: String = ""

@export_group("Running costs")
@export var daily_cost: int = 0
## The delivery van at the container door.
@export var install_suspicion: float = 0.0
## Paid with every bill: a power meter spinning like that gets noticed.
@export var daily_suspicion: float = 0.0

@export_group("Effects")
## Off the beds' room humidity.
@export var humidity_drop: float = 0.0
## Share added to growth speed: 0.25 grows a quarter faster.
@export var growth_speed: float = 0.0
@export var yield_bonus: int = 0
## Counts toward the care cap on quality.
@export var quality_bonus: int = 0
## Waters the first this many beds by itself.
@export var auto_water_beds: int = 0
## A raid at the container waits this much longer for an answer.
@export var raid_warning_hours: float = 0.0
