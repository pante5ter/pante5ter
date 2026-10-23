class_name Buyer
extends Interactable


func hover_text() -> String:
	var count := Game.sim.inventory.count()
	if count == 0:
		return "Покупатель — пока нечего продавать"
	return "Покупатель — продать урожай (%d шт.)" % count


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
