class_name SimRng
extends RefCounted

var _generator: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0


func _init(seed_value: int = 0) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	_seed = seed_value
	_generator.seed = seed_value


func get_seed() -> int:
	return _seed


func randi_range(from: int, to: int) -> int:
	return _generator.randi_range(from, to)


func randf() -> float:
	return _generator.randf()


func randf_range(from: float, to: float) -> float:
	return _generator.randf_range(from, to)


func to_dict() -> Dictionary:
	return {
		"seed": str(_seed),
		"state": str(_generator.state),
	}


func load_dict(data: Dictionary) -> void:
	reseed(String(data["seed"]).to_int())
	_generator.state = String(data["state"]).to_int()
