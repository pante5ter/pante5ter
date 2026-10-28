class_name StoryTreeView
extends Control

## The forks drawn as a flowchart: each story a box, its options fanned out below, the one Jack took
## lit and joined to the next fork; the others greyed, their labels hidden when he never saw them.

const NODE_SIZE: Vector2 = Vector2(400.0, 58.0)
const BRANCH_SIZE: Vector2 = Vector2(214.0, 76.0)
const BRANCH_GAP: float = 14.0
const FAN_DROP: float = 36.0
const BEAT_GAP: float = 44.0
const DAY_HEADER: float = 40.0
const MIN_WIDTH: float = 960.0
const MARGIN: float = 20.0
const INK: Color = Color("EDEBE6")  # white
const GOLD: Color = Color("F2C46B")  # lamp_warm
const MUTED: Color = Color("B5B5B0")  # light_grey
const DIM: Color = Color("4C5157")  # steel_dark
const BOX: Color = Color("26272A")  # pot_black
const BOX_CHOSEN: Color = Color("4A3A2C")  # timber
const LINE_COLOURS: Dictionary[String, Color] = {
	StoryTree.RAT: Color("B83A32"),  # alert_red
	StoryTree.LORD: Color("B08D4A"),  # brass
	StoryTree.VILLAGE: Color("7A8F5C"),  # grass_light
	StoryTree.RENT: Color("6E8F5E"),  # money_green
}

var _links: Array[Dictionary] = []


func show_beats(beats: Array[StoryTree.Beat], by_day: bool) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_links.clear()
	var width := MIN_WIDTH
	for beat: StoryTree.Beat in beats:
		width = maxf(width, _row_width(beat.branches.size()) + MARGIN * 2.0)
	var y := MARGIN
	var day := -1
	var previous_exit := Vector2.INF
	for index: int in beats.size():
		var beat := beats[index]
		if by_day and beat.day() != day:
			day = beat.day()
			var header := UiStyle.label("День %d" % day, 18, GOLD)
			header.position = Vector2(MARGIN, y)
			header.size = Vector2(width - MARGIN * 2.0, DAY_HEADER)
			add_child(header)
			y += DAY_HEADER
			previous_exit = Vector2.INF
		var node_rect := Rect2(Vector2((width - NODE_SIZE.x) / 2.0, y), NODE_SIZE)
		add_child(_node_box(beat, index, node_rect))
		if previous_exit != Vector2.INF:
			_links.append({"from": previous_exit, "to": Vector2(node_rect.get_center().x, node_rect.position.y), "colour": GOLD, "width": 3.0})
		previous_exit = Vector2.INF
		y = node_rect.end.y + FAN_DROP
		var row_left := (width - _row_width(beat.branches.size())) / 2.0
		for branch_index: int in beat.branches.size():
			var branch := beat.branches[branch_index]
			var rect := Rect2(Vector2(row_left + (BRANCH_SIZE.x + BRANCH_GAP) * float(branch_index), y), BRANCH_SIZE)
			add_child(_branch_box(branch, index, branch_index, rect))
			_links.append({
				"from": Vector2(node_rect.get_center().x, node_rect.end.y),
				"to": Vector2(rect.get_center().x, rect.position.y),
				"colour": GOLD if branch.chosen else DIM,
				"width": 3.0 if branch.chosen else 1.5,
			})
			if branch.chosen:
				previous_exit = Vector2(rect.get_center().x, rect.end.y)
		y += (BRANCH_SIZE.y if not beat.branches.is_empty() else 0.0) + BEAT_GAP
	custom_minimum_size = Vector2(width, y)
	size = custom_minimum_size
	queue_redraw()


func _row_width(count: int) -> float:
	return maxf(BRANCH_SIZE.x * float(count) + BRANCH_GAP * float(maxi(count - 1, 0)), 0.0)


func _node_box(beat: StoryTree.Beat, index: int, rect: Rect2) -> PanelContainer:
	var box := _box(rect, BOX, LINE_COLOURS.get(beat.storyline, MUTED) as Color, 2)
	box.name = "Beat_%d" % index
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	box.add_child(rows)
	var heading := UiStyle.label(beat.title, 16, INK)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.max_lines_visible = 1
	rows.add_child(heading)
	var note := "%s · %s" % [beat.storyline, ClueBoardText.when(beat.at)]
	if beat.state == StoryTree.WAITING:
		note += " · ждёт ответа"
	elif beat.state == StoryTree.MISSED:
		note += " · без ответа"
	var sub := UiStyle.label(note, 12, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(sub)
	return box


func _branch_box(branch: StoryTree.Branch, beat_index: int, index: int, rect: Rect2) -> PanelContainer:
	var box := _box(rect, BOX_CHOSEN if branch.chosen else BOX, GOLD if branch.chosen else DIM, 3 if branch.chosen else 1)
	box.name = "Beat_%d_Branch_%d" % [beat_index, index]
	box.set_meta("chosen", branch.chosen)
	box.modulate = Color.WHITE if branch.chosen else Color(1.0, 1.0, 1.0, 0.55)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	box.add_child(rows)
	var label := UiStyle.label(branch.shown_label(), 13, INK if branch.chosen else MUTED)
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.max_lines_visible = 3
	rows.add_child(label)
	if branch.chosen:
		var picked := "Выбор Джека" if branch.outcome.is_empty() else "Выбор Джека · %s" % branch.outcome
		var mark := UiStyle.label(picked, 11, GOLD)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(mark)
	return box


func _box(rect: Rect2, fill: Color, border: Color, border_width: int) -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = rect.position
	box.size = rect.size
	box.custom_minimum_size = rect.size
	box.clip_contents = true
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	box.add_theme_stylebox_override("panel", style)
	return box


func _draw() -> void:
	for link: Dictionary in _links:
		draw_line(link["from"] as Vector2, link["to"] as Vector2, link["colour"] as Color, float(link["width"]), true)


func beat_count() -> int:
	var count := 0
	for child: Node in get_children():
		if child.name.begins_with("Beat_") and not child.name.contains("_Branch_"):
			count += 1
	return count


func branch(beat_index: int, index: int) -> PanelContainer:
	return get_node_or_null("Beat_%d_Branch_%d" % [beat_index, index]) as PanelContainer


func branch_label(beat_index: int, index: int) -> String:
	var box := branch(beat_index, index)
	return (box.find_child("Label", true, false) as Label).text if box != null else ""
