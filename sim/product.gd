class_name Product
extends RefCounted

var id: int = 0
var strain_id: String = ""
var quality: int = 0
var packed: bool = false
## Brought to the stash in the village; packed products are always there.
var at_stash: bool = false


func _init(product_id: int = 0, product_strain_id: String = "", product_quality: int = 0) -> void:
	id = product_id
	strain_id = product_strain_id
	quality = product_quality


func to_dict() -> Dictionary:
	return {"id": id, "strain_id": strain_id, "quality": quality, "packed": packed, "at_stash": at_stash}


## A crate still waiting at the farm to be driven to the stash.
func on_farm() -> bool:
	return not at_stash and not packed


static func from_dict(data: Dictionary) -> Product:
	var product := Product.new(int(data["id"]), String(data["strain_id"]), int(data["quality"]))
	product.packed = data["packed"] == true
	product.at_stash = data.get("at_stash", false) == true
	return product
