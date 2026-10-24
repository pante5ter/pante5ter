class_name Travel
extends RefCounted
## Drives between the farm, home and the stash: the sim moves Jack and the clock, the router changes the scene.

const SCENES: Dictionary[String, String] = {
	DayCycle.FARM: "res://scenes/field/field.tscn",
	DayCycle.HOME: "res://scenes/home/home.tscn",
	DayCycle.STASH: "res://scenes/stash/stash.tscn",
}
## Where Jack steps out of the car in each scene.
const ARRIVALS: Dictionary[String, String] = {
	DayCycle.FARM: "car_container",
	DayCycle.HOME: "from_car",
	DayCycle.STASH: "from_car",
}
const MANOR_SPAWN: String = "car_manor"
const TITLES: Dictionary[String, String] = {
	DayCycle.FARM: "на ферму",
	DayCycle.HOME: "домой",
	DayCycle.STASH: "в тайник",
}
const NAMES: Dictionary[String, String] = {
	DayCycle.FARM: "ферма",
	DayCycle.HOME: "дом",
	DayCycle.STASH: "тайник при пекарне",
}


static func scene_of(place: String) -> String:
	return SCENES.get(place, SCENES[DayCycle.FARM])


## Jack drives there; the view follows him. Empty spawn: the usual car stop.
static func go(place: String, spawn: String = "") -> CommandResult:
	if SceneRouter.is_busy():
		return CommandResult.failure(CommandResult.ON_THE_ROAD)
	var result := Game.sim.apply(TravelCommand.new(place))
	if result.ok:
		SceneRouter.go_to(scene_of(place), spawn if not spawn.is_empty() else ARRIVALS.get(place, ""))
	return result


## Jack drives the crates to the stash himself and stays there.
static func haul_myself() -> CommandResult:
	if SceneRouter.is_busy():
		return CommandResult.failure(CommandResult.ON_THE_ROAD)
	var result := Game.sim.apply(HaulCommand.new(DayCycle.JACK))
	if result.ok:
		SceneRouter.go_to(scene_of(DayCycle.STASH), ARRIVALS[DayCycle.STASH])
	return result


## Only the view goes there; Jack stays where he is.
static func look_at(place: String, spawn: String = "") -> void:
	SceneRouter.go_to(scene_of(place), spawn if not spawn.is_empty() else ARRIVALS.get(place, ""))


static func back_to_jack() -> void:
	var place := Game.sim.day.place
	SceneRouter.go_to(scene_of(place), ARRIVALS.get(place, ""))


## Who is at the wheel, for the menu: Reggie drives Jack when he is around.
static func driver_note() -> String:
	return "Реджи за рулём" if Game.sim.helper.present() else "сам за рулём"


static func actions_from(here: String, level: Level) -> Array[UiAction]:
	var result: Array[UiAction] = []
	for place: String in DayCycle.PLACES:
		if place == here:
			continue
		if place == DayCycle.FARM:
			result.append(UiAction.make("Ехать на ферму — к контейнеру", _drive.bind(level, place, ARRIVALS[place])))
			result.append(UiAction.make("Ехать на ферму — к усадьбе", _drive.bind(level, place, MANOR_SPAWN)))
		else:
			result.append(UiAction.make("Ехать %s" % TITLES[place], _drive.bind(level, place, "")))
	return result


static func _drive(level: Level, place: String, spawn: String) -> void:
	var result := go(place, spawn)
	if not result.ok:
		level.show_message(UiText.error(result.error))
