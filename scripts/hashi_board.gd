class_name HashiBoard
extends Control
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const History = preload("res://scripts/hashi_history.gd")
const Art = preload("res://scripts/hashi_art.gd")
signal state_changed(message: String)
signal puzzle_changed
var last_action: Dictionary = {}
var input_enabled := true
var bridge_color := Color("aac4d1")
var history := History.new()
var puzzle: Puzzle
var warnings_enabled := false
var selected := ""
var pressed := ""
var active_touch := -1
var radius := 23.0
var centers: Dictionary = {}
var motion_enabled := true
var _motions: Dictionary = {}
var _win_glow := 0.0
const MOTION_SECONDS := 0.16
var _gesture_active := false
var _stroke_origin := Vector2.ZERO
var _stroke_point := Vector2.ZERO
var _stroke_distance := 0.0
var _stroke_excursion := 0.0
var _started_on_core := false
var _cut_candidates: Dictionary = {}
var _cut_sides: Dictionary = {}
var _touching_bridge: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	set_process(false)
	cancel_gesture()

func set_puzzle(value: Puzzle) -> void:
	puzzle = value
	history.clear()
	selected = ""
	pressed = ""
	active_touch = -1
	_motions.clear()
	_win_glow = 0.0
	set_process(false)
	cancel_gesture()
	queue_redraw()

func reset() -> void:
	if puzzle and input_enabled:
		var before := puzzle.bridges.duplicate(true)
		puzzle.reset()
		_finish_change(before, "reset")

func undo() -> void:
	if puzzle and input_enabled:
		var before := puzzle.bridges.duplicate(true)
		if history.undo(puzzle):
			_notify_change("undo", before)

func redo() -> void:
	if puzzle and input_enabled:
		var before := puzzle.bridges.duplicate(true)
		if history.redo(puzzle):
			_notify_change("redo", before)

func _finish_change(before: Dictionary, kind: String = "move") -> void:
	if history.record(before, puzzle.bridges):
		_notify_change(kind, before)
	else:
		selected = ""
		queue_redraw()

func _notify_change(kind: String, before: Dictionary) -> void:
	_animate_change(before)
	last_action = {"kind": kind, "before": before.duplicate(true), "bridges": puzzle.bridges.duplicate(true)}
	selected = ""
	pressed = ""
	active_touch = -1
	cancel_gesture()
	puzzle_changed.emit()
	state_changed.emit("")
	queue_redraw()

func _layout_islands() -> void:
	centers.clear()
	if not puzzle or puzzle.islands.is_empty():
		return
	var extent := Vector2.ONE
	for item in puzzle.islands:
		extent = extent.max(Rules.position(item))
	var margin := 25.0
	var step := minf(maxf(1.0, size.x - margin * 2.0) / extent.x, maxf(1.0, size.y - margin * 2.0) / extent.y)
	radius = minf(25.0, step * 0.43)
	var offset := (size - extent * step) / 2.0
	for item in puzzle.islands:
		centers[str(item.id)] = offset + Rules.position(item) * step

func _draw() -> void:
	_layout_islands()
	if not puzzle:
		return
	var panel := Art.surface(Color("faf7ed"), Art.BORDER, 18)
	panel.content_margin_left = 0
	panel.draw(get_canvas_item(), Rect2(Vector2(1, 1), size - Vector2(2, 2)))
	# Specks suggest a quiet tabletop without suggesting puzzle connections.
	for x in range(18, int(size.x) - 10, 24):
		for y in range(18, int(size.y) - 10, 24):
			draw_circle(Vector2(x, y), 0.65, Color(0.35,0.5,0.35,0.06))
	if _win_glow > 0:
		var finish := Art.surface(Color(0,0,0,0), Color(0.85,0.72,0.47,_win_glow * 0.8), 18)
		finish.set_border_width_all(2)
		finish.draw(get_canvas_item(), Rect2(Vector2(2, 2), size - Vector2(4, 4)))
	var visible_edges := puzzle.bridges.duplicate()
	for edge in _motions:
		visible_edges[edge] = _motions[edge].to
	for edge in visible_edges:
		var ids: PackedStringArray = edge.split(":")
		var a: Vector2 = centers[ids[0]]
		var b: Vector2 = centers[ids[1]]
		var amount := int(visible_edges[edge])
		var tint := bridge_color
		if _cut_candidates.has(edge):
			tint = Color("ba6d51")
		var spread := 1.0
		if _motions.has(edge):
			var anim: Dictionary = _motions[edge]
			var ease: float = 1.0 - pow(1.0 - float(anim.t), 3)
			if int(anim.to) == 0:
				amount = int(anim.from)
				tint.a = 1.0 - ease
			elif int(anim.from) == 0:
				b = a.lerp(b, ease)
			elif int(anim.to) == 2:
				spread = ease
		var normal: Vector2 = (centers[ids[1]] - a).normalized().orthogonal() * minf(4, radius * 0.24) * spread
		if amount == 1:
			_bridge(a, b, tint)
		else:
			_bridge(a + normal, b + normal, tint)
			_bridge(a - normal, b - normal, tint)
	var font := Art.NUMBERS
	for item in puzzle.islands:
		var id := str(item.id)
		var point: Vector2 = centers[id]
		var fill := island_fill(item)
		draw_circle(point + Vector2(0, 3), radius + 1, Color(0.25,0.32,0.2,0.18))
		if selected == id:
			draw_arc(point, radius + 4, 0, TAU, 48, Art.GOLD, 2, true)
		draw_circle(point, radius, fill)
		draw_arc(point, radius, 0, TAU, 48, Color("aabb9e"), 1.4, true)
		draw_arc(point - Vector2(0, 0.6), radius - 2.5, PI, TAU, 28, Color(1,1,1,0.12), 1, true)
		var text := "?" if item.get("variant") == "mystery" else str(int(item.target))
		var font_size := int(clampf(radius * 1.1, 13, 26))
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var ink := Art.INK if fill == Art.PAPER else Art.PAPER
		draw_string(font, point + Vector2(-width / 2, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

		if item.get("variant") == "blue":
			var badge := point + Vector2(radius * 0.72, -radius * 0.72)
			draw_circle(badge, 7, Color("225a8d"))
			draw_string(font, badge + Vector2(-3.5, 3.5), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("bcdef3"))

func _bridge(a: Vector2, b: Vector2, tint: Color) -> void:
	draw_line(a + Vector2(0, 2), b + Vector2(0, 2), Color(0.2,0.35,0.2,tint.a * 0.15), 5, true)
	draw_line(a, b, tint, 2.8, true)

func _animate_change(before: Dictionary) -> void:
	if not motion_enabled:
		return
	var edges := before.duplicate()
	edges.merge(puzzle.bridges, true)
	for edge in edges:
		var old := int(before.get(edge, 0))
		var current := int(puzzle.bridges.get(edge, 0))
		if old != current:
			_motions[edge] = {"from": old, "to": current, "t": 0.0}
	if Rules.is_solved(puzzle):
		_win_glow = 1.0
	set_process(not _motions.is_empty() or _win_glow > 0)

func _process(delta: float) -> void:
	for edge in _motions.keys():
		_motions[edge].t = minf(1.0, float(_motions[edge].t) + delta / MOTION_SECONDS)
		if _motions[edge].t >= 1:
			_motions.erase(edge)
	_win_glow = maxf(0, _win_glow - delta / 0.7)
	queue_redraw()
	set_process(not _motions.is_empty() or _win_glow > 0)

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	if not enabled:
		_motions.clear()
		_win_glow = 0
		set_process(false)
		queue_redraw()

func _hit(point: Vector2) -> String:
	_layout_islands()
	var closest := ""
	var distance := maxf(radius + 14.0, 34.0)
	for id in centers:
		var candidate := point.distance_to(centers[id])
		if candidate <= distance:
			closest = id
			distance = candidate
	return closest

func _release(point: Vector2) -> void:
	if not _gesture_active:
		return
	_track_stroke(point)
	var target := _hit(point)
	# A tap keeps its original island even if finger jitter crosses a hit-area boundary.
	var tap_limit := 12.0
	if not pressed.is_empty() and not target.is_empty() and target != pressed:
		tap_limit = minf(tap_limit, centers[pressed].distance_to(centers[target]) * 0.35)
	if not pressed.is_empty() and _stroke_excursion < tap_limit:
		target = pressed
	var aims_at_islands := false
	if not pressed.is_empty() and not target.is_empty() and target != pressed:
		var toward: Vector2 = (centers[target] - centers[pressed]).normalized()
		var direction := (point - _stroke_origin).normalized()
		var lateral := maxf(absf(toward.cross(_stroke_origin - centers[pressed])), absf(toward.cross(point - centers[target])))
		var in_corridor := _cut_candidates.is_empty() or lateral <= radius * 0.65
		aims_at_islands = _started_on_core or not _core_hit(point).is_empty() or (absf(direction.dot(toward)) >= 0.72 and in_corridor)
	if aims_at_islands:
		_connect_islands(pressed, target)
	elif _stroke_excursion >= 18 and not _started_on_core and _core_hit(point).is_empty() and not _cut_candidates.is_empty():
		var before := puzzle.bridges.duplicate(true)
		for edge in _cut_candidates:
			puzzle.bridges.erase(edge)
		_finish_change(before, "cut")
	elif not pressed.is_empty() and target == pressed:
		if not selected.is_empty() and selected != target:
			_connect_islands(selected, target)
		else:
			selected = "" if selected == target else target
	else:
		selected = ""
	_end_pointer()
	queue_redraw()

func _core_hit(point: Vector2) -> String:
	var result := ""
	var closest := radius
	for id in centers:
		var distance: float = point.distance_to(centers[id])
		if distance <= closest:
			closest = distance
			result = id
	return result

func _begin_pointer(point: Vector2) -> void:
	_layout_islands()
	_end_pointer()
	_gesture_active = true
	_stroke_origin = point
	_stroke_point = point
	_started_on_core = not _core_hit(point).is_empty()
	pressed = _hit(point)

func _end_pointer() -> void:
	_gesture_active = false
	_stroke_distance = 0
	_stroke_excursion = 0
	_cut_candidates.clear()
	_cut_sides.clear()
	_touching_bridge.clear()
	pressed = ""
	active_touch = -1

func cancel_gesture() -> void:
	selected = ""
	_end_pointer()
	queue_redraw()

func _track_stroke(point: Vector2) -> void:
	if not _gesture_active:
		return
	var from := _stroke_point
	_stroke_distance += from.distance_to(point)
	_stroke_excursion = maxf(_stroke_excursion, _stroke_origin.distance_to(point))
	_stroke_point = point
	if _started_on_core or from.distance_squared_to(point) < 0.25:
		return
	for edge in puzzle.bridges:
		var ids: PackedStringArray = str(edge).split(":")
		var a: Vector2 = centers[ids[0]]
		var b: Vector2 = centers[ids[1]]
		var axis := (b - a).normalized()
		var padding := minf(radius + 1.0, a.distance_to(b) * 0.45)
		var intersection: Variant = Geometry2D.segment_intersects_segment(from, point, a + axis * padding, b - axis * padding)
		var last: float = float(_cut_sides.get(edge, signf((b - a).cross(from - a))))
		var side := signf((b - a).cross(point - a))
		if intersection is Vector2 and absf((point - from).normalized().dot(axis)) < 0.9:
			_touching_bridge[edge] = true
		if side != 0:
			if last != 0 and last != side and _touching_bridge.has(edge):
				_cut_candidates[edge] = true
			_cut_sides[edge] = side
			_touching_bridge.erase(edge)
		elif not _cut_sides.has(edge):
			_cut_sides[edge] = last
	queue_redraw()

func _connect_islands(a: String, b: String) -> void:
	if not input_enabled:
		return
	var before := puzzle.bridges.duplicate(true)
	var error := Rules.cycle_bridge(puzzle, a, b)
	_finish_change(before)
	selected = ""
	state_changed.emit(error if warnings_enabled else "")

func _gui_input(event: InputEvent) -> void:
	if not puzzle or not input_enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			_begin_pointer(event.position)
			active_touch = event.index
		elif not event.pressed and event.index == active_touch:
			if not event.canceled:
				_release(event.position)
			else:
				cancel_gesture()
			active_touch = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_track_stroke(event.position)
		accept_event()
	elif event is InputEventMouseMotion and active_touch == -1 and _gesture_active and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and event.device != -1:
		_track_stroke(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1 and active_touch == -1:
		if event.pressed:
			_begin_pointer(event.position)
		else:
			_release(event.position)
		accept_event()

func island_fill(item: Dictionary) -> Color:
	var fill := Art.PAPER
	if item.get("variant") == "blue":
		fill = Color("225a8d")
	elif item.get("variant") == "mystery":
		return Color("554478")
	var degree := puzzle.degree(str(item.id))
	if degree == int(item.target):
		fill = Color("285d58")
	if warnings_enabled and degree > int(item.target):
		fill = Color("a33e51")
	return fill
