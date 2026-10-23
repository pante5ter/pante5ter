class_name SellCommand
extends SimCommand

var product_id: int = 0


func _init(target_product_id: int) -> void:
	product_id = target_product_id
