class_name ComputerDesk
extends Interactable

@export var screen_glow: Node3D


func _process(_delta: float) -> void:
	screen_glow.visible = not Game.sim.orders.with_status(Order.Status.OFFERED).is_empty()


func hover_text() -> String:
	var calls := Game.sim.orders.with_status(Order.Status.OFFERED).size()
	if calls > 0:
		return "Компьютер — звонков: %d" % calls
	return "Компьютер — заказы, курьеры, ферма"


func interact(level: Level) -> void:
	level.hud.open_computer()
