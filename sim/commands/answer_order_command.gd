class_name AnswerOrderCommand
extends SimCommand

var order_id: int = 0
var choice: String = ""


func _init(target_order_id: int, answer_choice: String) -> void:
	order_id = target_order_id
	choice = answer_choice
