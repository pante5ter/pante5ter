class_name CommandResult
extends RefCounted

const INVALID_PLOT: String = "invalid_plot"
const PLOT_OCCUPIED: String = "plot_occupied"
const PLOT_NOT_GROWING: String = "plot_not_growing"
const PLOT_NOT_READY: String = "plot_not_ready"
const UNKNOWN_PRODUCT: String = "unknown_product"
const UNKNOWN_COMMAND: String = "unknown_command"
const WORKER_ALREADY_HIRED: String = "worker_already_hired"
const NOT_ENOUGH_MONEY: String = "not_enough_money"
const WORKER_NOT_HIRED: String = "worker_not_hired"
const UNKNOWN_STRAIN: String = "unknown_strain"
const NO_SEEDS: String = "no_seeds"
const NO_FERTILIZER: String = "no_fertilizer"
const ALREADY_DONE: String = "already_done"
const PLOT_NOT_BUSH: String = "plot_not_bush"
const UNKNOWN_ITEM: String = "unknown_item"
const INVALID_QUANTITY: String = "invalid_quantity"
const MAX_PLOTS: String = "max_plots"
const UNKNOWN_ORDER: String = "unknown_order"
const ORDER_NOT_OPEN: String = "order_not_open"
const NOT_ENOUGH_PRODUCT: String = "not_enough_product"
const STRAIN_LOCKED: String = "strain_locked"
const NO_SUPPLY: String = "no_supply"
const NO_PROBLEM: String = "no_problem"
const NO_RAID: String = "no_raid"
const UNKNOWN_CHOICE: String = "unknown_choice"
const UNKNOWN_WORKER: String = "unknown_worker"
const TOO_MANY_COURIERS: String = "too_many_couriers"
const COURIER_BUSY: String = "courier_busy"
const LYING_LOW: String = "lying_low"
const NOTHING_TO_PACK: String = "nothing_to_pack"
const NO_PARCEL: String = "no_parcel"
const EVICTED: String = "evicted"
const UNKNOWN_SKILL: String = "unknown_skill"
const HELPER_AWAY: String = "helper_away"
const NOTHING_TO_RESTOCK: String = "nothing_to_restock"
const NO_STORY: String = "no_story"
const COURIER_BANNED: String = "courier_banned"
const CROP_EATEN: String = "crop_eaten"
const CREW_FULL: String = "crew_full"
const CRATES_ON_FARM: String = "crates_on_farm"
const NOTHING_TO_HAUL: String = "nothing_to_haul"
const HAUL_UNDER_WAY: String = "haul_under_way"
const UNKNOWN_PLACE: String = "unknown_place"
const ON_THE_ROAD: String = "on_the_road"
const NOT_AT_HOME: String = "not_at_home"
const NOT_AT_FARM: String = "not_at_farm"
const TOO_EARLY_TO_SLEEP: String = "too_early_to_sleep"
const UPGRADE_LOCKED: String = "upgrade_locked"
const NEEDS_UPGRADE: String = "needs_upgrade"
const NOT_IN_VILLAGE: String = "not_in_village"
const NOT_SOLD_IN_VILLAGE: String = "not_sold_in_village"

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
