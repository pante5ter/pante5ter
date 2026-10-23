class_name DropOrderCommand
extends SimCommand

var order_id: int = 0


func _init(target_order_id: int) -> void:
	order_id = target_order_id
