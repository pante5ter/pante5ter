class_name Buyer
extends Interactable


func hover_text() -> String:
	var products := Game.sim.inventory.products()
	if products.is_empty():
		return "Покупатель — пока нечего продавать"
	var total := 0
	for product: Product in products:
		total += Game.sim.economy.price_for(product.quality)
	return "Покупатель — продать урожай (%d шт. за %s)" % [products.size(), UiText.money(total)]


func interact(level: Level) -> void:
	var sold := 0
	var earned := 0
	var quality_sum := 0
	for product: Product in Game.sim.inventory.products():
		var quality := product.quality
		var result := Game.sim.apply(SellCommand.new(product.id))
		if result.ok:
			sold += 1
			earned += result.value
			quality_sum += quality
	if sold == 0:
		level.show_message("Покупатель: «Приходи, когда будет товар».")
		return
	var average_quality := roundi(float(quality_sum) / float(sold))
	level.show_message("Продано %d шт. (среднее качество %d) за %s." % [sold, average_quality, UiText.money(earned)])
