class_name RaidFlashback
extends CanvasLayer
## The gang's clip, played as one of «Молочные зубы» inside the bunker: down in the lift, knock things over
## for the camera, carry the crates to the lift and ride up. If Reggie was there, he steps in and is shoved
## aside. Display only: the sim already decided how many crates went, and nothing here touches Game.sim.

## Behind the black the clip replaced the owner's view: the owner may stop drawing its own scene.
signal opened
## The screen is black: the owner puts its scene back and calls dismiss().
signal finished

enum Phase { INTRO, PLAYING, LEAVING, ENDING, DONE }

const FLASHBACK_LAYER: int = 50
const FADE_SECONDS: float = 0.5
const CAPTION_SECONDS: float = 2.6
const SUBTITLE_SECONDS: float = 3.2
## However big the haul, a few grabs at the stack carry it all.
const MAX_TRIPS: int = 4
const TRIP_SECONDS: float = 0.9
const SCUFFLE_SECONDS: float = 0.9
const RISE_SECONDS: float = 1.4
const RISE_HEIGHT: float = 3.2
const REC_BLINK_SECONDS: float = 0.5
const CRATES_CLICK_RADIUS: float = 2.0
const LIFT_CLICK_RADIUS: float = 2.2
const PROP_CLICK_RADIUS: float = 1.0
const GUARD_REACH: float = 1.1
const LIFT_DOOR_NAME: String = "Door"
const LIFT_DOOR_OFFSET: Vector3 = Vector3(1.84, 0.0, 0.0)
## The bunker floor between the lift and the far wall: x/z of where one may walk.
const WALK_AREA: Rect2 = Rect2(-5.2, -5.0, 12.0, 10.0)
const OPERATOR_DISTANCE: float = 2.2

@export var view: SubViewportContainer
@export var camera: FlashbackCamera
@export var robber: FlashbackActor
@export var operator: FlashbackActor
@export var guard: FlashbackActor
@export var lift: Node3D
@export var lift_point: Marker3D
@export var lift_inside: Marker3D
@export var crate_stack: Node3D
@export var crates_point: Marker3D
@export var props: Node3D
@export var carried_crates: Node3D
@export var caption_label: Label
@export var subtitle_label: Label
@export var hint_label: Label
@export var rec_label: Label
@export var skip_button: Button
@export var flash: ColorRect
@export var veil: ColorRect

var total: int = 0
var carried: int = 0
var knocked: int = 0
var phase: Phase = Phase.INTRO
var guard_present: bool = false
var guard_down: bool = false
var _caption: String = ""
var _batch: int = 1
var _busy: bool = false
var _subtitle_left: float = 0.0
var _rec_left: float = REC_BLINK_SECONDS


func setup(caption: String, taken: int, with_guard: bool = false) -> void:
	_caption = caption
	total = maxi(taken, 1)
	_batch = ceili(float(total) / float(MAX_TRIPS))
	guard_present = with_guard


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
	flash.modulate.a = 0.0
	guard.visible = guard_present
	var door := _lift_door()
	if door != null:
		door.position += LIFT_DOOR_OFFSET
	_show_crates()
	camera.target = robber
	camera.snap()
	var tween := create_tween()
	tween.tween_property(veil, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_callback(_open_scene)
	tween.tween_property(veil, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_interval(CAPTION_SECONDS)
	tween.tween_callback(_start_playing)


func is_playable() -> bool:
	return phase == Phase.PLAYING and not _busy


func _open_scene() -> void:
	if phase != Phase.INTRO:
		return
	view.visible = true
	skip_button.visible = true
	caption_label.text = "%s\n%s" % [RaidRecapText.CLIP_TITLE, _caption]
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
	_rec_left -= delta
	if _rec_left <= 0.0:
		_rec_left = REC_BLINK_SECONDS
		rec_label.visible = not rec_label.visible
	_follow_robber()


func _follow_robber() -> void:
	if not operator.visible or phase == Phase.LEAVING:
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


## Where a click on the screen meets the floor; null when it misses.
func ground_point(screen_position: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_position)
	var normal := camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)


func click_ground(point: Vector3) -> void:
	if not is_playable():
		return
	var prop := _prop_near(point)
	if _flat_distance(point, crate_stack.position) < CRATES_CLICK_RADIUS or _flat_distance(point, crates_point.position) < CRATES_CLICK_RADIUS:
		go_to_crates()
	elif _flat_distance(point, lift.position) < LIFT_CLICK_RADIUS or _flat_distance(point, lift_point.position) < LIFT_CLICK_RADIUS:
		go_to_lift()
	elif prop != null:
		knock_over(prop)
	else:
		robber.move_to(_walkable(point))


func go_to_crates() -> void:
	if is_playable():
		robber.move_to(crates_point.position, _at_crates)


func go_to_lift() -> void:
	if is_playable():
		robber.move_to(lift_point.position, _board)


func knock_over(prop: FlashbackProp) -> void:
	if is_playable() and not prop.knocked:
		robber.move_to(_walkable(prop.position.lerp(robber.position, 0.25)), _knock.bind(prop))


func standing_props() -> Array[FlashbackProp]:
	var found: Array[FlashbackProp] = []
	for child: Node in props.get_children():
		var prop := child as FlashbackProp
		if prop != null and not prop.knocked:
			found.append(prop)
	return found


func _prop_near(point: Vector3) -> FlashbackProp:
	for prop: FlashbackProp in standing_props():
		if _flat_distance(point, prop.position) < PROP_CLICK_RADIUS:
			return prop
	return null


func _knock(prop: FlashbackProp) -> void:
	if not is_playable() or prop.knocked:
		return
	robber.face(prop.position)
	prop.knock(robber.position)
	knocked += 1
	if knocked == 1:
		say(RaidRecapText.banter(RaidRecapText.KNOCKED))


func _at_crates() -> void:
	if not is_playable():
		return
	if guard_present and not guard_down:
		_scuffle()
		return
	_grab()


## Reggie steps out from behind the beds and is shoved aside: a flash, and he sits down hard.
func _scuffle() -> void:
	_busy = true
	say(RaidRecapText.banter(RaidRecapText.GUARD_STEPS_IN))
	var meet := robber.position + (guard.position - robber.position).normalized() * GUARD_REACH
	guard.move_to(meet, _shove)


func _shove() -> void:
	if phase != Phase.PLAYING:
		return
	robber.face(guard.position)
	guard.face(robber.position)
	var back := (guard.position - robber.position).normalized()
	var tween := create_tween()
	tween.tween_property(robber, "position", robber.position + back * 0.4, 0.12)
	tween.tween_property(flash, "modulate:a", 0.8, 0.06)
	tween.tween_callback(_knock_guard_down.bind(back))
	tween.tween_property(robber, "position", robber.position, 0.12)
	tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	tween.tween_interval(SCUFFLE_SECONDS)
	tween.tween_callback(_after_scuffle)


func _knock_guard_down(back: Vector3) -> void:
	guard_down = true
	guard.position += back * 0.6
	guard.rotation.x = deg_to_rad(-70.0)
	say(RaidRecapText.banter(RaidRecapText.GUARD_DOWN))


func _after_scuffle() -> void:
	_busy = false
	if phase == Phase.PLAYING:
		_grab()


func _grab() -> void:
	if carried >= total:
		_hint(RaidRecapText.lift_hint())
		return
	_busy = true
	robber.face(crate_stack.position)
	if robber.model != null:
		robber.model.play_work()
	var tween := create_tween()
	tween.tween_interval(TRIP_SECONDS)
	tween.tween_callback(_take_batch)


func _take_batch() -> void:
	_busy = false
	if phase != Phase.PLAYING:
		return
	if robber.model != null:
		robber.model.play_idle()
	var first := carried == 0
	carried = mini(total, carried + _batch)
	_show_crates()
	robber.face(lift.position)
	if carried >= total:
		_hint(RaidRecapText.lift_hint())
		say(RaidRecapText.banter(RaidRecapText.LOADED))
		return
	_hint(RaidRecapText.load_hint(carried, total))
	if first:
		say(RaidRecapText.banter(RaidRecapText.FIRST_CRATE))


func _show_crates() -> void:
	var in_hands := carried_crates.get_children()
	var shown := ceili(float(carried) / float(total) * float(in_hands.size())) if total > 0 else 0
	for index: int in in_hands.size():
		(in_hands[index] as Node3D).visible = index < shown
	var stacked := crate_stack.get_children()
	var left := ceili(float(total - carried) / float(total) * float(stacked.size())) if total > 0 else 0
	for index: int in stacked.size():
		(stacked[index] as Node3D).visible = index < left


func _board() -> void:
	if not is_playable():
		return
	if carried < total:
		_hint(RaidRecapText.load_hint(carried, total))
		return
	leave()


func leave() -> void:
	phase = Phase.LEAVING
	hint_label.visible = false
	say(RaidRecapText.banter(RaidRecapText.DRIVE_OFF))
	operator.move_to(lift_inside.position + Vector3(0.0, 0.0, 0.6))
	robber.move_to(lift_inside.position, _rise)


func _rise() -> void:
	if phase != Phase.LEAVING:
		return
	robber.visible = false
	operator.stop()
	operator.visible = false
	camera.target = lift
	var tween := create_tween()
	var door := _lift_door()
	if door != null:
		tween.tween_property(door, "position", door.position - LIFT_DOOR_OFFSET, 0.3)
	tween.tween_property(lift, "position", lift.position + Vector3.UP * RISE_HEIGHT, RISE_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_end)


func _lift_door() -> Node3D:
	return lift.find_child(LIFT_DOOR_NAME, true, false) as Node3D


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
