class_name DispatchCommand
extends SimCommand

var order_id: int = 0
var courier_id: String = ""


func _init(target_order_id: int, chosen_courier_id: String) -> void:
	order_id = target_order_id
	courier_id = chosen_courier_id
