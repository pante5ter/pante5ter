class_name RoomDef
extends Resource

## One room of the bunker as the climate sensor reports it.
@export var id: String = ""
@export var display_name: String = ""
## The room the beds stand in: its humidity decides the mold risk.
@export var has_beds: bool = false
@export var base_temperature: float = 20.0
@export var base_humidity: float = 50.0
## Per growing bed: the plants breathe out water and the lamps heat the air.
@export var humidity_per_bed: float = 0.0
@export var heat_per_bed: float = 0.0
