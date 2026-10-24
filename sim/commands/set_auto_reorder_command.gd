class_name SetAutoReorderCommand
extends SimCommand

var item: String = ""
## Zero switches the rule off.
var keep: int = 0


func _init(item_id: String, keep_count: int) -> void:
	item = item_id
	keep = keep_count
