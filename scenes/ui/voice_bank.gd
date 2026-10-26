class_name VoiceBank
extends RefCounted
## Looks up pre-generated ElevenLabs lines by speaker + exact text.
## Dynamic lines (with numbers/names filled in) stay silent until regenerated.

const MANIFEST_PATH: String = "res://assets/voices/manifest.json"

static var _entries: Dictionary = {}
static var _loaded: bool = false
static var _streams: Dictionary = {}


static func stream_for(speaker: String, text: String) -> AudioStream:
	_ensure_loaded()
	var key := "%s\n%s" % [speaker, text]
	var path := String(_entries.get(key, ""))
	if path.is_empty():
		return null
	if _streams.has(path):
		return _streams[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_streams[path] = stream
	return stream


static func has_line(speaker: String, text: String) -> bool:
	_ensure_loaded()
	return _entries.has("%s\n%s" % [speaker, text])


static func line_count() -> int:
	_ensure_loaded()
	return _entries.size()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_entries = parsed as Dictionary
