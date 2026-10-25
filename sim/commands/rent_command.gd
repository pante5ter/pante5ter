class_name RentCommand
extends SimCommand

## Jack's answer to the lord's rent call: Rent.PAY or Rent.VISIT.
var choice: String = ""


func _init(answer: String) -> void:
	choice = answer
