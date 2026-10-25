class_name RaidFlashback
extends CanvasLayer
## The robbery replayed as one of «Молочные зубы»: walk to the container, carry the crates out, drive off.
## Display only. The sim already decided how many crates went, and nothing here touches Game.sim.

## Behind the black the flashback replaced the owner's view: the owner may stop drawing its own scene.
signal opened
## The screen is black: the owner puts its scene back and calls dismiss().
signal finished

enum Phase { INTRO, PLAYING, DRIVING, ENDING, DONE }

const FLASHBACK_LAYER: int = 50
const FADE_SECONDS: float = 0.5
const CAPTION_SECONDS: float = 2.6
const SUBTITLE_SECONDS: float = 3.2
## However big the haul, a few trips into the container carry it all.
const MAX_TRIPS: int = 4
const TRIP_SECONDS: float = 0.9
const DRIVE_SECONDS: float = 3.6
const CONTAINER_CLICK_RADIUS: float = 3.0
const CAR_CLICK_RADIUS: float = 2.6
## The yard in front of the container and the lane down to the car: x/z of the walkable ground.
const WALK_AREA: Rect2 = Rect2(-6.0, 4.6, 14.0, 19.4)
const OPERATOR_DISTANCE: float = 2.8

@export var view: SubViewportContainer
@export var camera: FlashbackCamera
@export var robber: FlashbackActor
@export var operator: FlashbackActor
@export var container_entrance: FlashbackContainer
@export var door_point: Marker3D
@export var car: Node3D
@export var car_door_point: Marker3D
@export var carried_crates: Node3D
@export var drive_route: Node3D
@export var caption_label: Label
@export var subtitle_label: Label
@export var hint_label: Label
@export var skip_button: Button
@export var veil: ColorRect

var total: int = 0
var carried: int = 0
var phase: Phase = Phase.INTRO
var _caption: String = ""
var _batch: int = 1
var _in_container: bool = false
var _subtitle_left: float = 0.0


func setup(caption: String, taken: int) -> void:
	_caption = caption
	total = maxi(taken, 1)
	_batch = ceili(float(total) / float(MAX_TRIPS))


func _ready() -> void:
	layer = FLASHBACK_LAYER
	view.visible = false
	caption_label.visible = false
	subtitle_label.visible = false
	hint_label.visible = false
	skip_button.visible = false
	skip_button.text = RaidRecapText.SKIP_LABEL
	skip_button.pressed.connect(skip)
	veil.modulate.a = 0.0
	_show_carried()
	camera.target = robber
	camera.snap()
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_callback(_open_scene)
	tween.tween_property(veil, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_interval(CAPTION_SECONDS)
	tween.tween_callback(_start_playing)


func is_playable() -> bool:
	return phase == Phase.PLAYING and not _in_container


func _open_scene() -> void:
	if phase != Phase.INTRO:
		return
	view.visible = true
	skip_button.visible = true
	caption_label.text = _caption
	caption_label.visible = true
	opened.emit()


func _start_playing() -> void:
	if phase != Phase.INTRO:
		return
	phase = Phase.PLAYING
	caption_label.visible = false
	_hint(RaidRecapText.WALK_HINT)
	say(RaidRecapText.banter(RaidRecapText.START))


func say(line: DialogueLineDef) -> void:
	subtitle_label.text = "%s: %s" % [line.speaker, line.text]
	subtitle_label.visible = true
	_subtitle_left = SUBTITLE_SECONDS


func _hint(text: String) -> void:
	hint_label.text = text
	hint_label.visible = true


func _process(delta: float) -> void:
	_subtitle_left = maxf(_subtitle_left - delta, 0.0)
	if _subtitle_left <= 0.0:
		subtitle_label.visible = false
	_follow_robber()


func _follow_robber() -> void:
	if not operator.visible:
		return
	var away := operator.position - robber.position
	away.y = 0.0
	if away.length() > OPERATOR_DISTANCE + 0.5:
		operator.move_to(robber.position + away.normalized() * OPERATOR_DISTANCE)
	elif not operator.is_moving():
		operator.face(robber.position)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_ESCAPE:
		skip()
		get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	get_viewport().set_input_as_handled()
	var point: Variant = ground_point(button.position)
	if point != null:
		click_ground(point as Vector3)


## Where a click on the screen meets the ground; null when it misses (the sky).
func ground_point(screen_position: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_position)
	var normal := camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)


func click_ground(point: Vector3) -> void:
	if not is_playable():
		return
	if _flat_distance(point, container_entrance.position) < CONTAINER_CLICK_RADIUS or _flat_distance(point, door_point.position) < CONTAINER_CLICK_RADIUS:
		go_to_container()
	elif _flat_distance(point, car.position) < CAR_CLICK_RADIUS:
		go_to_car()
	else:
		robber.move_to(_walkable(point))


func go_to_container() -> void:
	if is_playable():
		robber.move_to(door_point.position, _fetch_crates)


func go_to_car() -> void:
	if is_playable():
		robber.move_to(car_door_point.position, _board)


func _fetch_crates() -> void:
	if not is_playable():
		return
	if carried >= total:
		_hint(RaidRecapText.car_hint())
		return
	_in_container = true
	robber.face(container_entrance.position)
	var tween := create_tween()
	tween.tween_interval(container_entrance.open())
	tween.tween_callback(_go_inside)
	tween.tween_interval(TRIP_SECONDS)
	tween.tween_callback(_come_out)


func _go_inside() -> void:
	robber.visible = false


func _come_out() -> void:
	_in_container = false
	if phase != Phase.PLAYING:
		return
	robber.visible = true
	var first := carried == 0
	carried = mini(total, carried + _batch)
	_show_carried()
	robber.face(car.position)
	if carried >= total:
		_hint(RaidRecapText.car_hint())
		say(RaidRecapText.banter(RaidRecapText.LOADED))
		return
	_hint(RaidRecapText.load_hint(carried, total))
	if first:
		say(RaidRecapText.banter(RaidRecapText.FIRST_CRATE))


func _show_carried() -> void:
	var crates := carried_crates.get_children()
	var shown := ceili(float(carried) / float(total) * float(crates.size())) if total > 0 else 0
	for index: int in crates.size():
		(crates[index] as Node3D).visible = index < shown


func _board() -> void:
	if not is_playable():
		return
	if carried < total:
		_hint(RaidRecapText.load_hint(carried, total))
		return
	drive_off()


func drive_off() -> void:
	phase = Phase.DRIVING
	hint_label.visible = false
	robber.stop()
	robber.visible = false
	operator.stop()
	operator.visible = false
	say(RaidRecapText.banter(RaidRecapText.DRIVE_OFF))
	camera.target = car
	var points := drive_route.get_children()
	var tween := create_tween()
	var leg_seconds := DRIVE_SECONDS / float(maxi(points.size(), 1))
	for marker: Node in points:
		var target := (marker as Node3D).position
		tween.tween_callback(_aim_car.bind(target))
		tween.tween_property(car, "position", target, leg_seconds)
	tween.tween_callback(_end)


func _aim_car(target: Vector3) -> void:
	var flat := Vector3(target.x - car.position.x, 0.0, target.z - car.position.z)
	if flat.length() > 0.01:
		car.rotation.y = atan2(flat.x, flat.z)


func skip() -> void:
	if phase == Phase.ENDING or phase == Phase.DONE:
		return
	_end()


func _end() -> void:
	if phase == Phase.ENDING or phase == Phase.DONE:
		return
	phase = Phase.ENDING
	skip_button.visible = false
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_callback(_finish)


func _finish() -> void:
	phase = Phase.DONE
	finished.emit()


## The owner's scene is back behind the black: lift it and go.
func dismiss() -> void:
	view.visible = false
	caption_label.visible = false
	subtitle_label.visible = false
	hint_label.visible = false
	skip_button.visible = false
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)


func _walkable(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, WALK_AREA.position.x, WALK_AREA.end.x), 0.0, clampf(point.z, WALK_AREA.position.y, WALK_AREA.end.y))


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
