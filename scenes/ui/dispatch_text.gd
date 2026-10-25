class_name DispatchText
extends RefCounted

## Why an accepted order cannot go out with this driver right now; empty when it can.
## Checked in the order the player would fix things: the farm's lights, the boxes, then the driver.


static func blocked_reason(order: Order, courier_id: String, sim: SimState) -> String:
	if sim.suspicion.quiet:
		return "ферма затихла — сначала «Вернуться к работе» на вкладке «Ферма»"
	if not sim.orders.can_fill(order):
		return _shortage(order, sim)
	if not sim.couriers.is_free(courier_id, sim.clock.elapsed_game_seconds):
		return _driver_away(courier_id, sim)
	return ""


static func _shortage(order: Order, sim: SimState) -> String:
	var boxes := sim.orders.matching_products(order).size()
	var waiting := 0
	for product: Product in sim.inventory.products():
		if not product.packed and order.accepts(product):
			waiting += 1
	var text := "нет расфасованного товара%s качества %d+ (коробок %d из %d" % [UiText.order_strain(order.strain_id, sim), order.min_quality, boxes, order.quantity]
	if waiting > 0:
		text += ", ещё %d шт. ждут фасовки" % waiting
	return text + ")"


static func _driver_away(courier_id: String, sim: SimState) -> String:
	if sim.couriers.is_helper(courier_id):
		var status := PeopleText.helper_status(sim)
		return status if not status.is_empty() else "помощника нет на ферме"
	var back: float = sim.couriers.busy_until.get(courier_id, 0.0)
	return "в дороге, вернётся через %s" % UiText.real_duration(back - sim.clock.elapsed_game_seconds, sim)
