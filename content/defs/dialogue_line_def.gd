class_name DialogueLineDef
extends Resource

## Empty speaker means a narration line (scene caption) without a name.
@export var speaker: String = ""
@export_multiline var text: String = ""


static func make(speaker_name: String, line_text: String) -> DialogueLineDef:
	var line := DialogueLineDef.new()
	line.speaker = speaker_name
	line.text = line_text
	return line
