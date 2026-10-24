extends GutTest

## Playtest round 4: «нафасованного» read as a typo — the shelf line says plainly what is not packed yet.


func test_the_stock_line_names_unpacked_harvest_plainly() -> void:
	var config := (load("res://content/balance.tres") as BalanceConfig).duplicate() as BalanceConfig
	config.first_day = null
	config.director = null
	var state := SimState.new(config, 1)
	state.inventory.create(config.strain.id, 50).packed = true
	state.inventory.create(config.strain.id, 50)
	state.inventory.create(config.strain.id, 50)
	var line := UiText.stock(state)
	assert_string_contains(line, "1 коробка на полке")
	assert_string_contains(line, "ещё не расфасовано: 2")
	assert_false(line.contains("нефасован"))


func test_counts_agree_with_the_noun() -> void:
	var forms: Dictionary[int, String] = {0: "коробок", 1: "коробка", 2: "коробки", 4: "коробки", 5: "коробок", 11: "коробок", 12: "коробок", 21: "коробка", 22: "коробки", 111: "коробок", 101: "коробка"}
	for count: int in forms:
		assert_eq(UiText.plural(count, "коробка", "коробки", "коробок"), forms[count], str(count))
