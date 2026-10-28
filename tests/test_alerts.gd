extends GutTest

const FIELD_SCENE: String = "res://scenes/field/field.tscn"
const PLANTATION_SCENE: String = "res://scenes/plantation/plantation.tscn"
const SETTLE_FRAMES: int = 3
const SCREEN: Vector2i = Vector2i(1600, 900)

var _old_screen: Vector2i = Vector2i.ZERO


func before_each() -> void:
	Game.new_game(21)
	Game.sim.first_day.skip()
	Game.is_running = false
	_old_screen = get_tree().root.size
	get_tree().root.size = SCREEN


func after_each() -> void:
	Game.is_running = false
	get_tree().root.size = _old_screen
	Game.new_game(21)


func _open(path: String) -> Level:
	var level := (load(path) as PackedScene).instantiate() as Level
	add_child_autoqfree(level)
	await wait_until(level.is_navigation_ready, 5.0)
	await wait_physics_frames(SETTLE_FRAMES)
	Game.is_running = false
	return level


func _hours_to_real(hours: float) -> float:
	return hours * Game.sim.config.real_seconds_per_game_day / 24.0


func _start_raid() -> void:
	Game.sim.raids.pending = true
	Game.sim.raids.deadline = Game.sim.clock.elapsed_game_seconds + 3600.0
	Game.sim.event_log.record(EventLog.RAID_STARTED, Game.sim.clock.elapsed_game_seconds, PackedStringArray())


func _deliver_parcel() -> void:
	Game.sim.economy.earn(1000)
	Game.sim.apply(BuyCommand.new(Supplies.FERTILIZER, 1))
	var arrives := Game.sim.supplies.arrival_for(Game.sim.clock.elapsed_game_seconds)
	var wait := (arrives - Game.sim.clock.elapsed_game_seconds) / SimClock.GAME_SECONDS_PER_HOUR + 0.1
	Game.sim.apply(AdvanceTimeCommand.new(_hours_to_real(wait)))


func _alert_button(level: Level, topic: String, text: String) -> Button:
	var panel := level.hud.alert_banner.find_child("Alert_" + topic, true, false)
	if panel == null:
		return null
	for node: Node in panel.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == text:
			return button
	return null


func test_dangerous_events_become_sticky_alerts_and_news_stays_news() -> void:
	var sim := Game.sim
	var raid := Alert.from_event(sim.event_log.record(EventLog.RAID_STARTED, 0.0, PackedStringArray()), sim)
	assert_eq(raid.severity, Alert.Severity.DANGER)
	assert_true(raid.sticky, "a raid waits for the player")
	assert_eq(raid.action, Alert.SHOW)
	var warned := Alert.from_event(sim.event_log.record(EventLog.INSPECTION_WARNED, 0.0, PackedStringArray()), sim)
	assert_true(warned.sticky)
	var paid := Alert.from_event(sim.event_log.record(EventLog.ORDER_PAID, 0.0, PackedStringArray(), {"order_id": 1, "reward": 100, "fee": 0}), sim)
	assert_eq(paid.severity, Alert.Severity.GOOD)
	assert_false(paid.sticky, "good news fades by itself")
	var parcel := Alert.from_event(sim.event_log.record(EventLog.SUPPLY_DELIVERED, 0.0, PackedStringArray(), {"item": Supplies.FERTILIZER, "quantity": 2}), sim)
	assert_string_contains(parcel.body, "у двери контейнера", "the parcel alert says where it is")
	assert_null(Alert.from_event(sim.event_log.record(EventLog.PLOT_DRIED_OUT, 0.0, PackedStringArray(), {"plot_id": 0}), sim))


func test_edge_point_pins_off_screen_points_to_the_margin() -> void:
	var screen := Vector2(1600.0, 900.0)
	assert_eq(EdgeMarkers.edge_point(screen, Vector2(400.0, 300.0), 50.0), Vector2(400.0, 300.0), "points on screen stay put")
	var right := EdgeMarkers.edge_point(screen, Vector2(5000.0, 450.0), 50.0)
	assert_almost_eq(right.x, 1550.0, 0.01)
	assert_almost_eq(right.y, 450.0, 0.01)
	var corner := EdgeMarkers.edge_point(screen, Vector2(-3200.0, -1800.0), 50.0)
	assert_almost_eq(corner.y, 50.0, 0.01, "the steeper side wins")
	assert_true(EdgeMarkers.is_on_screen(screen, Vector2(800.0, 450.0), 50.0))
	assert_false(EdgeMarkers.is_on_screen(screen, Vector2(1580.0, 450.0), 50.0))


func test_raid_shows_a_banner_and_a_marker_until_acknowledged() -> void:
	var level := await _open(FIELD_SCENE)
	_start_raid()
	await wait_process_frames(2)
	var banner := level.hud.alert_banner
	assert_has(banner.topics(), Alert.RAID)
	assert_not_null(AlertTarget.find_live(get_tree(), Alert.RAID), "the raiders are marked in the world")
	var body := banner.find_alert(Alert.RAID).body
	assert_false(body.is_empty())
	assert_false(level.hud.message_label.text.contains(body), "the raid is told once, in the banner")
	await wait_seconds(0.5)
	assert_has(banner.topics(), Alert.RAID, "still there after a while")
	var understood := _alert_button(level, Alert.RAID, "Понял")
	assert_not_null(understood)
	understood.pressed.emit()
	assert_does_not_have(banner.topics(), Alert.RAID)


func test_raid_banner_goes_away_when_the_gang_leaves() -> void:
	var level := await _open(FIELD_SCENE)
	_start_raid()
	await wait_process_frames(2)
	Game.sim.raids.pending = false
	await wait_process_frames(2)
	assert_does_not_have(level.hud.alert_banner.topics(), Alert.RAID)
	assert_null(AlertTarget.find_live(get_tree(), Alert.RAID))


func test_parcel_alert_points_at_the_container_and_shows_it() -> void:
	var level := await _open(FIELD_SCENE)
	_deliver_parcel()
	await wait_process_frames(2)
	assert_has(level.hud.alert_banner.topics(), Alert.PARCEL)
	var target := AlertTarget.find_live(get_tree(), Alert.PARCEL)
	var parcel := level.get_node("NavRegion/Parcel") as Node3D
	assert_not_null(target)
	assert_almost_eq(target.global_position.distance_to(parcel.global_position), 0.0, 0.01)
	var show := _alert_button(level, Alert.PARCEL, Alert.SHOW)
	assert_not_null(show)
	show.pressed.emit()
	var rig := level.camera_rig.global_position
	assert_almost_eq(Vector2(rig.x, rig.z).distance_to(Vector2(parcel.global_position.x, parcel.global_position.z)), 0.0, 0.5, "the camera swings to the parcel")
	Game.sim.apply(PickUpParcelCommand.new())
	await wait_process_frames(2)
	assert_does_not_have(level.hud.alert_banner.topics(), Alert.PARCEL)


func test_underground_the_parcel_alert_says_where_without_a_show_button() -> void:
	var level := await _open(PLANTATION_SCENE)
	_deliver_parcel()
	await wait_process_frames(2)
	var alert := level.hud.alert_banner.find_alert(Alert.PARCEL)
	assert_not_null(alert)
	assert_string_contains(alert.body, "контейнера")
	assert_null(_alert_button(level, Alert.PARCEL, Alert.SHOW), "nothing to show below ground")


func test_answer_on_a_call_alert_opens_the_phone_on_the_calls() -> void:
	var level := await _open(FIELD_SCENE)
	Game.sim.orders.inject(2, 50, 300, 6.0, 0.0, false, Game.sim.clock.elapsed_game_seconds)
	await wait_process_frames(2)
	var answer := _alert_button(level, Alert.CALL, Alert.ANSWER)
	assert_not_null(answer)
	answer.pressed.emit()
	assert_true(level.hud.phone.visible)
	assert_eq(level.hud.phone.current_app(), Phone.APP_CALLS)
