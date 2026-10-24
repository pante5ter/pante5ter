class_name AlertTarget
extends Marker3D

## Marks where an alert topic happens in the world, so the HUD can point at it from the screen edge.

const GROUP: String = "alert_targets"

@export var topic: String = ""


func _ready() -> void:
	add_to_group(GROUP)


func is_live() -> bool:
	return is_visible_in_tree() and Alert.is_live(topic, Game.sim)


static func find_live(tree: SceneTree, wanted_topic: String) -> AlertTarget:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var target := node as AlertTarget
		if target != null and target.topic == wanted_topic and target.is_live():
			return target
	return null
