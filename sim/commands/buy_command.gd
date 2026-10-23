class_name BuyCommand
extends SimCommand

var item: String = ""
var quantity: int = 1


func _init(item_id: String, item_quantity: int = 1) -> void:
	item = item_id
	quantity = item_quantity
