class_name GuideMarker
extends Control

## Points at what the guide's current step is about: a pulsing ring with an arrow over it on screen,
## an arrow pinned to the screen edge when it is off. A step done elsewhere points at the way there.

const CONTAINER: String = "container"
const BED: String = "bed"
const CRATES: String = "crates"
const BENCH: String = "bench"
const COMPUTER: String = "computer"
const CAR: String = "car"
const PHONE: String = "phone"
const HEAD_HEIGHT: float = 1.6
const MARGIN: float = 64.0
const RING: float = 30.0
const PULSE_SPEED: float = 4.0
const RESCAN_SECONDS: float = 1.0
const LABEL: String = "Сюда"

var hud: Hud

var _time: float = 0.0
var _rescan_left: float = 0.0
var _nodes: Dictionary[String, Node3D] = {}
var _grid: PlotsGrid


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## What the step points at from where the view is; empty when there is nothing to point at here.
static func target_kind(sim: SimState, place: String, underground: bool) -> String:
	var guide := sim.first_day.guide
	if not guide.active() or sim.day.travelling() or sim.day.place != place:
		return ""
	var on_field := place == DayCycle.FARM and not underground
	match guide.current():
		Guide.Step.GO_DOWN:
			return CONTAINER if on_field else ""
		Guide.Step.PLANT, Guide.Step.WATER, Guide.Step.PRUNE, Guide.Step.HARVEST:
			if underground:
				return BED if target_plot(sim) >= 0 else ""
			return CONTAINER if on_field else ""
		Guide.Step.HIRE:
			return PHONE
		Guide.Step.HAUL:
			if sim.inventory.farm_crates().is_empty() or sim.stash.on_the_road():
				return ""
			return CRATES if underground else (CONTAINER if on_field else "")
		Guide.Step.PACK:
			if place == DayCycle.STASH:
				return BENCH if sim.packing.unpacked_count() > 0 and not sim.packing.busy() else ""
			return CAR if on_field and not sim.inventory.at_stash().is_empty() else ""
		Guide.Step.SEND:
			if underground or place == DayCycle.STASH:
				return COMPUTER if ComputerDesk.ready_orders() > 0 else ""
			return CONTAINER if on_field and ComputerDesk.ready_orders() > 0 else ""
	return ""


## The bed the step is about; -1 when none fits.
static func target_plot(sim: SimState) -> int:
	var wanted: Callable
	match sim.first_day.guide.current():
		Guide.Step.GO_DOWN, Guide.Step.PLANT:
			wanted = func(plot: Plot) -> bool: return plot.stage == Plot.Stage.EMPTY
		Guide.Step.WATER:
			wanted = func(plot: Plot) -> bool: return plot.is_growing()
		Guide.Step.PRUNE:
			wanted = func(plot: Plot) -> bool: return plot.stage == Plot.Stage.BUSH and not plot.pruned
		Guide.Step.HARVEST:
			wanted = func(plot: Plot) -> bool: return plot.stage == Plot.Stage.READY
		_:
			return -1
	var fallback := -1
	for plot: Plot in sim.grow.plots():
		if bool(wanted.call(plot)):
			if sim.first_day.guide.current() != Guide.Step.WATER or plot.water_seconds <= 0.0:
				return plot.id
			if fallback < 0:
				fallback = plot.id
	return fallback


func _process(delta: float) -> void:
	_time += delta
	_rescan_left -= delta
	queue_redraw()


func _hidden() -> bool:
	if hud == null or Game.sim == null:
		return true
	return hud.is_blocking_world() or hud.phone.visible or hud.night.is_open()


## The world spot or screen rectangle the marker points at right now.
func current_point() -> Variant:
	var kind := target_kind(Game.sim, hud.place, hud.underground)
	if kind.is_empty() or _hidden():
		return null
	if kind == PHONE:
		return hud.phone_button.get_global_rect() if hud.phone_button != null else null
	var node := _find(kind)
	return node.global_position if node != null else null


func _find(kind: String) -> Node3D:
	if kind == BED:
		var grid := _grid if is_instance_valid(_grid) else null
		if grid == null:
			_scan()
			grid = _grid if is_instance_valid(_grid) else null
		return grid.view_for(target_plot(Game.sim)) if grid != null else null
	var found := _nodes.get(kind) as Node3D
	if (found == null or not is_instance_valid(found)) and _rescan_left <= 0.0:
		_scan()
		found = _nodes.get(kind) as Node3D
	return found if is_instance_valid(found) else null


func _scan() -> void:
	_rescan_left = RESCAN_SECONDS
	_nodes.clear()
	_grid = null
	var level := hud.get_parent()
	if level == null:
		return
	var pending: Array[Node] = [level]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is ContainerEntrance:
			_nodes[CONTAINER] = node as Node3D
		elif node is CrateStack:
			_nodes[CRATES] = node as Node3D
		elif node is PackingBench:
			_nodes[BENCH] = node as Node3D
		elif node is ComputerDesk:
			_nodes[COMPUTER] = node as Node3D
		elif node is LandRover:
			_nodes[CAR] = node as Node3D
		elif node is PlotsGrid:
			_grid = node as PlotsGrid
		if node != hud:
			pending.append_array(node.get_children())


func _draw() -> void:
	var point: Variant = current_point()
	if point == null:
		return
	var colour := PhoneKit.GOLD
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	if point is Rect2:
		var rect := (point as Rect2).grow(4.0 + 4.0 * pulse)
		var box := PhoneKit.rounded(Color(0.0, 0.0, 0.0, 0.0), 10, 0.0)
		box.draw_center = false
		box.border_color = colour
		box.set_border_width_all(3)
		draw_style_box(box, Rect2(rect.position - get_global_rect().position, rect.size))
		_arrow(rect.position - get_global_rect().position + Vector2(rect.size.x / 2.0, -10.0 - 6.0 * pulse), Vector2.DOWN, colour)
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var world := point as Vector3
	var screen := get_viewport_rect().size
	var behind := camera.is_position_behind(world)
	var foot := camera.unproject_position(world)
	if behind:
		foot = screen - foot
	if not behind and EdgeMarkers.is_on_screen(screen, foot, MARGIN):
		draw_arc(foot, RING + 8.0 * pulse, 0.0, TAU, 40, Color(colour, 1.0 - 0.6 * pulse), 3.0)
		var head := camera.unproject_position(world + Vector3.UP * HEAD_HEIGHT)
		_arrow(head + Vector2(0.0, -6.0 * pulse), Vector2.DOWN, colour)
		return
	var pin := EdgeMarkers.edge_point(screen, foot, MARGIN)
	var direction := (foot - screen / 2.0).normalized()
	_arrow(pin + direction * 16.0, direction, colour)
	var font := get_theme_default_font()
	draw_string_outline(font, pin - direction * 30.0 + Vector2(-20.0, 6.0), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.BODY_SIZE, 4, PhoneKit.BEZEL)
	draw_string(font, pin - direction * 30.0 + Vector2(-20.0, 6.0), LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, PhoneKit.BODY_SIZE, colour)


func _arrow(tip: Vector2, direction: Vector2, colour: Color) -> void:
	var side := direction.orthogonal() * 14.0
	var base := tip - direction * 24.0
	draw_colored_polygon(PackedVector2Array([tip + direction * 2.0, base + side * 1.25, base - side * 1.25]), PhoneKit.BEZEL)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), colour)
