class_name Packer
extends RefCounted

const ACTOR: String = "packer"

var hired: bool = false
var working: bool = false
var next_check_at: float = 0.0
var next_wage_at: float = 0.0

var _def: WorkerDef = null
var _config: BalanceConfig
var _packing: Packing
var _economy: Economy
var _suspicion: Suspicion
var _event_log: EventLog


func _init(config: BalanceConfig, packing: Packing, economy: Economy, suspicion: Suspicion, event_log: EventLog) -> void:
	_config = config
	_packing = packing
	_economy = economy
	_suspicion = suspicion
	_event_log = event_log
	if not config.packer_candidates.is_empty():
		_def = config.packer_candidates[0]


func definition() -> WorkerDef:
	return _def


func hire(worker_id: String, now: float, actor: String) -> CommandResult:
	var chosen := _config.find_packer(worker_id)
	if chosen == null:
		return CommandResult.failure(CommandResult.UNKNOWN_WORKER)
	if hired:
		return CommandResult.failure(CommandResult.WORKER_ALREADY_HIRED)
	if not _economy.spend(chosen.daily_wage):
		return CommandResult.failure(CommandResult.NOT_ENOUGH_MONEY)
	_def = chosen
	hired = true
	working = false
	next_check_at = now
	next_wage_at = now + SimClock.GAME_SECONDS_PER_DAY
	_event_log.record(EventLog.WORKER_HIRED, now, PackedStringArray([actor, ACTOR]), {
		"worker_id": _def.id,
		"role": WorkerDef.PACKER,
		"wage": _def.daily_wage,
		"money": _economy.money,
	})
	return CommandResult.success()


func fire(now: float, actor: String) -> CommandResult:
	if not hired:
		return CommandResult.failure(CommandResult.WORKER_NOT_HIRED)
	hired = false
	working = false
	_event_log.record(EventLog.WORKER_FIRED, now, PackedStringArray([actor, ACTOR]), {"worker_id": _def.id})
	return CommandResult.success()


func next_event_time() -> float:
	if not hired:
		return INF
	return minf(next_wage_at, _packing.ends_at if working else next_check_at)


func process(now: float) -> void:
	if not hired:
		return
	if now >= next_wage_at:
		_pay_wage(now)
		if not hired:
			return
	if working and not _packing.busy():
		working = false
		next_check_at = now
	if working or now < next_check_at:
		return
	if _suspicion.quiet or _packing.busy() or _packing.unpacked_count() == 0:
		next_check_at = now + _def.idle_check_minutes * 60.0
		return
	if _packing.start(now, ACTOR, _def.competence).ok:
		working = true


func _pay_wage(now: float) -> void:
	if _economy.spend(_def.daily_wage):
		next_wage_at += SimClock.GAME_SECONDS_PER_DAY
		_suspicion.add(_def.talkativeness)
		_event_log.record(EventLog.WORKER_PAID, now, PackedStringArray([ACTOR]), {
			"worker_id": _def.id,
			"wage": _def.daily_wage,
			"money": _economy.money,
		})
		return
	hired = false
	working = false
	_event_log.record(EventLog.WORKER_QUIT, now, PackedStringArray([ACTOR]), {
		"worker_id": _def.id,
		"reason": "unpaid",
		"money": _economy.money,
	})


func to_dict() -> Dictionary:
	return {
		"worker_id": _def.id if _def != null else "",
		"hired": hired,
		"working": working,
		"next_check_at": ExactFloat.encode(next_check_at),
		"next_wage_at": ExactFloat.encode(next_wage_at),
	}


func load_dict(data: Dictionary) -> void:
	var stored := _config.find_packer(String(data["worker_id"]))
	if stored != null:
		_def = stored
	hired = data["hired"] == true and _def != null
	working = data["working"] == true
	next_check_at = ExactFloat.decode(data["next_check_at"])
	next_wage_at = ExactFloat.decode(data["next_wage_at"])
