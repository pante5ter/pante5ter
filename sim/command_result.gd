class_name CommandResult
extends RefCounted

const INVALID_PLOT: String = "invalid_plot"
const PLOT_OCCUPIED: String = "plot_occupied"
const PLOT_NOT_GROWING: String = "plot_not_growing"
const PLOT_NOT_READY: String = "plot_not_ready"
const UNKNOWN_PRODUCT: String = "unknown_product"
const UNKNOWN_COMMAND: String = "unknown_command"

var ok: bool = false
var error: String = ""
var value: int = 0


static func success(result_value: int = 0) -> CommandResult:
	var result := CommandResult.new()
	result.ok = true
	result.value = result_value
	return result


static func failure(reason: String) -> CommandResult:
	var result := CommandResult.new()
	result.error = reason
	return result
