class_name HashiBoard
extends Control
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
signal state_changed(message: String)
var puzzle: Puzzle
var warnings_enabled := false
var selected := ""
var pressed := ""
var active_touch := -1
var radius := 23.0
var centers: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func set_puzzle(value: Puzzle) -> void:
	puzzle = value
	selected = ""
	pressed = ""
	active_touch = -1
	queue_redraw()

func reset() -> void:
	if puzzle:
		puzzle.reset()
		selected = ""
		state_changed.emit("")
		queue_redraw()

func _layout_islands() -> void:
	centers.clear()
	if not puzzle or puzzle.islands.is_empty():
		return
	var extent := Vector2.ONE
	for item in puzzle.islands:
		extent = extent.max(Rules.position(item))
	var margin := 36.0
	var step := minf(maxf(1.0, size.x - margin * 2.0) / extent.x, maxf(1.0, size.y - margin * 2.0) / extent.y)
	radius = minf(25.0, step * 0.31)
	var offset := (size - extent * step) / 2.0
	for item in puzzle.islands:
		centers[str(item.id)] = offset + Rules.position(item) * step

func _draw() -> void:
	_layout_islands()
	if not puzzle:
		return
	for edge in puzzle.bridges:
		var ids: PackedStringArray = edge.split(":")
		var a: Vector2 = centers[ids[0]]
		var b: Vector2 = centers[ids[1]]
		var normal := (b - a).normalized().orthogonal() * 4.0
		if int(puzzle.bridges[edge]) == 1:
			draw_line(a, b, Color("86cddd"), 3.0, true)
		else:
			draw_line(a + normal, b + normal, Color("86cddd"), 3.0, true)
			draw_line(a - normal, b - normal, Color("86cddd"), 3.0, true)
	var font := ThemeDB.fallback_font
	for item in puzzle.islands:
		var id := str(item.id)
		var point: Vector2 = centers[id]
		var degree := puzzle.degree(id)
		var fill := Color("26384e")
		if degree == int(item.target):
			fill = Color("285d58")
		if warnings_enabled and degree > int(item.target):
			fill = Color("a33e51")
		draw_circle(point, radius, fill)
		draw_arc(point, radius, 0, TAU, 48, Color("f4cf79") if selected == id else Color("aac4d1"), 2.5, true)
		var text := str(item.target)
		var font_size := int(minf(25, radius * 1.05))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, point + Vector2(-width / 2, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _hit(point: Vector2) -> String:
	_layout_islands()
	var closest := ""
	var distance := maxf(radius, 24.0)
	for id in centers:
		var candidate := point.distance_to(centers[id])
		if candidate <= distance:
			closest = id
			distance = candidate
	return closest

func _release(point: Vector2) -> void:
	var target := _hit(point)
	if not pressed.is_empty() and not target.is_empty() and target != pressed:
		_connect_islands(pressed, target)
	elif not pressed.is_empty() and target == pressed:
		if not selected.is_empty() and selected != target:
			_connect_islands(selected, target)
		else:
			selected = "" if selected == target else target
	else:
		selected = ""
	pressed = ""
	queue_redraw()

func _connect_islands(a: String, b: String) -> void:
	var error := Rules.cycle_bridge(puzzle, a, b)
	selected = ""
	state_changed.emit(error if warnings_enabled else "")

func _gui_input(event: InputEvent) -> void:
	if not puzzle:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			pressed = _hit(event.position)
		elif not event.pressed and event.index == active_touch:
			if not event.canceled:
				_release(event.position)
			else:
				pressed = ""
			active_touch = -1
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1 and active_touch == -1:
		if event.pressed:
			pressed = _hit(event.position)
		else:
			_release(event.position)
		accept_event()
