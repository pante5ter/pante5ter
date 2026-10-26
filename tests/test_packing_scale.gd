extends GutTest

## «Весы» at the stash bench: opens from the bench, stops the clock, hands its round to the sim.

const STASH_SCENE: String = "res://scenes/stash/stash.tscn"
const SETTLE_FRAMES: int = 3


func before_each() -> void:
	Game.new_game(42)
	Game.sim.first_day.skip()
	Game.is_running = false


func after_each() -> void:
	Game.is_running = false
	Game.new_game(42)


func _open_stash() -> Level:
	assert_true(Game.sim.apply(TravelCommand.new(DayCycle.STASH)).ok)
	var level := (load(STASH_SCENE) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	for quality: int in [60, 70]:
		Game.sim.inventory.create(Game.sim.config.strain.id, quality).at_stash = true
	return level


func _bench(level: Level) -> PackingBench:
	return level.get_node("NavRegion/Bench") as PackingBench


func _labels(level: Level) -> Array[String]:
	var result: Array[String] = []
	for action: UiAction in _bench(level).actions(level):
		result.append(action.label)
	return result


## Pours one bag until the needle shows `grams`, then lets go.
func _weigh(game: PackingScale, grams: float) -> void:
	game.press()
	var rate := Game.sim.hand_packing.definition().target_grams / game.current_fill_seconds()
	game._process(grams / rate)
	game.release()
	game._process(PackingScale.SETTLE_SECONDS + 0.01)


func test_bench_offers_the_scale_and_the_automatic_job() -> void:
	var level := await _open_stash()
	var labels := _labels(level)
	assert_true(labels.any(func(label: String) -> bool: return label.begins_with("Фасовать самому: «Весы»")))
	assert_true(labels.any(func(label: String) -> bool: return label.begins_with("Расфасовать автоматически")))


func test_opening_the_scale_stops_the_clock_and_changes_nothing() -> void:
	var level := await _open_stash()
	Game.is_running = true
	var before := Game.sim.to_json()
	_bench(level).interact(level)
	assert_true(level.hud.action_menu.choose_label("Фасовать самому"))
	var game := level.hud.get_node_or_null("PackingScale") as PackingScale
	assert_not_null(game, "the scale opens over the HUD")
	assert_false(Game.is_running, "the game clock stands still")
	await wait_process_frames(5)
	assert_eq(game.bags, Game.sim.hand_packing.bags_now())
	assert_eq(Game.sim.to_json(), before, "playing the round touches nothing in the sim")
	game.cancel()
	assert_true(Game.is_running, "the clock runs again")
	assert_eq(Game.sim.to_json(), before, "backing out packs nothing")


func test_skipping_to_auto_runs_the_usual_job_without_a_bonus() -> void:
	var level := await _open_stash()
	var game := _bench(level).open_scale(level)
	game.choose_auto()
	assert_true(Game.sim.packing.busy())
	assert_true(Game.sim.event_log.of_type(EventLog.PACKING_HAND_SCORED).is_empty())
	var qualities: Array[int] = []
	for product: Product in Game.sim.inventory.at_stash():
		qualities.append(product.quality)
	qualities.sort()
	assert_eq(qualities, [60, 70] as Array[int])


func test_a_played_round_goes_to_the_sim_as_one_command() -> void:
	var level := await _open_stash()
	var game := _bench(level).open_scale(level)
	var def := Game.sim.hand_packing.definition()
	watch_signals(game)
	var before := Game.sim.to_json()
	for bag: int in game.bags:
		_weigh(game, def.target_grams)
	assert_eq(game.phase, PackingScale.Phase.SUMMARY)
	assert_eq(game.best_streak, game.bags, "every bag stamped «Идеально»")
	assert_eq(Game.sim.to_json(), before, "nothing changes before the round is handed in")
	game.confirm()
	assert_signal_emitted(game, "finished")
	var events := Game.sim.event_log.of_type(EventLog.PACKING_HAND_SCORED)
	assert_eq(events.size(), 1)
	assert_eq(int(events[0].data["quality_bonus"]), def.max_quality_bonus)
	assert_true(Game.sim.packing.busy())
	var qualities: Array[int] = []
	for product: Product in Game.sim.inventory.at_stash():
		qualities.append(product.quality)
	qualities.sort()
	assert_eq(qualities, [60 + def.max_quality_bonus, 70 + def.max_quality_bonus] as Array[int])


func test_overfilling_spills_and_counts_as_a_miss() -> void:
	var level := await _open_stash()
	var game := _bench(level).open_scale(level)
	var def := Game.sim.hand_packing.definition()
	game.press()
	game._process(game.current_fill_seconds() * 10.0)
	assert_eq(game.phase, PackingScale.Phase.SETTLING, "the bag stops itself at the end of the dial")
	assert_almost_eq(game.misses[0], def.scale_max_grams - def.target_grams, 0.001)
	assert_eq(game.streak, 0)
	game.cancel()


func test_the_scale_waits_while_the_bench_is_busy() -> void:
	var level := await _open_stash()
	assert_true(Game.sim.apply(PackCommand.new()).ok)
	var labels := _labels(level)
	assert_false(labels.any(func(label: String) -> bool: return label.begins_with("Фасовать самому")))
