class_name BunkerLights
extends Node

## With the farm lying low the bunker goes dark: the room light drops and the work lamps go out.
## The lift keeps its lamp so Jack can find the way out.

const DIMMED: float = 0.25

@export var world: WorldEnvironment
@export var lamps: Array[Light3D] = []

var _lit_energy: float = 0.0


func _ready() -> void:
	world.environment = world.environment.duplicate() as Environment
	_lit_energy = world.environment.ambient_light_energy


func _process(_delta: float) -> void:
	var lit := not Game.sim.suspicion.quiet
	world.environment.ambient_light_energy = _lit_energy if lit else _lit_energy * DIMMED
	for lamp: Light3D in lamps:
		lamp.visible = lit
