class_name Progress
extends RefCounted

var reached: int = 0

var _config: BalanceConfig
var _event_log: EventLog


func _init(config: BalanceConfig, event_log: EventLog) -> void:
	_config = config
	_event_log = event_log


func milestones() -> Array[MilestoneDef]:
	return _config.milestones


func next_milestone() -> MilestoneDef:
	if reached >= _config.milestones.size():
		return null
	return _config.milestones[reached]


func plot_cap() -> int:
	var cap := _config.starting_plot_cap
	for index: int in reached:
		cap = maxi(cap, _config.milestones[index].plot_cap)
	return mini(cap, _config.max_plots)


func is_strain_unlocked(strain_id: String) -> bool:
	for index: int in _config.milestones.size():
		if _config.milestones[index].unlock_strain_id == strain_id:
			return index < reached
	return true


func unlocking_milestone(strain_id: String) -> MilestoneDef:
	for milestone: MilestoneDef in _config.milestones:
		if milestone.unlock_strain_id == strain_id:
			return milestone
	return null


func update(value: int, now: float) -> void:
	while reached < _config.milestones.size() and value >= _config.milestones[reached].value:
		var milestone := _config.milestones[reached]
		reached += 1
		_event_log.record(EventLog.MILESTONE_REACHED, now, PackedStringArray(), {
			"index": reached - 1,
			"title": milestone.title,
			"value": value,
		})


func to_dict() -> Dictionary:
	return {"reached": reached}


func load_dict(data: Dictionary) -> void:
	reached = int(data["reached"])
