class_name ComputerDesk
extends Interactable

@export var screen_glow: Node3D


func _process(_delta: float) -> void:
	screen_glow.visible = ready_orders() > 0


## Accepted orders whose boxes are on the shelf, waiting for a driver.
static func ready_orders() -> int:
	var ready := 0
	for order: Order in Game.sim.orders.with_status(Order.Status.ACCEPTED):
		if Game.sim.orders.can_fill(order):
			ready += 1
	return ready


func hover_text() -> String:
	var ready := ready_orders()
	if ready > 0:
		return "Компьютер — заказов к отправке: %d" % ready
	if not ClimateControls.damp_advice(Game.sim).is_empty():
		return "Компьютер — в бункере сыро: вентиляция на вкладке «Ферма»"
	return "Компьютер — заказы, курьеры, ферма и вентиляция"


func interact(level: Level) -> void:
	level.hud.open_computer()
