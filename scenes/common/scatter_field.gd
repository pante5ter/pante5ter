class_name ScatterField
extends MultiMeshInstance3D
## Fills a rectangle with one model drawn as a MultiMesh: a whole field of crops costs a single draw call.
## Offsets come from a hash of the grid cell, so the field looks the same every run.

@export var model: PackedScene
@export var size: Vector2 = Vector2(10.0, 10.0)
@export var spacing: float = 1.0
@export_range(0.0, 0.5) var jitter: float = 0.3
@export var scale_min: float = 0.85
@export var scale_max: float = 1.15


func _ready() -> void:
	var source := model.instantiate() as Node3D
	var mesh_instance := source as MeshInstance3D
	if mesh_instance == null:
		mesh_instance = source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var columns := maxi(1, floori(size.x / spacing))
	var rows := maxi(1, floori(size.y / spacing))
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.mesh = mesh_instance.mesh
	field.instance_count = columns * rows
	var origin := Vector3(-float(columns - 1) * spacing / 2.0, 0.0, -float(rows - 1) * spacing / 2.0)
	for row: int in rows:
		for column: int in columns:
			var cell := hash(Vector2i(column, row))
			var dx := (_unit(cell, 0) - 0.5) * 2.0 * jitter * spacing
			var dz := (_unit(cell, 10) - 0.5) * 2.0 * jitter * spacing
			var spread := lerpf(scale_min, scale_max, _unit(cell, 20))
			var basis := Basis(Vector3.UP, _unit(cell, 5) * TAU).scaled(Vector3.ONE * spread)
			var at := origin + Vector3(float(column) * spacing + dx, 0.0, float(row) * spacing + dz)
			field.set_instance_transform(row * columns + column, Transform3D(basis, at))
	multimesh = field
	source.free()


func instance_count() -> int:
	return multimesh.instance_count if multimesh != null else 0


static func _unit(value: int, shift: int) -> float:
	return float((value >> shift) & 1023) / 1023.0
