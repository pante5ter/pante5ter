class_name UiAction
extends RefCounted

var label: String = ""
var callback: Callable = Callable()
var enabled: bool = true


static func make(action_label: String, action_callback: Callable, is_enabled: bool = true) -> UiAction:
	var action := UiAction.new()
	action.label = action_label
	action.callback = action_callback
	action.enabled = is_enabled
	return action
