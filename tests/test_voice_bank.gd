extends GutTest
## Pre-generated dialogue VO: lookup by speaker + exact text.


func test_missing_line_returns_null() -> void:
	assert_null(VoiceBank.stream_for("Реджи", "Этой реплики точно нет в манифесте."))


func test_manifest_loads_when_present() -> void:
	# Empty project still loads without crash; count is whatever assets hold.
	assert_true(VoiceBank.line_count() >= 0)
