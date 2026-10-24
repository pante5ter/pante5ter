class_name ParcelBox
extends Interactable
## The supply parcel left by the container door. It can only be clicked while there is one.

## Clickable, but outside the navmesh bake: the box comes and goes without re-baking.
const LAYER: int = 4

@export var visual: Node3D


func _process(_delta: float) -> void:
	var waiting := has_parcel()
	visual.visible = waiting
	collision_layer = LAYER if waiting else 0


func has_parcel() -> bool:
	return not Game.sim.supplies.parcel().is_empty()


func hover_text() -> String:
	return "Посылка — забрать: %s" % _contents()


func interact(level: Level) -> void:
	if not has_parcel():
		return
	var contents := _contents()
	var result := Game.sim.apply(PickUpParcelCommand.new())
	level.show_message("Посылку забрал (%s) — всё на складе (телефон → Склад)." % contents if result.ok else UiText.error(result.error))


func _contents() -> String:
	var items := PackedStringArray()
	for entry: Dictionary in Game.sim.supplies.parcel():
		items.append("%s × %d" % [UiText.item_name(String(entry["item"]), Game.sim), int(entry["quantity"])])
	return ", ".join(items)
