extends SceneTree
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Board = preload("res://scripts/hashi_board.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Sequence = preload("res://scripts/hashi_sequence.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
const Main = preload("res://scenes/main.tscn")
# Fixed witnesses for the unchanged fixtures, not a game solver.
const SOLUTIONS = [{"0:1": 2, "1:3": 2, "2:3": 1}, {"1:2": 2, "0:3": 1, "1:4": 2, "3:4": 2, "4:5": 2, "4:7": 2, "6:7": 1, "5:8": 1, "7:8": 2}, {"0:3": 1, "2:3": 2, "1:4": 2, "3:4": 2, "4:5": 2, "2:6": 2, "6:7": 1, "4:8": 1, "5:9": 2, "11:8": 1, "10:11": 2}]
var catalog: Array
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL H02A: ", label)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	test_history()
	test_sequence_and_session()
	test_storage()
	await test_ui()
	print("H02A RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func test_history() -> void:
	var board := Board.new()
	board.set_puzzle(Puzzle.new(catalog[0]))
	check(not board.history.undo(board.puzzle) and not board.history.redo(board.puzzle), "empty history")
	board._connect_islands("0", "3")
	check(board.history.past.is_empty(), "rejected diagonal not recorded")
	for count in [1, 2, 0]:
		board._connect_islands("0", "1")
		check(board.puzzle.bridge_count("0", "1") == count, "bridge changes recorded")
	check(board.history.past.size() == 3, "one record per change")
	for count in [2, 1, 0]:
		board.undo()
		check(board.puzzle.bridge_count("0", "1") == count, "successive undo")
	check(board.history.past.is_empty() and board.history.future.size() == 3, "full undo")
	for count in [1, 2, 0]:
		board.redo()
		check(board.puzzle.bridge_count("0", "1") == count, "successive redo")
	board.undo()
	board._connect_islands("0", "3")
	check(board.history.future.size() == 1, "invalid action preserves redo")
	check(not board.history.record(board.puzzle.bridges, board.puzzle.bridges), "duplicate not recorded")
	check(board.history.future.size() == 1, "duplicate preserves redo")
	board._connect_islands("0", "2")
	check(board.history.future.is_empty(), "new move invalidates redo")
	var snapshot := board.puzzle.bridges.duplicate()
	board.reset()
	check(board.puzzle.bridges.is_empty(), "reset empties board")
	var count := board.history.past.size()
	board.reset()
	check(board.history.past.size() == count, "empty reset not recorded")
	board.undo()
	check(board.puzzle.bridges == snapshot, "reset undoable")
	board.redo()
	check(board.puzzle.bridges.is_empty(), "reset redoable")
	board.set_puzzle(Puzzle.new(catalog[1]))
	check(board.history.past.is_empty() and board.history.future.is_empty(), "no cross-level history")
	board.free()

func test_sequence_and_session() -> void:
	var policy := Sequence.new(catalog)
	check(policy.next_id("h01_1") == "h01_2", "first to second")
	check(policy.next_id("h01_2") == "h01_3", "second to third")
	check(policy.next_id("h01_3") == "h01_1" and policy.wraps_after("h01_3"), "temporary wrap")
	check(policy.next_id("unknown").is_empty(), "unknown ID not advanced")
	check(Sequence.new().next_id("unknown").is_empty(), "empty catalog policy")
	var session := Session.new(catalog, "user://h02a-session.json")
	check(not session.advance(), "incomplete board cannot advance")
	check(not session.select(-1) and not session.select(3), "invalid selection refused")
	for i in range(3):
		var puzzle := session.current_puzzle()
		puzzle.bridges = SOLUTIONS[i].duplicate()
		check(Rules.is_solved(puzzle), "unchanged solution witness")
		check(session.capture(puzzle), "completed state captured")
		check(session.capture(puzzle) and session.completed_ids.size() == i + 1, "completed IDs deduplicated")
		check(session.advance(), "next level allowed after victory")
	check(session.current_index == 0 and session.completed_ids.size() == 3, "wrap retains progress")
	check(session.current_puzzle().bridges == SOLUTIONS[0], "visited board restored")
	var puzzle := session.current_puzzle()
	puzzle.reset()
	session.capture(puzzle)
	check(session.completed_ids.size() == 3, "completion milestone survives reset")
	check(session.save_game(), "session saved")
	var reopened := Session.new(catalog, "user://h02a-session.json")
	check(reopened.restore(), "session loaded")
	check(reopened.current_index == 0 and reopened.completed_ids.size() == 3, "progress recovered")
	check(reopened.current_puzzle().bridges.is_empty(), "reset recovered")
	reopened.select(1)
	check(reopened.current_puzzle().bridges == SOLUTIONS[1], "other levels recovered")
	var detached := reopened.current_puzzle()
	detached.reset()
	check(not reopened.current_puzzle().bridges.is_empty(), "restored state not aliased")

func test_storage() -> void:
	var store := Store.new("user://h02a-storage.json")
	var session := Session.new(catalog)
	var data := session.snapshot_data()
	check(store.save_game(data, catalog), "initial snapshot written")
	data.boards.h01_1 = {"0:1": 2, "0:2": 2}
	check(store.save_game(data, catalog), "partial excess accepted")
	check(store.load_game(catalog) == data, "atomic overwrite loads latest")
	write_text(store.path + ".tmp", "{broken")
	check(store.load_game(catalog) == data, "interrupted temp ignored")
	var bad: Array = []
	for version in [Store.VERSION + 1, 1.5, true, "1"]:
		var item := data.duplicate(true)
		item.version = version
		bad.append(item)
	for bridges in [{"1:0": 1}, {"0:0": 1}, {"0:3": 1}, {"0:missing": 1}, {"0:1:2": 1}, {"0:1": 3}, {"0:1": -1}, {"0:1": 0}, {"0:1": 1.5}, {"0:1": true}, {"0:1": "1"}, [], null]:
		var item := data.duplicate(true)
		item.boards.h01_1 = bridges
		bad.append(item)
	for completed in [["unknown"], ["h01_1", "h01_1"], [false], {}]:
		var item := data.duplicate(true)
		item.completed_ids = completed
		bad.append(item)
	for current in ["unknown", 0, null]:
		var item := data.duplicate(true)
		item.current_puzzle_id = current
		bad.append(item)
	bad.append({})
	bad.append([])
	bad.append(null)
	var unknown_board := data.duplicate(true)
	unknown_board.boards["unknown"] = {}
	bad.append(unknown_board)
	var missing_current := data.duplicate(true)
	missing_current.boards.erase("h01_1")
	bad.append(missing_current)
	for item in bad:
		check(not store.valid_snapshot(item, catalog), "malformed snapshot rejected " + str(checks))
	var invalid := data.duplicate(true)
	invalid.boards.h01_1 = {"0:1": 3}
	check(not store.save_game(invalid, catalog) and store.load_game(catalog) == data, "failed validation preserves previous save")
	var through_island := data.duplicate(true)
	through_island.boards.h01_2 = {"0:2": 1}
	check(not store.valid_snapshot(through_island, catalog), "saved bridge through island rejected")
	var cross_catalog := [{"id": "cross", "islands": [{"id": "a", "x": 0, "y": 1, "target": 1}, {"id": "b", "x": 2, "y": 1, "target": 1}, {"id": "c", "x": 1, "y": 0, "target": 1}, {"id": "d", "x": 1, "y": 2, "target": 1}]}]
	var cross_data := {"version": 1, "current_puzzle_id": "cross", "boards": {"cross": {"a:b": 1, "c:d": 1}}, "completed_ids": []}
	check(not store.valid_snapshot(cross_data, cross_catalog), "saved crossing rejected")
	for text in ["{", "null", "[]", JSON.stringify(invalid), "x".repeat(Store.MAX_BYTES + 1)]:
		write_text(store.path, text)
		check(store.load_game(catalog).is_empty() and not store.last_error.is_empty(), "corrupt file rejected")
	var fallback := Session.new(catalog, store.path)
	check(not fallback.restore() and fallback.current_puzzle().bridges.is_empty(), "bad save starts safely")
	check(not Store.new("res://forbidden.json").save_game(data, catalog), "save restricted to user directory")
	check(not Store.new("user://missing-directory/state.json").save_game(data, catalog), "unwritable destination reported")

func test_ui() -> void:
	var ui = Main.instantiate()
	ui.save_path = "user://h02a-ui.json"
	root.add_child(ui)
	await process_frame
	check(ui.undo_button.disabled and ui.redo_button.disabled and ui.next_button.disabled, "initial buttons")
	ui.board._connect_islands("0", "1")
	check(not ui.undo_button.disabled and ui.redo_button.disabled, "move enables undo")
	ui.undo_button.pressed.emit()
	check(ui.board.puzzle.bridges.is_empty() and not ui.redo_button.disabled, "undo button")
	ui.redo_button.pressed.emit()
	check(ui.board.puzzle.bridge_count("0", "1") == 1, "redo button")
	ui.board._connect_islands("0", "1")
	ui.board._connect_islands("1", "3")
	ui.board._connect_islands("1", "3")
	ui.board._connect_islands("2", "3")
	check(not ui.next_button.disabled and "resuelto" in ui.status.text, "discreet victory enables next")
	ui.undo_button.pressed.emit()
	check(ui.next_button.disabled and not "resuelto" in ui.status.text, "undo removes victory")
	ui.redo_button.pressed.emit()
	check(not ui.next_button.disabled, "redo restores victory")
	ui.next_button.pressed.emit()
	check(ui.session.current_index == 1 and ui.selector.selected == 1, "next button selects next")
	check(ui.board.history.past.is_empty(), "next clears history")
	ui.board._connect_islands("0", "1")
	var bridges: Dictionary = ui.board.puzzle.bridges.duplicate()
	ui.queue_free()
	await process_frame
	ui = Main.instantiate()
	ui.save_path = "user://h02a-ui.json"
	root.add_child(ui)
	await process_frame
	check(ui.session.current_index == 1 and ui.board.puzzle.bridges == bridges, "reopen resumes level and bridges")
	check("h01_1" in ui.session.completed_ids, "reopen resumes progress")
	ui._select_puzzle(0)
	check(ui.board.puzzle.bridges == SOLUTIONS[0], "return to solved first board")
	ui._select_puzzle(2)
	for edge in SOLUTIONS[2]:
		var ids: PackedStringArray = edge.split(":")
		for count in int(SOLUTIONS[2][edge]):
			ui.board._connect_islands(ids[0], ids[1])
	check(not ui.next_button.disabled and ui.next_button.text == "Volver al primero", "last board wraps explicitly")
	check("provisional" in ui.status.text, "temporary sequence wording")
	ui.next_button.pressed.emit()
	check(ui.session.current_index == 0, "last next returns first")
	for dimensions in [Vector2i(360, 640), Vector2i(480, 800), Vector2i(720, 1280)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		await process_frame
		await process_frame
		check(ui.board.size.y >= 200, "board fits portrait")
		var bottom: float = ui.next_button.global_position.y + ui.next_button.size.y
		check(bottom <= root.size.y, "navigation stays on screen " + str(dimensions) + " bottom=" + str(bottom))
	ui.restart_button.pressed.emit()
	check(ui.board.puzzle.bridges.is_empty() and ui.next_button.disabled, "restart button clears victory")
	ui.session.store.path = "user://missing-directory/ui.json"
	ui.board._connect_islands("0", "1")
	check(ui.save_failed and "No se pudo guardar" in ui.status.text, "save failure reported without losing move")
	ui.session.store.path = "user://h02a-retry.json"
	ui._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not ui.save_failed and not ui.session.store.load_game(catalog).is_empty(), "pause retries pending save")
	ui.queue_free()
	await process_frame

	write_text("user://h02a-corrupt-ui.json", "{broken")
	ui = Main.instantiate()
	ui.save_path = "user://h02a-corrupt-ui.json"
	root.add_child(ui)
	await process_frame
	check(ui.board.puzzle.bridges.is_empty() and "inválidos" in ui.status.text, "invalid save reported in UI")
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(FileAccess.get_file_as_string(ui.save_path) == "{broken", "focus does not overwrite corrupt save")
	ui.board._connect_islands("0", "1")
	check(not ui.session.store.load_game(catalog).is_empty(), "valid new action replaces corrupt save")
	ui.queue_free()
	await process_frame
