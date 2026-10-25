extends SceneTree
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var solutions: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", label)

func make(points: Array, targets: Array) -> Puzzle:
	var data := {"id": "test", "islands": []}
	for i in points.size():
		data.islands.append({"id": str(i), "x": points[i][0], "y": points[i][1], "target": targets[i]})
	return Puzzle.new(data)

# Exhaustive test-only enumerator, bounded at two solutions. Not a game solver.
func enumerate(puzzle: Puzzle, edges: Array, index: int) -> void:
	if solutions.size() >= 2:
		return
	for item in puzzle.islands:
		var id := str(item.id)
		var remaining := 0
		for k in range(index, edges.size()):
			if id in edges[k]:
				remaining += 2
		var degree := puzzle.degree(id)
		if degree > int(item.target) or degree + remaining < int(item.target):
			return
	if index == edges.size():
		if Rules.is_solved(puzzle):
			solutions.append(puzzle.bridges.duplicate())
		return
	var a: String = edges[index][0]
	var b: String = edges[index][1]
	for count in range(3):
		if not Rules.move_error(puzzle, a, b, count).is_empty():
			continue
		if count == 0:
			puzzle.bridges.erase(puzzle.key(a, b))
		else:
			puzzle.bridges[puzzle.key(a, b)] = count
		enumerate(puzzle, edges, index + 1)
	puzzle.bridges.erase(puzzle.key(a, b))

func run() -> void:
	var pair := make([[0, 0], [2, 0]], [2, 2])
	check(Rules.valid_definition(pair), "valid model")
	for expected in [1, 2, 0]:
		check(Rules.cycle_bridge(pair, "0", "1").is_empty(), "cycle accepted")
		check(pair.bridge_count("1", "0") == expected, "cycle 0 1 2 0, symmetric key")
	check(not Rules.move_error(pair, "0", "1", 3).is_empty(), "third bridge rejected")
	check(not Rules.move_error(pair, "0", "1", -1).is_empty(), "negative rejected")
	check(not Rules.move_error(pair, "0", "0", 1).is_empty(), "self edge rejected")
	check(not Rules.move_error(pair, "0", "missing", 1).is_empty(), "unknown island rejected")
	pair.bridges["0:1"] = 2
	check(Rules.is_solved(pair), "double bridge solved")
	pair.reset()
	check(pair.bridges.is_empty() and not Rules.is_solved(pair), "reset clears and removes victory")
	var diagonal := make([[0, 0], [1, 1]], [1, 1])
	check(not Rules.move_error(diagonal, "0", "1", 1).is_empty(), "diagonal rejected")
	var blocked := make([[0, 0], [1, 0], [2, 0]], [1, 2, 1])
	check(not Rules.move_error(blocked, "0", "2", 1).is_empty(), "bridge through island rejected")
	var crossing := make([[1, 0], [1, 2], [0, 1], [2, 1]], [1, 1, 1, 1])
	crossing.bridges["0:1"] = 1
	check(not Rules.move_error(crossing, "2", "3", 1).is_empty(), "crossing rejected")
	check(Rules.move_error(crossing, "0", "1", 0).is_empty(), "removal accepted")
	crossing.bridges["2:3"] = 1
	check(not Rules.is_solved(crossing), "crossing cannot win")
	var disconnected := make([[0, 0], [2, 0], [0, 2], [2, 2]], [1, 1, 1, 1])
	disconnected.bridges = {"0:1": 1, "2:3": 1}
	check(not Rules.network_connected(disconnected) and not Rules.is_solved(disconnected), "matching degrees but separate networks rejected")
	var invalid := make([[0, 0]], [9])
	check(not Rules.valid_definition(invalid), "target over eight rejected")
	invalid.islands[0].target = 0
	check(not Rules.valid_definition(invalid), "target zero rejected")
	invalid = make([[0, 0], [0, 0]], [1, 1])
	check(not Rules.valid_definition(invalid), "duplicate location rejected")
	var ambiguous := make([[0, 0], [2, 0], [0, 2], [2, 2]], [3, 3, 3, 3])
	solutions.clear()
	enumerate(ambiguous, [["0", "1"], ["0", "2"], ["1", "3"], ["2", "3"]], 0)
	check(solutions.size() == 2, "enumerator detects multiple solutions")
	var impossible := make([[0, 0], [1, 0]], [1, 2])
	solutions.clear()
	enumerate(impossible, [["0", "1"]], 0)
	check(solutions.is_empty(), "enumerator detects no solution")
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	check(fixtures.size() >= 3, "three fixtures")
	var first_solution := {}
	for data in fixtures:
		var puzzle := Puzzle.new(data)
		check(Rules.valid_definition(puzzle), "fixture valid " + str(data.id))
		var edges: Array = []
		for i in puzzle.islands.size():
			for j in range(i + 1, puzzle.islands.size()):
				var a := str(puzzle.islands[i].id)
				var b := str(puzzle.islands[j].id)
				if Rules.aligned_neighbors(puzzle, a, b):
					edges.append([a, b])
		solutions.clear()
		enumerate(puzzle, edges, 0)
		check(solutions.size() == 1, "exactly one solution " + str(data.id))
		print("Uniqueness ", data.id, ": ", solutions.size(), " solution(s)")
		if solutions.size() == 1:
			puzzle.bridges = solutions[0].duplicate()
			check(Rules.is_solved(puzzle), "fixture solution accepted")
			if data.id == fixtures[0].id:
				first_solution = puzzle.bridges.duplicate()
	var ui = Main.instantiate()
	root.add_child(ui)
	await process_frame
	check(not ui.board.warnings_enabled, "warnings off by default")
	for dimensions in [Vector2i(360, 640), Vector2i(480, 800), Vector2i(720, 1280)]:
		root.size = dimensions
		await process_frame
		await process_frame
		ui.board._layout_islands()
		check(ui.board.size.x >= 200 and ui.board.size.y >= 200, "portrait board fits " + str(dimensions))
		for center in ui.board.centers.values():
			check(Rect2(Vector2.ZERO, ui.board.size).has_point(center), "island visible")
	var board = ui.board
	var a: Vector2 = board.centers["0"]
	var b: Vector2 = board.centers["1"]
	touch(board, a, true)
	touch(board, a, false)
	touch(board, b, true)
	touch(board, b, false)
	check(board.puzzle.bridge_count("0", "1") == 1, "two taps create bridge")
	touch(board, a, true)
	touch(board, b, false)
	check(board.puzzle.bridge_count("0", "1") == 2, "swipe creates double")
	touch(board, a, true)
	touch(board, b, false)
	check(board.puzzle.bridge_count("0", "1") == 0, "swipe removes bridge")
	for edge in first_solution:
		var ids: PackedStringArray = edge.split(":")
		for count in int(first_solution[edge]):
			touch(board, board.centers[ids[0]], true)
			touch(board, board.centers[ids[1]], false)
	check(Rules.is_solved(board.puzzle), "complete puzzle solved through touch events")
	check("resuelto" in ui.status.text, "victory indicator")
	board.reset()
	check(not "resuelto" in ui.status.text and board.puzzle.bridges.is_empty(), "reset updates UI")
	board.set_puzzle(make([[0, 0], [1, 0]], [1, 1]))
	board.puzzle.bridges["0:1"] = 2
	check(not Rules.is_solved(board.puzzle), "excess never wins")
	ui._update_status("")
	check(not "más puentes" in ui.status.text, "excess warning hidden by default")
	board.warnings_enabled = true
	ui._update_status("")
	check("más puentes" in ui.status.text, "enabled excess warning")
	ui._select_puzzle(2)
	check(board.puzzle.puzzle_id == "h01_3", "board selector")
	ui.queue_free()
	await process_frame
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func touch(board: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	board._gui_input(event)
