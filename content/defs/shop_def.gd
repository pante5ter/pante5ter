class_name ShopDef
extends Resource

## The phone shop's daily delivery, the village supply store and the big kit.

@export_group("Daily delivery")
## Everything ordered arrives together at this hour at the container door. Negative: each order
## comes on its own after BalanceConfig.delivery_hours, as before.
@export var delivery_hour: float = -1.0
## Orders placed after this hour wait for the delivery after next. Equal to delivery_hour: right up to it.
@export var cutoff_hour: float = -1.0

@export_group("Village store")
## Jack buys on the spot when he is in the village, at this share over the shop price.
@export var village_markup: float = 0.0
## Only these items; seeds come from the Dutch.
@export var village_items: Array[String] = []

@export_group("Upgrades")
@export var upgrades: Array[UpgradeDef] = []
## Hour of the daily bill for everything installed.
@export var bill_hour: float = 9.0


func find_upgrade(upgrade_id: String) -> UpgradeDef:
	for upgrade: UpgradeDef in upgrades:
		if upgrade.id == upgrade_id:
			return upgrade
	return null
