class_name CrateStack
extends Interactable
## Fresh harvest in crates by the lift. It does not stay on the farm: Reggie drives it to the stash, or Jack does.

@export var stack: Node3D
@export var count_label: Label3D


func _process(_delta: float) -> void:
	var count := crates()
	var shown := stack.get_children()
	for index: int in shown.size():
		(shown[index] as Node3D).visible = index < count
	if Game.sim.stash.on_the_road():
		count_label.text = "Ящики в пути в тайник"
	elif count > 0:
		count_label.text = "Ящики: %d шт." % count
	else:
		count_label.text = "Ящики"


static func crates() -> int:
	return Game.sim.inventory.farm_crates().size()


func shown_crates() -> int:
	return stack.get_children().filter(func(crate: Node) -> bool: return (crate as Node3D).visible).size()


func hover_text() -> String:
	return "Ящики с урожаем — %d шт. Отвезти в тайник" % crates()


func interact(level: Level) -> void:
	level.hud.show_actions("Ящики с урожаем: %d шт." % crates(), actions(level))


func actions(level: Level) -> Array[UiAction]:
	var sim := Game.sim
	var ready := crates() > 0 and not sim.stash.on_the_road()
	var result: Array[UiAction] = []
	if sim.helper.exists():
		var label := "%s отвезёт в тайник" % sim.helper.definition().display_name
		if not sim.helper.present():
			label = "%s сейчас в отъезде" % sim.helper.definition().display_name
		result.append(UiAction.make(label, _send_reggie.bind(level), ready and sim.helper.present()))
	result.append(UiAction.make("Отвезти самому — и остаться в тайнике", _drive_myself.bind(level), ready))
	return result


func _send_reggie(level: Level) -> void:
	var result := Game.sim.apply(HaulCommand.new(Helper.ACTOR))
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	level.show_message("%s грузит %d ящ. в лендровер. Вернётся через %s." % [Game.sim.helper.definition().display_name, result.value, UiText.real_duration(Game.sim.helper.away_until - Game.sim.clock.elapsed_game_seconds, Game.sim)])


func _drive_myself(level: Level) -> void:
	var result := Travel.haul_myself()
	if not result.ok:
		level.show_message(UiText.error(result.error))
