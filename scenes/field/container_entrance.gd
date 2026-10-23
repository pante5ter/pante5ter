class_name ContainerEntrance
extends Elevator

@export var parcel_box: Node3D


func _process(_delta: float) -> void:
	parcel_box.visible = not Game.sim.supplies.parcel().is_empty()


func hover_text() -> String:
	if not Game.sim.supplies.parcel().is_empty():
		return "Контейнер — тут посылка"
	return hover_label


func interact(level: Level) -> void:
	level.hud.show_actions("Старый контейнер", actions(level))


func actions(level: Level) -> Array[UiAction]:
	var result: Array[UiAction] = [UiAction.make("Спуститься на плантацию", ride)]
	var parcel := Game.sim.supplies.parcel()
	if not parcel.is_empty():
		var items := PackedStringArray()
		for entry: Dictionary in parcel:
			items.append("%s × %d" % [UiText.item_name(String(entry["item"]), Game.sim), int(entry["quantity"])])
		result.append(UiAction.make("Забрать посылку: %s" % ", ".join(items), _pick_up.bind(level)))
	return result


func _pick_up(level: Level) -> void:
	var result := Game.sim.apply(PickUpParcelCommand.new())
	level.show_message("Посылку забрал — всё на складе (телефон → Склад)." if result.ok else UiText.error(result.error))
