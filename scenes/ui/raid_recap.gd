class_name RaidRecap
extends Node

## After a robbery Jack missed, Reggie calls; «Как это было?» cuts to the flashback of that night and back.
## The clock stands still from the call to Reggie's last word. Nothing here sends a command: the sim
## already took the crates, the flashback only replays it.

enum Stage { IDLE, CALLING, ASKED, FLASHBACK, CLOSING }

const FLASHBACK_SCENE: PackedScene = preload("res://scenes/flashback/raid_flashback.tscn")

## Shared by the HUD of every level, so a scene change between the robbery and the call loses nothing.
static var _watched_sim: SimState = null
static var _seen: int = 0

## Set by the HUD.
var hud: Hud
var stage: Stage = Stage.IDLE
var flashback: RaidFlashback = null
var _robbery: SimEvent = null
var _was_running: bool = false
var _asked: bool = false
var _level: Node = null
var _level_mode: ProcessMode = PROCESS_MODE_INHERIT
var _level_was_visible: bool = true


func _process(_delta: float) -> void:
	var sim := Game.sim
	if sim == null:
		return
	if sim != _watched_sim:
		_watched_sim = sim
		_seen = sim.event_log.size()
		return
	if stage != Stage.IDLE or not _can_call():
		return
	var robbery := Raids.last_unattended_robbery_since(sim.event_log, _seen)
	_seen = sim.event_log.size()
	if robbery != null:
		call_about(robbery)


func _can_call() -> bool:
	return not hud.is_dialogue_open() and not hud.night.is_open() and not SceneRouter.is_busy()


func is_busy() -> bool:
	return stage != Stage.IDLE


func call_about(robbery: SimEvent) -> void:
	_robbery = robbery
	_asked = false
	_was_running = Game.is_running
	stage = Stage.CALLING
	hud.play_dialogue(RaidRecapText.call_lines(robbery), RaidRecapText.CALL_CHOICES)
	hud.dialogue_box.chosen.connect(_on_choice, CONNECT_ONE_SHOT)


func _on_choice(index: int) -> void:
	if stage != Stage.CALLING:
		return
	if index == RaidRecapText.ASK:
		_asked = true
		stage = Stage.ASKED
		hud.dialogue_finished.connect(start_flashback, CONNECT_ONE_SHOT)
		hud.play_dialogue(RaidRecapText.ask_lines())
		return
	_close()


func start_flashback() -> void:
	stage = Stage.FLASHBACK
	Game.is_running = false
	_level = hud.get_parent()
	if _level != null:
		_level_mode = _level.process_mode
		_level.process_mode = Node.PROCESS_MODE_DISABLED
	flashback = FLASHBACK_SCENE.instantiate() as RaidFlashback
	flashback.setup(RaidRecapText.caption(_robbery), Raids.crates_taken(_robbery))
	flashback.opened.connect(_hide_level, CONNECT_ONE_SHOT)
	flashback.finished.connect(_on_flashback_finished, CONNECT_ONE_SHOT)
	hud.get_tree().root.add_child(flashback)


## Behind the flashback the level goes dark too: two 3D worlds are not drawn at once.
func _hide_level() -> void:
	var visual := _level as Node3D
	if visual != null and stage == Stage.FLASHBACK:
		_level_was_visible = visual.visible
		visual.visible = false


func _on_flashback_finished() -> void:
	_restore_level()
	if is_instance_valid(flashback):
		flashback.dismiss()
	flashback = null
	_close()


func _restore_level() -> void:
	if not is_instance_valid(_level):
		return
	_level.process_mode = _level_mode
	var visual := _level as Node3D
	if visual != null:
		visual.visible = _level_was_visible
	_level = null


func _close() -> void:
	stage = Stage.CLOSING
	hud.dialogue_finished.connect(_on_closed, CONNECT_ONE_SHOT)
	hud.play_dialogue(RaidRecapText.closing_lines(_robbery, _asked))


func _on_closed() -> void:
	stage = Stage.IDLE
	_robbery = null
	Game.is_running = _was_running


func _exit_tree() -> void:
	if is_instance_valid(flashback):
		flashback.queue_free()
	flashback = null
