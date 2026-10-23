class_name Stash
extends Interactable


func hover_text() -> String:
	var open := 0
	for order: Order in Game.sim.orders.all():
		if order.status == Order.Status.OPEN:
			open += 1
	return "Тайник — открытых заказов: %d" % open


func interact(level: Level) -> void:
	level.hud.show_actions("Тайник\nЗаказы приходят в телефон (Tab)", actions(level))


func actions(level: Level) -> Array[UiAction]:
	var result: Array[UiAction] = []
	for order: Order in Game.sim.orders.all():
		if order.status != Order.Status.OPEN:
			continue
		var label := "Положить заказ #%d: %d шт., качество %d+ → %s" % [order.id, order.quantity, order.min_quality, UiText.money(order.reward)]
		result.append(UiAction.make(label, _drop.bind(level, order.id), Game.sim.orders.can_fill(order)))
	return result


func _drop(level: Level, order_id: int) -> void:
	var result := Game.sim.apply(DropOrderCommand.new(order_id))
	if not result.ok:
		level.show_message(UiText.error(result.error))
		return
	var order := Game.sim.orders.find(order_id)
	var wait := UiText.real_duration(order.pickup_at - Game.sim.clock.elapsed_game_seconds, Game.sim)
	level.show_message("Заказ #%d в тайнике. Курьер заберёт через %s и заплатит." % [order_id, wait])
