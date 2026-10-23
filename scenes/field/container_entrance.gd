class_name ContainerEntrance
extends Elevator

@export var cover: Node3D


func _process(_delta: float) -> void:
	cover.visible = Game.sim.suspicion.entrance_masked


func hover_text() -> String:
	if Game.sim.suspicion.entrance_masked:
		return "Контейнер — вход замаскирован"
	return hover_label


func interact(level: Level) -> void:
	level.hud.show_actions("Старый контейнер", actions(level))


func actions(level: Level) -> Array[UiAction]:
	var masked := Game.sim.suspicion.entrance_masked
	var result: Array[UiAction] = [UiAction.make("Спуститься на плантацию" if not masked else "Спуститься (сначала сними маскировку)", ride, not masked)]
	if masked:
		result.append(UiAction.make("Снять маскировку", _mask.bind(level, false)))
	else:
		result.append(UiAction.make("Замаскировать вход (сено и хлам)", _mask.bind(level, true)))
	return result


func _mask(level: Level, masked: bool) -> void:
	var result := Game.sim.apply(MaskEntranceCommand.new(masked))
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	level.show_message("Вход завален сеном и хламом. Пока так — вниз не спуститься." if masked else "Маскировка снята.")
