class_name Order
extends RefCounted

enum Status { OPEN, DROPPED }

var id: int = 0
var quantity: int = 0
var min_quality: int = 0
var reward: int = 0
var deadline: float = 0.0
var status: Status = Status.OPEN
var pickup_at: float = 0.0


static func status_name(value: Status) -> String:
	return String(Status.keys()[value]).to_lower()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"quantity": quantity,
		"min_quality": min_quality,
		"reward": reward,
		"deadline": ExactFloat.encode(deadline),
		"status": status_name(status),
		"pickup_at": ExactFloat.encode(pickup_at),
	}


static func from_dict(data: Dictionary) -> Order:
	var order := Order.new()
	order.id = int(data["id"])
	order.quantity = int(data["quantity"])
	order.min_quality = int(data["min_quality"])
	order.reward = int(data["reward"])
	order.deadline = ExactFloat.decode(data["deadline"])
	order.status = Status.get(String(data["status"]).to_upper(), Status.OPEN) as Status
	order.pickup_at = ExactFloat.decode(data["pickup_at"])
	return order
