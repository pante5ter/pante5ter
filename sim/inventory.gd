class_name Inventory
extends RefCounted

var _products: Array[Product] = []
var _next_id: int = 1


func create(strain_id: String, quality: int) -> Product:
	var product := Product.new(_next_id, strain_id, quality)
	_next_id += 1
	_products.append(product)
	return product


func find(product_id: int) -> Product:
	for product: Product in _products:
		if product.id == product_id:
			return product
	return null


func take(product_id: int) -> Product:
	var product := find(product_id)
	if product != null:
		_products.erase(product)
	return product


func count() -> int:
	return _products.size()


func products() -> Array[Product]:
	return _products.duplicate()


func to_dict() -> Dictionary:
	var items: Array[Dictionary] = []
	for product: Product in _products:
		items.append(product.to_dict())
	return {"next_id": _next_id, "products": items}


func load_dict(data: Dictionary) -> void:
	_next_id = int(data["next_id"])
	_products.clear()
	for item: Variant in data["products"] as Array:
		_products.append(Product.from_dict(item as Dictionary))
