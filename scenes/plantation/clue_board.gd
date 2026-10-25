class_name ClueBoard
extends Interactable

## Cork board on the bunker wall by the computer: one paper note per clue Reggie has pinned up.
@export var notes: Node3D

var _seen_sim: SimState
var _seen_log_size: int = -1


func _process(_delta: float) -> void:
	if Game.sim == _seen_sim and Game.sim.event_log.size() == _seen_log_size:
		return
	_seen_sim = Game.sim
	_seen_log_size = Game.sim.event_log.size()
	var shown := pinned_count()
	for index: int in notes.get_child_count():
		(notes.get_child(index) as Node3D).visible = index < shown


static func pinned_count() -> int:
	var def := Game.sim.intrigue.definition()
	return IntrigueBoard.pinned(def, Game.sim.event_log).size() if def != null else 0


func hover_text() -> String:
	var count := pinned_count()
	if count == 0:
		return "Пробковая доска — пока пусто"
	return "Пробковая доска — улик: %d" % count


func interact(level: Level) -> void:
	level.hud.close_actions()
	level.hud.phone.close()
	level.hud.computer.open(ComputerScreen.TAB_CLUES)
