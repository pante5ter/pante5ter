class_name StockShelf
extends Node3D

const COLUMNS: int = 4
const LEVELS: int = 3
const SLOT: Vector3 = Vector3(0.45, 0.62, 0.0)

@export var box_scene: PackedScene
@export var box_scale: float = 1.4
@export var label: Label3D

var _boxes: Array[Node3D] = []


func _ready() -> void:
	for level_index: int in LEVELS:
		for column: int in COLUMNS:
			var box := box_scene.instantiate() as Node3D
			box.position = Vector3((float(column) - float(COLUMNS - 1) / 2.0) * SLOT.x, 0.08 + float(level_index) * SLOT.y, 0.0)
			box.scale = Vector3.ONE * box_scale
			box.visible = false
			add_child(box)
			_boxes.append(box)


func capacity() -> int:
	return _boxes.size()


func shown_boxes() -> int:
	return _boxes.filter(func(box: Node3D) -> bool: return box.visible).size()


func _process(_delta: float) -> void:
	var packed := 0
	for product: Product in Game.sim.inventory.products():
		if product.packed:
			packed += 1
	for index: int in _boxes.size():
		_boxes[index].visible = index < packed
	label.text = "Склад: %d коробок" % packed
