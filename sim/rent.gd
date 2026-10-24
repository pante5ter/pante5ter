class_name Rent
extends RefCounted

const LORD_ACTOR: String = "lord"

var next_due_at: float = INF
var missed: int = 0
var evicted: bool = false
## Paid ahead to the lord; comes off the next payments.
var credit: int = 0

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


func max_missed() -> int:
	return _def.evict_after_missed if _def != null else 0


func add_credit(amount: int) -> void:
	credit += maxi(amount, 0)


func due_in(now: float) -> float:
	return maxf(next_due_at - now, 0.0)


func next_event_time() -> float:
	return INF if evicted else next_due_at


func process(now: float) -> void:
	while not evicted and now >= next_due_at:
		var due_at := next_due_at
		next_due_at += _def.period_hours * SimClock.GAME_SECONDS_PER_HOUR
		_collect(due_at)


func _collect(at: float) -> void:
	var due := maxi(_def.amount - credit, 0)
	if _economy.spend(due):
		credit = maxi(credit - _def.amount, 0)
		missed = 0
		_event_log.record(EventLog.RENT_PAID, at, PackedStringArray([LORD_ACTOR]), {
			"amount": due,
			"money": _economy.money,
		})
		return
	missed += 1
	_suspicion.add(_def.missed_suspicion)
	_event_log.record(EventLog.RENT_MISSED, at, PackedStringArray([LORD_ACTOR]), {
		"amount": _def.amount,
		"money": _economy.money,
		"missed": missed,
		"evict_after": _def.evict_after_missed,
	})
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
	}


func load_dict(data: Dictionary) -> void:
	next_due_at = ExactFloat.decode(data["next_due_at"])
	missed = int(data["missed"])
	evicted = data["evicted"] == true
	credit = int(data.get("credit", 0))
