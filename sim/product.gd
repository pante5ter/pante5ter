class_name Product
extends RefCounted

var id: int = 0
var strain_id: String = ""
var quality: int = 0


func _init(product_id: int = 0, product_strain_id: String = "", product_quality: int = 0) -> void:
	id = product_id
	strain_id = product_strain_id
	quality = product_quality


func to_dict() -> Dictionary:
	return {"id": id, "strain_id": strain_id, "quality": quality}


static func from_dict(data: Dictionary) -> Product:
	return Product.new(int(data["id"]), String(data["strain_id"]), int(data["quality"]))
