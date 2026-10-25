class_name Rent
extends RefCounted

const LORD_ACTOR: String = "lord"
## Jack's answers to the lord's call.
const PAY: String = "pay"
const VISIT: String = "visit"
## Where the money changed hands, in RENT_PAID.
const BY_PHONE: String = "phone"
const AT_MANOR: String = "manor"
## call_stage: the lord has rung and waits for an answer / Jack promised to bring it to the manor.
const CALLED: String = "called"
const PROMISED: String = "promised"

var next_due_at: float = INF
var missed: int = 0
var evicted: bool = false
## Paid ahead to the lord; comes off the next payments.
var credit: int = 0
## About the payment due at next_due_at: "" until the lord rings, then CALLED or PROMISED.
var call_stage: String = ""

var _def: RentDef
var _economy: Economy
var _suspicion: Suspicion
var _event_log: EventLog


func _init(def: RentDef, economy: Economy, suspicion: Suspicion, event_log: EventLog) -> void:
	_def = def
	_economy = economy
	_suspicion = suspicion
	_event_log = event_log
	if def != null and def.amount > 0:
		next_due_at = def.first_due_hours * SimClock.GAME_SECONDS_PER_HOUR


func amount() -> int:
	return _def.amount if _def != null else 0


## What the next payment actually takes once the credit is counted.
func owed() -> int:
	return maxi(amount() - credit, 0)


func max_missed() -> int:
	return _def.evict_after_missed if _def != null else 0


func add_credit(amount: int) -> void:
	credit += maxi(amount, 0)


func due_in(now: float) -> float:
	return maxf(next_due_at - now, 0.0)


func call_pending() -> bool:
	return call_stage == CALLED


func visit_promised() -> bool:
	return call_stage == PROMISED


## Empty when Jack can pay right now, else the reason he cannot.
func can_pay() -> String:
	if evicted:
		return CommandResult.EVICTED
	if call_stage.is_empty():
		return CommandResult.NO_STORY
	if _economy.money < owed():
		return CommandResult.NOT_ENOUGH_MONEY
	return ""


func next_event_time() -> float:
	return INF if evicted else minf(_call_time(), next_due_at)


func process(now: float) -> void:
	while not evicted:
		var call_at := _call_time()
		if call_at <= now and call_at < next_due_at:
			_call(call_at)
		elif now >= next_due_at:
			var due_at := next_due_at
			next_due_at += _def.period_hours * SimClock.GAME_SECONDS_PER_HOUR
			_settle(due_at)
		else:
			return


func answer(choice: String, now: float, actor: String) -> CommandResult:
	if choice != PAY and choice != VISIT:
		return CommandResult.failure(CommandResult.UNKNOWN_CHOICE)
	if call_stage.is_empty():
		return CommandResult.failure(CommandResult.NO_STORY)
	if choice == VISIT:
		return _promise_visit(now, actor)
	var refused := can_pay()
	if not refused.is_empty():
		return CommandResult.failure(refused)
	var due := owed()
	_economy.spend(due)
	var where := AT_MANOR if visit_promised() else BY_PHONE
	_paid()
	call_stage = ""
	next_due_at += _def.period_hours * SimClock.GAME_SECONDS_PER_HOUR
	_event_log.record(EventLog.RENT_PAID, now, PackedStringArray([actor, LORD_ACTOR]), {
		"amount": due,
		"money": _economy.money,
		"where": where,
	})
	return CommandResult.success(due)


func _promise_visit(now: float, actor: String) -> CommandResult:
	if visit_promised():
		return CommandResult.failure(CommandResult.ALREADY_DONE)
	call_stage = PROMISED
	_event_log.record(EventLog.RENT_VISIT_PROMISED, now, PackedStringArray([actor, LORD_ACTOR]), {
		"amount": owed(),
		"due_at": next_due_at,
	})
	return CommandResult.success()


## When the lord rings about the next payment; INF once he has, or when he never does.
func _call_time() -> float:
	if _def == null or _def.call_ahead_hours <= 0.0 or not call_stage.is_empty():
		return INF
	return next_due_at - _def.call_ahead_hours * SimClock.GAME_SECONDS_PER_HOUR


func _call(at: float) -> void:
	call_stage = CALLED
	_event_log.record(EventLog.RENT_CALLED, at, PackedStringArray([LORD_ACTOR]), {
		"amount": owed(),
		"due_at": next_due_at,
	})


## The due hour: a broken promise to come is a missed payment; otherwise the rent is taken if it can be.
func _settle(at: float) -> void:
	var promised := visit_promised()
	call_stage = ""
	if promised:
		_miss(at, true)
		return
	var due := owed()
	if _economy.spend(due):
		_paid()
		_event_log.record(EventLog.RENT_PAID, at, PackedStringArray([LORD_ACTOR]), {
			"amount": due,
			"money": _economy.money,
		})
		return
	_miss(at, false)


func _paid() -> void:
	credit = maxi(credit - _def.amount, 0)
	missed = 0


func _miss(at: float, promised: bool) -> void:
	missed += 1
	_suspicion.add(_def.missed_suspicion)
	var data := {
		"amount": _def.amount,
		"money": _economy.money,
		"missed": missed,
		"evict_after": _def.evict_after_missed,
	}
	if promised:
		data["promised"] = true
	_event_log.record(EventLog.RENT_MISSED, at, PackedStringArray([LORD_ACTOR]), data)
	if missed >= _def.evict_after_missed:
		evicted = true
		next_due_at = INF
		_event_log.record(EventLog.RENT_EVICTED, at, PackedStringArray([LORD_ACTOR]), {"missed": missed})


func to_dict() -> Dictionary:
	return {
		"next_due_at": ExactFloat.encode(next_due_at),
		"missed": missed,
		"evicted": evicted,
		"credit": credit,
		"call_stage": call_stage,
	}


func load_dict(data: Dictionary) -> void:
	next_due_at = ExactFloat.decode(data["next_due_at"])
	missed = int(data["missed"])
	evicted = data["evicted"] == true
	credit = int(data.get("credit", 0))
	var stage := String(data.get("call_stage", ""))
	call_stage = stage if stage == CALLED or stage == PROMISED else ""
