class_name BuyCommand
extends SimCommand

var item: String = ""
var quantity: int = 1
## Over the counter of the village store, on the spot and dearer, instead of the phone shop.
var in_village: bool = false


func _init(item_id: String, item_quantity: int = 1, from_village: bool = false) -> void:
	item = item_id
	quantity = item_quantity
	in_village = from_village
