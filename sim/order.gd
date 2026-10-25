class_name Order
extends RefCounted

enum Status { OFFERED, ACCEPTED, IN_TRANSIT }

var id: int = 0
var quantity: int = 0
var min_quality: int = 0
var reward: int = 0
var status: Status = Status.OFFERED
var answer_by: float = 0.0
var deadline: float = 0.0
var haggled: bool = false
var courier_id: String = ""
var product_ids: Array[int] = []
var arrives_at: float = 0.0
## A director call: short fuse, fat bonus.
var urgent: bool = false
## Overrides the usual deadline once accepted; zero keeps it.
var deadline_hours: float = 0.0
## Already held up on the road once; one hold-up per delivery.
var delayed: bool = false
## The strain the client wants; empty takes any.
var strain_id: String = ""


static func status_name(value: Status) -> String:
	return String(Status.keys()[value]).to_lower()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"quantity": quantity,
		"min_quality": min_quality,
		"reward": reward,
		"status": status_name(status),
		"answer_by": ExactFloat.encode(answer_by),
		"deadline": ExactFloat.encode(deadline),
		"haggled": haggled,
		"courier_id": courier_id,
		"product_ids": product_ids.duplicate(),
		"arrives_at": ExactFloat.encode(arrives_at),
		"urgent": urgent,
		"deadline_hours": ExactFloat.encode(deadline_hours),
		"delayed": delayed,
		"strain_id": strain_id,
	}


func accepts(product: Product) -> bool:
	return product.quality >= min_quality and (strain_id.is_empty() or product.strain_id == strain_id)


static func from_dict(data: Dictionary) -> Order:
	var order := Order.new()
	order.id = int(data["id"])
	order.quantity = int(data["quantity"])
	order.min_quality = int(data["min_quality"])
	order.reward = int(data["reward"])
	order.status = Status.get(String(data["status"]).to_upper(), Status.OFFERED) as Status
	order.answer_by = ExactFloat.decode(data["answer_by"])
	order.deadline = ExactFloat.decode(data["deadline"])
	order.haggled = data["haggled"] == true
	order.courier_id = String(data["courier_id"])
	for product_id: Variant in data["product_ids"] as Array:
		order.product_ids.append(int(product_id))
	order.arrives_at = ExactFloat.decode(data["arrives_at"])
	order.urgent = data.get("urgent", false) == true
	order.delayed = data.get("delayed", false) == true
	order.deadline_hours = ExactFloat.decode(data["deadline_hours"]) if data.has("deadline_hours") else 0.0
	order.strain_id = String(data.get("strain_id", ""))
	return order
