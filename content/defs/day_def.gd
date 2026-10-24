class_name DayDef
extends Resource

## Jack's day: Reggie calls him home in the evening, he sleeps at home and wakes in the morning.

@export var evening_hour: float = 20.0
## From this hour until late_until_hour Jack away from home is noticed: lights and a car out at night.
@export var late_hour: float = 23.0
@export var late_until_hour: float = 5.0
@export var late_suspicion_per_hour: float = 0.0
## The bed takes him only from this hour (and through the night).
@export var sleep_from_hour: float = 18.0
@export var wake_hour: float = 7.0
## Game minutes for any drive between the farm, home and the stash.
@export var travel_minutes: float = 20.0
