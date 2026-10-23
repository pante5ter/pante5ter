class_name DayNight
extends Node

@export var sun: DirectionalLight3D
@export var world: WorldEnvironment
@export var day_sky: Color = Color(0.56, 0.72, 0.88)
@export var night_sky: Color = Color(0.05, 0.07, 0.14)
@export var day_light: Color = Color(1.0, 0.95, 0.86)
@export var night_light: Color = Color(0.5, 0.6, 0.9)


func _process(_delta: float) -> void:
	var hour := Game.sim.clock.hour_of_day()
	var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
	var t := smoothstep(0.0, 0.4, daylight)
	sun.light_energy = lerpf(0.35, 1.25, t)
	sun.light_color = night_light.lerp(day_light, t)
	sun.rotation.x = deg_to_rad(-lerpf(25.0, 65.0, daylight))
	var environment := world.environment
	environment.background_color = night_sky.lerp(day_sky, t)
	environment.ambient_light_color = night_light.lerp(Color.WHITE, t)
	environment.ambient_light_energy = lerpf(0.45, 0.7, t)
