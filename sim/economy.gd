class_name Economy
extends RefCounted

const BUYER_ACTOR: String = "buyer"

var money: int = 0
var _strain: StrainDef
var _event_log: EventLog
var _inventory: Inventory
var _config: BalanceConfig = null


func _init(strain: StrainDef, starting_money: int, event_log: EventLog, inventory: Inventory) -> void:
	_strain = strain
	money = starting_money
	_event_log = event_log
	_inventory = inventory


func attach(config: BalanceConfig) -> void:
	_config = config


static func price_with(strain: StrainDef, quality: int) -> int:
	var t := clampf(float(quality) / 100.0, 0.0, 1.0)
	var multiplier := lerpf(strain.price_mult_at_q0, strain.price_mult_at_q100, t)
	return maxi(roundi(float(strain.base_price) * multiplier), 0)


func price_for(quality: int) -> int:
	return price_with(_strain, quality)


func price_of(product: Product) -> int:
	var strain := _config.find_strain(product.strain_id) if _config != null else null
	return price_with(strain if strain != null else _strain, product.quality)


func earn(amount: int) -> void:
	money += maxi(amount, 0)


func sell(product_id: int, now: float, actor: String) -> CommandResult:
	var product := _inventory.take(product_id)
	if product == null:
		return CommandResult.failure(CommandResult.UNKNOWN_PRODUCT)
	var price := price_of(product)
	money += price
	_event_log.record(EventLog.PRODUCT_SOLD, now, PackedStringArray([actor, BUYER_ACTOR]), {
		"product_id": product.id,
		"quality": product.quality,
		"price": price,
		"money": money,
	})
	return CommandResult.success(price)


func spend(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	return true


func to_dict() -> Dictionary:
	return {"money": money}


func load_dict(data: Dictionary) -> void:
	money = int(data["money"])
