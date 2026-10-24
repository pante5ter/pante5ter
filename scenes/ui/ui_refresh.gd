class_name UiRefresh
extends RefCounted

## Live panels refill themselves twice a second. Swapping in identical buttons would throw away
## a press in progress (and the hover), so a fresh build replaces the old one only when it differs.


## Moves the children of `fresh` into `box` when they show something new; returns whether it did.
static func swap_if_changed(box: Container, fresh: Container) -> bool:
	if fingerprint(box) == fingerprint(fresh):
		fresh.queue_free()
		return false
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for child: Node in fresh.get_children():
		fresh.remove_child(child)
		box.add_child(child)
	fresh.queue_free()
	return true


static func fingerprint(node: Node) -> String:
	var parts := PackedStringArray()
	_collect(node, parts)
	return "|".join(parts)


## Fires on mouse down: a refill between press and release can no longer swallow the click.
static func press_on_down(button: Button) -> Button:
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	return button


static func _collect(node: Node, parts: PackedStringArray) -> void:
	for child: Node in node.get_children():
		var label := child as Label
		var button := child as Button
		if label != null:
			parts.append("L" + label.text)
		elif button != null:
			parts.append("B%s%s" % [button.text, "-" if button.disabled else "+"])
		else:
			parts.append(child.get_class())
		_collect(child, parts)
		parts.append(")")
