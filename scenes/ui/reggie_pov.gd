class_name ReggiePov
extends Node

## «От лица Реджи»: someone walks up to the farm while Jack is away. The view goes to the field, Reggie
## walks out to meet the visitor, the talk plays between the two figures, Reggie gives the answer, and the
## view goes back to Jack. The only thing that reaches the sim is the story choice; the clock stands still.

enum Stage { IDLE, GOING, WALKING, TALKING, PARTING }

const REGGIE_MODEL: PackedScene = preload("res://assets/models/characters/worker.glb")
const DEFAULT_VISITOR_MODEL: PackedScene = preload("res://assets/models/characters/courier.glb")
const MEETING_ANCHOR: NodePath = ^"NavRegion/Container/Approach"
const STAND_IN: NodePath = ^"Reggie"
## Relative to the container's approach: down the lane to the yard.
const VISITOR_FROM: Vector3 = Vector3(3.0, 0.0, 18.0)
const MEETING: Vector3 = Vector3(1.5, 0.0, 5.0)
const TALK_GAP: float = 0.7
const WALK_TIMEOUT_SECONDS: float = 10.0
const PART_SECONDS: float = 1.8
const TITLE: String = "От лица Реджи"
const LABEL_COLOR: Color = Color(0.96, 0.84, 0.45, 1.0)

## Set by the HUD.
var hud: Hud
var stage: Stage = Stage.IDLE
var story_id: String = ""
var reggie: FlashbackActor = null
var visitor: FlashbackActor = null
var _title: Label = null
var _was_running: bool = false
var _stage_left: float = 0.0
var _stand_in: Node3D = null
var _stand_in_mode: ProcessMode = PROCESS_MODE_INHERIT


func _ready() -> void:
	_title = UiStyle.label(TITLE, 24, LABEL_COLOR)
	_title.name = "ReggiePovTitle"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.5
	_title.anchor_right = 0.5
	_title.offset_left = -200.0
	_title.offset_right = 200.0
	_title.offset_top = 64.0
	_title.offset_bottom = 96.0
	_title.visible = false
	hud.add_child.call_deferred(_title)


func is_active() -> bool:
	return stage != Stage.IDLE


## A visitor story Reggie answers: someone came to the farm and Jack is not there.
static func wants(story: StoryDef, sim: SimState) -> bool:
	return story != null and story.has_visitor() and jack_is_away(sim)


static func jack_is_away(sim: SimState) -> bool:
	return sim.day.place != DayCycle.FARM or sim.day.travelling()


## Called by the story presenter every frame while such a story waits.
func handle(story: StoryDef) -> void:
	match stage:
		Stage.IDLE:
			if hud.is_dialogue_open() or hud.night.is_open() or hud.raid_recap.is_busy() or SceneRouter.is_busy():
				return
			if _on_field():
				start(story)
			else:
				stage = Stage.GOING
				Travel.look_at(DayCycle.FARM)
		Stage.TALKING:
			if not hud.is_dialogue_open() and Game.sim.stories.pending_id == story_id:
				hud.story_presenter.present_visit(story)


func _level() -> Level:
	return hud.get_parent() as Level


func _on_field() -> bool:
	var level := _level()
	return level != null and level.scene_file_path == Travel.scene_of(DayCycle.FARM) and level.get_node_or_null(MEETING_ANCHOR) != null


func start(story: StoryDef) -> void:
	var level := _level()
	var anchor := (level.get_node(MEETING_ANCHOR) as Node3D).global_position
	stage = Stage.WALKING
	story_id = story.id
	_was_running = Game.is_running
	Game.is_running = false
	_hide_stand_in(level)
	var meeting := anchor + MEETING
	var toward_lane := (VISITOR_FROM - MEETING).normalized()
	reggie = _figure(level, REGGIE_MODEL, UiText.REGGIE, anchor)
	visitor = _figure(level, story.visitor_model if story.visitor_model != null else DEFAULT_VISITOR_MODEL, story.visitor_name, anchor + VISITOR_FROM)
	reggie.move_to(meeting - toward_lane * TALK_GAP)
	visitor.move_to(meeting + toward_lane * TALK_GAP)
	level.camera_rig.follow(reggie)
	_title.visible = true
	_stage_left = WALK_TIMEOUT_SECONDS


func _figure(level: Level, model_scene: PackedScene, title: String, at: Vector3) -> FlashbackActor:
	var actor := FlashbackActor.new()
	actor.speed = 3.6
	var model := CharacterModel.new()
	model.add_child(model_scene.instantiate())
	actor.add_child(model)
	actor.model = model
	var label := Label3D.new()
	label.text = title
	label.position = Vector3(0.0, 2.3, 0.0)
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 32
	label.outline_size = 10
	actor.add_child(label)
	level.add_child(actor)
	actor.global_position = at
	return actor


func _process(delta: float) -> void:
	if stage != Stage.WALKING and stage != Stage.TALKING and stage != Stage.PARTING:
		return
	if not is_instance_valid(reggie) or not is_instance_valid(visitor):
		finish()
		return
	_stage_left -= delta
	match stage:
		Stage.WALKING:
			if (not reggie.is_moving() and not visitor.is_moving()) or _stage_left <= 0.0:
				_talk()
		Stage.TALKING:
			if not hud.is_dialogue_open() and Game.sim.stories.pending_id != story_id:
				_part()
		Stage.PARTING:
			if _stage_left <= 0.0:
				finish()


func _talk() -> void:
	stage = Stage.TALKING
	reggie.stop()
	visitor.stop()
	reggie.face(visitor.position)
	visitor.face(reggie.position)
	var story := Game.sim.stories.find(story_id)
	if story != null and Game.sim.stories.pending_id == story_id:
		hud.story_presenter.present_visit(story)


func _part() -> void:
	stage = Stage.PARTING
	_stage_left = PART_SECONDS
	var level := _level()
	var anchor := (level.get_node(MEETING_ANCHOR) as Node3D).global_position
	visitor.move_to(anchor + VISITOR_FROM)
	reggie.move_to(anchor)


## Jack was away the whole time, so the view goes back to his scene; it restarts the clock.
func finish() -> void:
	_clear()
	Game.is_running = _was_running
	Travel.back_to_jack()


func _clear() -> void:
	for actor: FlashbackActor in [reggie, visitor]:
		if is_instance_valid(actor):
			actor.queue_free()
	reggie = null
	visitor = null
	_show_stand_in()
	if is_instance_valid(_title):
		_title.visible = false
	stage = Stage.IDLE
	story_id = ""


## The field's own Reggie follows Jack and the sim; during the visit the scene's Reggie is this one.
func _hide_stand_in(level: Level) -> void:
	_stand_in = level.get_node_or_null(STAND_IN) as Node3D
	if _stand_in == null:
		return
	_stand_in_mode = _stand_in.process_mode
	_stand_in.process_mode = Node.PROCESS_MODE_DISABLED
	_stand_in.visible = false


func _show_stand_in() -> void:
	if is_instance_valid(_stand_in):
		_stand_in.process_mode = _stand_in_mode
	_stand_in = null
