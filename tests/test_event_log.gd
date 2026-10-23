extends GutTest


func test_record_stores_all_fields() -> void:
	var event_log := EventLog.new()
	var event := event_log.record(EventLog.PLOT_PLANTED, 12.5, PackedStringArray(["player", "plot:0"]), {"plot_id": 0})
	assert_eq(event.seq, 0)
	assert_eq(event.type, EventLog.PLOT_PLANTED)
	assert_eq(event.game_time, 12.5)
	assert_eq(event.actors, PackedStringArray(["player", "plot:0"]))
	assert_true(event.data.has("plot_id"))
	assert_eq(event_log.size(), 1)


func test_seq_increments_in_order() -> void:
	var event_log := EventLog.new()
	event_log.record("a", 0.0, PackedStringArray())
	event_log.record("b", 1.0, PackedStringArray())
	event_log.record("c", 2.0, PackedStringArray())
	var seqs: Array[int] = []
	for event: SimEvent in event_log.entries():
		seqs.append(event.seq)
	assert_eq(seqs, [0, 1, 2])
	assert_eq(event_log.last().type, "c")


func test_of_type_filters() -> void:
	var event_log := EventLog.new()
	event_log.record(EventLog.PLOT_WATERED, 0.0, PackedStringArray())
	event_log.record(EventLog.PLOT_PLANTED, 1.0, PackedStringArray())
	event_log.record(EventLog.PLOT_WATERED, 2.0, PackedStringArray())
	assert_eq(event_log.of_type(EventLog.PLOT_WATERED).size(), 2)
	assert_eq(event_log.of_type(EventLog.PRODUCT_SOLD).size(), 0)


func test_entries_returns_copy() -> void:
	var event_log := EventLog.new()
	event_log.record("a", 0.0, PackedStringArray())
	event_log.entries().clear()
	assert_eq(event_log.size(), 1)


func test_round_trip_through_json_is_identical() -> void:
	var event_log := EventLog.new()
	event_log.record(EventLog.PLOT_HARVESTED, 3600.25, PackedStringArray(["player"]), {"plot_id": 2, "quality": 71, "note": "ok"})
	event_log.record(EventLog.PRODUCT_SOLD, 7200.0, PackedStringArray(["player", "buyer"]), {"price": 133})
	var json_text := JSON.stringify(event_log.to_array(), "", true, true)

	var restored := EventLog.new()
	restored.load_array(JSON.parse_string(json_text) as Array)

	assert_eq(JSON.stringify(restored.to_array(), "", true, true), json_text)
	assert_eq(restored.size(), 2)
	assert_eq(restored.last().actors, PackedStringArray(["player", "buyer"]))
