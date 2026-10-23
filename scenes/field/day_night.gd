class_name DayNight
extends Node

## Light presets from STYLE.md §5; the hour blends between them.
const DAY: Dictionary = {"sun": Color(0.863, 0.890, 0.910), "energy": 0.8, "pitch": -55.0, "ambient": Color(0.604, 0.651, 0.682), "fog": Color(0.663, 0.698, 0.710), "density": 0.002, "ambient_energy": 1.0}
const DUSK: Dictionary = {"sun": Color(0.941, 0.702, 0.478), "energy": 0.6, "pitch": -14.0, "ambient": Color(0.369, 0.416, 0.478), "fog": Color(0.431, 0.455, 0.502), "density": 0.006, "ambient_energy": 1.6}
const NIGHT: Dictionary = {"sun": Color(0.498, 0.576, 0.710), "energy": 0.2, "pitch": -40.0, "ambient": Color(0.165, 0.196, 0.251), "fog": Color(0.137, 0.165, 0.200), "density": 0.008, "ambient_energy": 2.8}
const KEYS: Array[float] = [0.0, 5.0, 7.0, 9.0, 16.0, 18.5, 21.0, 24.0]

@export var sun: DirectionalLight3D
@export var world: WorldEnvironment
@export var rain: GPUParticles3D


func preset_for_hour(hour: float) -> Dictionary:
	var presets: Array[Dictionary] = [NIGHT, NIGHT, DUSK, DAY, DAY, DUSK, NIGHT, NIGHT]
	for index: int in KEYS.size() - 1:
		if hour <= KEYS[index + 1]:
			var t := inverse_lerp(KEYS[index], KEYS[index + 1], hour)
			return _blend(presets[index], presets[index + 1], t)
	return NIGHT


func is_raining(hour: float) -> bool:
	return float(preset_for_hour(hour)["energy"]) < 0.7


func _process(_delta: float) -> void:
	var hour := Game.sim.clock.hour_of_day()
	var preset := preset_for_hour(hour)
	sun.light_color = preset["sun"]
	sun.light_energy = preset["energy"]
	sun.rotation.x = deg_to_rad(float(preset["pitch"]))
	var environment := world.environment
	environment.background_color = preset["fog"]
	environment.ambient_light_color = preset["ambient"]
	environment.ambient_light_energy = preset["ambient_energy"]
	environment.fog_light_color = preset["fog"]
	environment.fog_density = preset["density"]
	rain.emitting = is_raining(hour)


static func _blend(from: Dictionary, to: Dictionary, t: float) -> Dictionary:
	return {
		"sun": (from["sun"] as Color).lerp(to["sun"] as Color, t),
		"energy": lerpf(float(from["energy"]), float(to["energy"]), t),
		"pitch": lerpf(float(from["pitch"]), float(to["pitch"]), t),
		"ambient": (from["ambient"] as Color).lerp(to["ambient"] as Color, t),
		"fog": (from["fog"] as Color).lerp(to["fog"] as Color, t),
		"density": lerpf(float(from["density"]), float(to["density"]), t),
		"ambient_energy": lerpf(float(from["ambient_energy"]), float(to["ambient_energy"]), t),
	}
