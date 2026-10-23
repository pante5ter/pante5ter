class_name CourierView
extends Node3D

const WALK_HOURS: float = 0.4

@export var road_point: Marker3D
@export var stash_point: Marker3D
@export var model: CharacterModel

var _watched_sim: SimState
var _seen_events: int = 0
var _last_pickup: float = -INF


func _process(_delta: float) -> void:
	var sim := Game.sim
	_track_pickups(sim)
	var now := sim.clock.elapsed_game_seconds
	var walk := WALK_HOURS * SimClock.GAME_SECONDS_PER_HOUR
	var progress := -1.0
	for order: Order in sim.orders.all():
		if order.status == Order.Status.DROPPED and order.pickup_at - now <= walk:
			progress = maxf(progress, 1.0 - (order.pickup_at - now) / walk)
	var leaving := progress < 0.0 and now - _last_pickup < walk
	if leaving:
		progress = 1.0 - (now - _last_pickup) / walk
	visible = progress >= 0.0
	if not visible:
		return
	var from := road_point.global_position
	var to := stash_point.global_position
	global_position = from.lerp(to, clampf(progress, 0.0, 1.0))
	var heading := (from - to) if leaving else (to - from)
	rotation.y = atan2(heading.x, heading.z)
	if progress >= 1.0:
		model.play_idle()
	else:
		model.play_walk()


func _track_pickups(sim: SimState) -> void:
	if sim != _watched_sim:
		_watched_sim = sim
		_seen_events = 0
		_last_pickup = -INF
	for event: SimEvent in sim.event_log.since(_seen_events):
		if event.type == EventLog.ORDER_PAID:
			_last_pickup = event.game_time
	_seen_events = sim.event_log.size()
