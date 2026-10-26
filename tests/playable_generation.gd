extends SceneTree
const Generator = preload("res://scripts/hashi_generator.gd")
const Task = preload("res://scripts/hashi_generation_task.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Main = preload("res://scenes/main.tscn")
var catalog: Array
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL H02C: ", label)

func contains_solution(value: Variant) -> bool:
	if value is Dictionary:
		for name in value:
			if name in ["solution", "solutions", "construction_solution"] or contains_solution(value[name]):
				return true
	elif value is Array:
		for item in value:
			if contains_solution(item):
				return true
	return false

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func wait_task(task: Task) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		var result := task.poll()
		if not result.is_empty():
			return result
		await process_frame
	check(false, "worker timeout")
	task.finish_on_shutdown()
	return {"status": "failure", "reason": "test_timeout"}

func wait_ui(ui: Control) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "UI task completes")

func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var task := Task.new()
	var options := {"width": 5, "height": 5, "island_count": 10}
	check(task.start(42, options), "worker started")
	check(not task.start(43, options), "duplicate start rejected")
	options.width = 0
	var generated := await wait_task(task)
	check(generated.status == "success", "worker uses copied options")
	check(task.poll().is_empty(), "result delivered once")
	check(not contains_solution(generated), "worker handoff contains no solution")
	if generated.status != "success":
		quit(1)
		return
	var recipe: Dictionary = generated.recipe
	var id: String = recipe.puzzle.id
	check(recipe.parameters.width == 5 and recipe.parameters.height == 5 and recipe.puzzle.islands.size() == 10, "initial 5x5 ten islands")
	check(id == "procedural-id1-h02b-1-9ee1b9751911fc0d573e5aeaf302ca14761da348383407495e46210a0788f362", "H02B identity unchanged")
	var session := Session.new(catalog, "user://h02c-session.json")
	check(session.install_procedural(recipe), "session installs validated recipe")
	check(session.is_procedural() and session.current_index == 3 and session.catalog.size() == 4, "single procedural selector slot")
	check(session.current_puzzle().bridges.is_empty(), "no solution placed automatically")
	var puzzle := session.current_puzzle()
	var edges := Solver.candidate_edges(puzzle)
	check(Rules.cycle_bridge(puzzle, edges[0].a, edges[0].b).is_empty(), "procedural interaction uses original rules")
	check(session.capture(puzzle) and session.save_game(), "procedural move saved")
	check(session.install_procedural(recipe) and session.current_puzzle().bridges == puzzle.bridges, "repeated installation of the same identity preserves play")
	var saved := session.snapshot_data()
	check(not contains_solution(saved), "snapshot excludes solver witnesses")
	var reopened := Session.new(catalog, session.store.path)
	check(reopened.restore(), "procedural session reopened")
	check(reopened.snapshot_data() == saved, "exact snapshot recovered after JSON normalization")
	check(reopened.current_puzzle().bridges == puzzle.bridges and reopened.current_puzzle().puzzle_id == id, "bridges and stable identity recovered")
	check(reopened.procedural[id] == recipe, "seed parameters algorithm and identity schema recovered")
	reopened.select(0)
	check(reopened.catalog.size() == 4 and reopened.procedural.has(id), "static navigation retains procedural slot")
	reopened.select(3)
	check(reopened.current_puzzle().bridges == puzzle.bridges, "return to procedural retains play")
	var replacement_task := Task.new()
	replacement_task.start(43, {})
	var replacement := await wait_task(replacement_task)
	check(reopened.install_procedural(replacement.recipe), "new successful procedural replaces previous")
	check(reopened.procedural.size() == 1 and not reopened.boards.has(id) and reopened.catalog.size() == 4, "old generated slot pruned without unbounded saves")
	var invalid_recipe := recipe.duplicate(true)
	invalid_recipe.solution = {}
	var snapshot_before := reopened.snapshot_data()
	check(not reopened.install_procedural(invalid_recipe) and reopened.snapshot_data() == snapshot_before, "rejected recipe cannot replace current game")
	var large_seed := Task.new()
	large_seed.start(9223372036854775807, {})
	var large := await wait_task(large_seed)
	check(large.status == "success", "int64 seed supported by worker")
	if large.status == "success":
		var large_session := Session.new(catalog, "user://h02c-large-seed.json")
		check(large_session.install_procedural(large.recipe) and large_session.save_game(), "large seed saved without floating point conversion")
		var large_reopen := Session.new(catalog, large_session.store.path)
		check(large_reopen.restore() and large_reopen.snapshot_data() == large_session.snapshot_data(), "int64 seed and identity survive JSON exactly")
	var empty_task := Task.new()
	empty_task.start(1, {"max_attempts": 0})
	while not WorkerThreadPool.is_task_completed(empty_task._task_id):
		await process_frame
	empty_task._mutex.lock()
	empty_task._result.clear()
	empty_task._mutex.unlock()
	var empty_result := empty_task.poll()
	check(empty_result.get("status") == "failure" and empty_result.get("reason") == "worker_failed", "unexpected empty worker result cannot leave UI busy forever")
	test_migration()
	test_validation(saved)
	await test_ui()
	print("H02C RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func test_migration() -> void:
	var legacy := {"version": 1, "current_puzzle_id": "h01_2", "boards": {"h01_1": {"0:1": 2, "1:3": 2, "2:3": 1}, "h01_2": {"0:1": 1}}, "completed_ids": ["h01_1"]}
	var path := "user://h02c-legacy.json"
	write_text(path, JSON.stringify(legacy))
	var session := Session.new(catalog, path)
	check(session.restore(), "v1 save accepted")
	check(session.current_index == 1 and session.current_puzzle().bridge_count("0", "1") == 1, "legacy selected level and bridges retained")
	check(session.completed_ids == ["h01_1"] and session.procedural.is_empty(), "legacy progress retained")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 1, "read-only recovery does not overwrite legacy file")
	check(session.save_game(), "migration writes v2 at same path")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 2, "new payload is versioned v2")
	var again := Session.new(catalog, path)
	check(again.restore() and again.snapshot_data() == session.snapshot_data(), "migrated save reopens exactly")

func test_validation(valid: Dictionary) -> void:
	var store := Store.new("user://h02c-invalid.json")
	var id: String = valid.procedural.keys()[0]
	check(store.valid_snapshot(valid, catalog), "valid v2 data")
	var malformed: Array = []
	for field in ["seed", "algorithm_version", "identity_schema", "parameters", "puzzle"]:
		var data := valid.duplicate(true)
		data.procedural[id].erase(field)
		malformed.append(data)
	for seed_value in [42, "43", "042", "+42", "9223372036854775808", "not-a-seed"]:
		var data := valid.duplicate(true)
		data.procedural[id].seed = seed_value
		malformed.append(data)
	for version in ["h02b-2", "unknown"]:
		var data := valid.duplicate(true)
		data.procedural[id].algorithm_version = version
		malformed.append(data)
	for field in ["width", "island_count", "max_time_ms"]:
		var data := valid.duplicate(true)
		data.procedural[id].parameters[field] = -1
		malformed.append(data)
	var wrong_clue := valid.duplicate(true)
	wrong_clue.procedural[id].puzzle.islands[0].target += 1
	malformed.append(wrong_clue)
	var fractional := valid.duplicate(true)
	fractional.procedural[id].puzzle.islands[0].x = 1.5
	malformed.append(fractional)
	var extra := valid.duplicate(true)
	extra.procedural[id].solution = {}
	malformed.append(extra)
	extra = valid.duplicate(true)
	extra.solution = {}
	malformed.append(extra)
	extra = valid.duplicate(true)
	extra.procedural[id].puzzle.bridges = {}
	malformed.append(extra)
	var bad_edge := valid.duplicate(true)
	bad_edge.boards[id] = {"unknown:other": 1}
	malformed.append(bad_edge)
	var too_many := valid.duplicate(true)
	too_many.procedural["other"] = valid.procedural[id].duplicate(true)
	malformed.append(too_many)
	for data in malformed:
		check(not store.valid_snapshot(data, catalog), "malformed procedural state rejected " + str(checks))
	write_text(store.path, JSON.stringify(wrong_clue))
	var fallback := Session.new(catalog, store.path)
	check(not fallback.restore() and not fallback.is_procedural(), "bad procedural save falls back safely")
	check(not fallback.store.last_error.is_empty(), "recovery failure reported")

func test_ui() -> void:
	var ui = Main.instantiate()
	ui.save_path = "user://h02c-ui.json"
	root.add_child(ui)
	await process_frame
	check(ui.new_board_button.text == "Nuevo tablero" and not ui.new_board_button.disabled, "new board button available")
	var previous_seed: int = ui._last_requested_seed
	check(ui._request_new_puzzle(), "UI starts asynchronous generation")
	check(ui._last_requested_seed != previous_seed, "new seed chosen")
	check(ui.new_board_button.disabled and "Generando" in ui.status.text, "busy state shown")
	check(not ui._request_new_puzzle(), "UI rejects duplicate generation")
	await wait_ui(ui)
	check(ui.session.is_procedural() and ui.selector.item_count == 4, "procedural board presented with original levels")
	check(ui.board.puzzle.bridges.is_empty() and not contains_solution(ui.session.snapshot_data()), "UI has only playable state")
	var id: String = ui.board.puzzle.puzzle_id
	var edges := Solver.candidate_edges(ui.board.puzzle)
	ui.board._layout_islands()
	var a: Vector2 = ui.board.centers[edges[0].a]
	var b: Vector2 = ui.board.centers[edges[0].b]
	touch(ui.board, a, true)
	touch(ui.board, b, false)
	check(ui.board.puzzle.bridge_count(edges[0].a, edges[0].b) == 1, "procedural swipe places bridge")
	ui.undo_button.pressed.emit()
	check(ui.board.puzzle.bridges.is_empty(), "procedural undo")
	ui.redo_button.pressed.emit()
	check(ui.board.puzzle.bridge_count(edges[0].a, edges[0].b) == 1, "procedural redo")
	var state: Dictionary = ui.session.snapshot_data()
	ui.queue_free()
	await process_frame
	ui = Main.instantiate()
	ui.save_path = "user://h02c-ui.json"
	root.add_child(ui)
	await process_frame
	check(ui.session.snapshot_data() == state and ui.board.puzzle.puzzle_id == id, "UI reopen restores exact procedural game")
	check(ui.board.history.past.is_empty(), "reopened history starts from recovered bridges")
	ui.generation_options.max_attempts = 0
	check(ui._request_new_puzzle(), "failure request queued")
	await wait_ui(ui)
	check(ui.session.snapshot_data() == state and "No se pudo generar" in ui.status.text and not ui.new_board_button.disabled, "generation failure preserves current game and allows retry")
	ui.generation_options.max_attempts = 100
	check(ui._request_new_puzzle(), "new request before navigation")
	ui._select_puzzle(1)
	check(ui.session.current_index == 1, "navigation responsive while worker runs")
	await wait_ui(ui)
	check(ui.session.current_index == 1 and ui.session.procedural.has(id), "stale result cannot replace selected level or old procedural")
	ui._select_puzzle(3)
	check(ui._request_new_puzzle(), "new request before gameplay")
	ui.board._connect_islands(edges[0].a, edges[0].b)
	var edited: Dictionary = ui.board.puzzle.bridges.duplicate()
	await wait_ui(ui)
	check(ui.board.puzzle.puzzle_id == id and ui.board.puzzle.bridges == edited, "gameplay during generation invalidates stale result")
	for size in [Vector2i(360, 640), Vector2i(480, 800), Vector2i(720, 1280)]:
		root.content_scale_size = size
		root.size = size
		await process_frame
		await process_frame
		check(ui.new_board_button.global_position.x + ui.new_board_button.size.x <= root.get_visible_rect().size.x, "new control fits portrait")
		check(ui.next_button.global_position.y + ui.next_button.size.y <= root.get_visible_rect().size.y, "navigation stays visible")
	# Victory and procedural navigation still use the original rules and controls.
	var solved := Solver.new().solve(ui.board.puzzle)
	check(solved.status == "unique", "shown procedural is uniquely solvable")
	ui.restart_button.pressed.emit()
	for edge in solved.solutions[0]:
		var ids: PackedStringArray = edge.split(":")
		for count in int(solved.solutions[0][edge]):
			ui.board._connect_islands(ids[0], ids[1])
	check(not ui.next_button.disabled and ui.next_button.text == "Volver al primero" and "resuelto" in ui.status.text, "procedural victory and return control")
	check(id in ui.session.completed_ids and not contains_solution(ui.session.snapshot_data()), "procedural completion saved without hidden solution fields")
	ui.next_button.pressed.emit()
	check(ui.session.current_index == 0 and ui.session.procedural.has(id), "return to static sequence preserves procedural game")
	# Regression: a real previous procedural with bridges, completion and undo/redo.
	ui._select_puzzle(3)
	ui.restart_button.pressed.emit()
	ui.board._connect_islands(edges[0].a, edges[0].b)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	ui.undo_button.pressed.emit()
	var previous_state: Dictionary = ui.session.snapshot_data()
	var previous_puzzle: RefCounted = ui.board.puzzle
	var previous_past: Array = ui.board.history.past.duplicate(true)
	var previous_future: Array = ui.board.history.future.duplicate(true)
	var persisted_before := FileAccess.get_file_as_string(ui.save_path)
	check(not ui.board.puzzle.bridges.is_empty() and not previous_past.is_empty() and not previous_future.is_empty(), "replacement regression starts with played procedural and history")
	# Block the actual temporary destination, without changing the saved file path.
	var temporary_path := ProjectSettings.globalize_path(ui.save_path + ".tmp")
	check(DirAccess.make_dir_absolute(temporary_path) == OK, "simulate write failure at original save destination")
	check(ui._request_new_puzzle(), "generation before simulated storage failure")
	await wait_ui(ui)
	check(ui.session.snapshot_data() == previous_state, "failed replacement preserves entire previous session and progress")
	check(ui.board.puzzle == previous_puzzle and ui.board.puzzle.bridges == previous_state.boards[id], "failed replacement preserves displayed procedural and bridges")
	check(ui.board.history.past == previous_past and ui.board.history.future == previous_future, "failed replacement preserves undo and redo history")
	check(FileAccess.get_file_as_string(ui.save_path) == persisted_before, "failed replacement leaves persisted bytes unchanged")
	check(not ui.save_failed and "Se conserva tu partida" in ui.status.text and not ui.new_board_button.disabled, "clear replacement failure permits generating again")
	ui._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(FileAccess.get_file_as_string(ui.save_path) == persisted_before and ui.session.snapshot_data() == previous_state, "pause cannot retry an uncommitted replacement")
	var recovered := Session.new(catalog, ui.save_path)
	check(recovered.restore() and recovered.snapshot_data() == previous_state, "reopening after failed replacement recovers previous game exactly")
	check(DirAccess.remove_absolute(temporary_path) == OK, "restore writable save destination")
	check(ui._request_new_puzzle(), "player can retry generating after write failure")
	await wait_ui(ui)
	check(ui.session.is_procedural() and ui.board.puzzle.puzzle_id != id and ui.board.puzzle.bridges.is_empty(), "successful retry activates the new board")
	check(ui.session.store.load_game(catalog) == ui.session.snapshot_data(), "new board was persisted before activation")
	check(ui.board.history.past.is_empty() and ui.board.history.future.is_empty() and not ui.save_failed, "successful commit starts clean history")
	var before_shutdown := FileAccess.get_file_as_string(ui.save_path)
	check(ui._request_new_puzzle(), "worker active during scene teardown")
	var reference: WeakRef = weakref(ui)
	ui.queue_free()
	await process_frame
	check(reference.get_ref() == null and FileAccess.get_file_as_string("user://h02c-ui.json") == before_shutdown, "closing scene joins worker and cannot apply its late result")

func touch(board: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	board._gui_input(event)
