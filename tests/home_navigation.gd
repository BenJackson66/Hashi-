extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Session = preload("res://scripts/hashi_session.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL H03B1: ", label)

func launch(path: String) -> Control:
	var ui = Main.instantiate()
	ui.save_path = path
	root.add_child(ui)
	return ui

func wait_ui(ui: Control) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "bounded asynchronous request finishes")

func run() -> void:
	var path := "user://h03b1-game.json"
	var ui = launch(path)
	await process_frame
	check(ui.screen == "home" and ui.home.visible and not ui.game_view.visible, "fresh installation opens home")
	check(ui.home.continue_button.disabled and not FileAccess.file_exists(path), "no fake save or continue on fresh install")
	ui.home.continue_button.pressed.emit()
	check(ui.screen == "home", "disabled continue guarded in controller too")
	ui.home.rules_button.pressed.emit()
	check(ui.home.page == "rules" and not FileAccess.file_exists(path), "rules do not create a game")
	ui.home.rules_back_button.pressed.emit()
	ui.home.learn_button.pressed.emit()
	check(ui.home.page == "learn" and ui.home.lesson_buttons.size() == 3, "all three learning boards available")
	ui.home.lesson_buttons[1].pressed.emit()
	check(ui.screen == "game" and ui.session.current_index == 1 and not ui.home.visible, "learning choice opens requested board")
	check(ui.session.store.load_game(ui.puzzles) == ui.session.snapshot_data(), "selection saved before activation")
	var edges := Solver.candidate_edges(ui.board.puzzle)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	ui.undo_button.pressed.emit()
	var snapshot: Dictionary = ui.session.snapshot_data()
	var persisted := FileAccess.get_file_as_string(path)
	var puzzle: RefCounted = ui.board.puzzle
	var past: Array = ui.board.history.past.duplicate(true)
	var future: Array = ui.board.history.future.duplicate(true)
	ui.board.pressed = edges[0].a
	ui.board.active_touch = 0
	ui.home_button.pressed.emit()
	ui.home_button.pressed.emit()
	check(ui.screen == "home" and not ui.home.continue_button.disabled, "return enables continue; repeated home harmless")
	check(ui.session.snapshot_data() == snapshot and FileAccess.get_file_as_string(path) == persisted, "return to home is read-only")
	check(ui.board.pressed.is_empty() and ui.board.active_touch == -1, "navigation cancels incomplete gesture")
	ui.home.continue_button.pressed.emit()
	ui.home.continue_button.pressed.emit()
	check(ui.screen == "game" and ui.board.puzzle == puzzle, "continue reuses live puzzle without duplicated transition")
	check(ui.board.history.past == past and ui.board.history.future == future, "menu round trip preserves undo and redo")
	ui.redo_button.pressed.emit()
	check(ui.board.puzzle.bridge_count(edges[0].a, edges[0].b) == 2, "redo still operates after continue")
	# An existing H02-C v2 session always opens at home without rewriting bytes.
	snapshot = ui.session.snapshot_data()
	persisted = FileAccess.get_file_as_string(path)
	ui.queue_free()
	await process_frame
	ui = launch(path)
	await process_frame
	check(ui.screen == "home" and ui.session.snapshot_data() == snapshot, "existing v2 progress loaded behind home")
	check(FileAccess.get_file_as_string(path) == persisted, "v2 startup leaves saved bytes intact")
	ui.home.continue_button.pressed.emit()
	check(ui.session.current_index == 1 and ui.board.puzzle.bridges == snapshot.boards.h01_2, "continue opens last selected board with its bridges")
	# Fresh procedural uses existing worker, without leaking a solution into play.
	ui.home_button.pressed.emit()
	ui.home.new_button.pressed.emit()
	var request_seed: int = ui._last_requested_seed
	ui.home.new_button.pressed.emit()
	check(ui.generation_task != null and ui.home.new_button.disabled and ui._last_requested_seed == request_seed, "repeated new tap starts one worker")
	check("Generando" in ui.home.notice.text, "home displays generation status")
	await wait_ui(ui)
	check(ui.screen == "game" and ui.session.is_procedural() and ui.board.puzzle.bridges.is_empty(), "generated puzzle opens unsolved after persistence")
	var procedural_id: String = ui.board.puzzle.puzzle_id
	edges = Solver.candidate_edges(ui.board.puzzle)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	ui.undo_button.pressed.emit()
	var procedural_bridges: Dictionary = ui.board.puzzle.bridges.duplicate(true)
	puzzle = ui.board.puzzle
	past = ui.board.history.past.duplicate(true)
	future = ui.board.history.future.duplicate(true)
	persisted = FileAccess.get_file_as_string(path)
	snapshot = ui.session.snapshot_data()
	ui.new_board_button.pressed.emit()
	ui.new_board_button.pressed.emit()
	check(ui.screen == "confirm" and ui.home.page == "confirm" and ui.generation_task == null, "started procedural requires confirmation exactly once")
	ui.home.cancel_button.pressed.emit()
	ui.home.cancel_button.pressed.emit()
	check(ui.screen == "game" and ui.board.puzzle == puzzle, "cancel from game returns same puzzle")
	check(ui.session.snapshot_data() == snapshot and FileAccess.get_file_as_string(path) == persisted, "cancel retains full state and file")
	check(ui.board.history.past == past and ui.board.history.future == future, "cancel preserves both history stacks")
	# Static and procedural progress are independent, including a warning from static play.
	for index in range(3):
		ui.home_button.pressed.emit()
		ui.home.learn_button.pressed.emit()
		ui.home.lesson_buttons[index].pressed.emit()
		check(ui.session.current_index == index, "learning choice " + str(index))
		var static_edges := Solver.candidate_edges(ui.board.puzzle)
		if ui.board.puzzle.bridges.is_empty():
			ui.board._connect_islands(static_edges[0].a, static_edges[0].b)
		check(ui.session.boards[procedural_id] == procedural_bridges, "learning does not modify procedural " + str(index))
	ui.home_button.pressed.emit()
	snapshot = ui.session.snapshot_data()
	persisted = FileAccess.get_file_as_string(path)
	ui.home.new_button.pressed.emit()
	check(ui.home.page == "confirm" and ui.generation_task == null, "warning also protects procedural while last selection is static")
	ui.home.cancel_button.pressed.emit()
	check(ui.screen == "home" and ui.home.page == "home" and ui.session.snapshot_data() == snapshot, "cancel from home preserves selected static board")
	# Real write failure following accepted confirmation must keep all older progress.
	var temporary := ProjectSettings.globalize_path(path + ".tmp")
	check(DirAccess.make_dir_absolute(temporary) == OK, "block atomic write destination")
	ui.home.new_button.pressed.emit()
	ui.home.confirm_button.pressed.emit()
	request_seed = ui._last_requested_seed
	ui.home.confirm_button.pressed.emit()
	check(ui.generation_task != null and ui._last_requested_seed == request_seed, "duplicate confirmation cannot launch two requests")
	await wait_ui(ui)
	check(ui.screen == "home" and ui.session.snapshot_data() == snapshot, "failed replacement keeps old selection and all games")
	check(FileAccess.get_file_as_string(path) == persisted, "failed save preserves persisted bytes")
	check("Se conserva tu partida" in ui.home.notice.text and not ui.home.new_button.disabled, "failed save has clear notice and retry")
	ui._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(FileAccess.get_file_as_string(path) == persisted, "pause cannot publish rejected replacement")
	var recovered := Session.new(ui.puzzles, path)
	check(recovered.restore() and recovered.snapshot_data() == snapshot, "failed replacement reopens previous save exactly")
	# A failed navigation write must not discard the current board/history either.
	ui.home.learn_button.pressed.emit()
	ui.home.lesson_buttons[0].pressed.emit()
	check(ui.session.snapshot_data() == snapshot and "guardar la selección" in ui.home.notice.text, "failed selection is transactional")
	check(DirAccess.remove_absolute(temporary) == OK, "restore writable storage")
	ui.home.learn_back_button.pressed.emit()
	ui.generation_options.max_attempts = 0
	ui.home.new_button.pressed.emit()
	ui.home.confirm_button.pressed.emit()
	await wait_ui(ui)
	check(ui.screen == "home" and ui.session.snapshot_data() == snapshot and FileAccess.get_file_as_string(path) == persisted, "exhausted generation preserves all prior state")
	check("No se pudo generar" in ui.home.notice.text and not ui.home.new_button.disabled, "generation error visible and retryable")
	ui.generation_options.max_attempts = 100
	# An obsolete result must not pull a player out of the rules or a selected board.
	ui.home.new_button.pressed.emit()
	ui.home.confirm_button.pressed.emit()
	ui.home.rules_button.pressed.emit()
	await wait_ui(ui)
	check(ui.screen == "home" and ui.home.page == "rules" and ui.session.snapshot_data() == snapshot, "rules navigation invalidates pending result")
	check(FileAccess.get_file_as_string(path) == persisted, "stale result never persists")
	ui.home.rules_back_button.pressed.emit()
	ui.home.new_button.pressed.emit()
	ui.home.confirm_button.pressed.emit()
	ui.home.learn_button.pressed.emit()
	ui.home.lesson_buttons[0].pressed.emit()
	await wait_ui(ui)
	check(ui.screen == "game" and ui.session.current_index == 0 and ui.session.procedural.has(procedural_id), "learning selection invalidates old generation")
	ui.home_button.pressed.emit()
	ui.home.new_button.pressed.emit()
	ui.home.confirm_button.pressed.emit()
	await wait_ui(ui)
	check(ui.screen == "game" and ui.session.is_procedural() and ui.board.puzzle.puzzle_id != procedural_id, "confirmed successful replacement activates new board")
	check(ui.board.puzzle.bridges.is_empty() and ui.session.store.load_game(ui.puzzles) == ui.session.snapshot_data(), "new procedural persisted before it is shown")
	for id in ["h01_1", "h01_2", "h01_3"]:
		check(ui.session.boards[id] == snapshot.boards[id], "successful replacement preserves static " + id)
	# Returning home while generating from game invalidates the in-flight result.
	persisted = FileAccess.get_file_as_string(path)
	ui.new_board_button.pressed.emit()
	check(ui.generation_task != null and not ui._confirmation_pending, "empty procedural needs no replacement warning")
	ui.home_button.pressed.emit()
	await wait_ui(ui)
	check(ui.screen == "home" and FileAccess.get_file_as_string(path) == persisted, "home navigation discards in-flight game result")
	await check_portrait(ui)
	# Completed IDs are historical; the warning must follow today's actual state.
	var witness := Solver.new().solve(ui.board.puzzle)
	for edge in witness.solutions[0]:
		var ids: PackedStringArray = edge.split(":")
		for count in int(witness.solutions[0][edge]):
			ui.board._connect_islands(ids[0], ids[1])
	ui.new_board_button.pressed.emit()
	check(ui.generation_task != null and not ui._confirmation_pending, "solved procedural needs no replacement warning")
	ui.home_button.pressed.emit()
	await wait_ui(ui)
	ui.home.continue_button.pressed.emit()
	ui.undo_button.pressed.emit()
	ui.new_board_button.pressed.emit()
	check(ui._confirmation_pending and ui.generation_task == null, "undo after victory protects unfinished procedural despite completed milestone")
	ui.home.cancel_button.pressed.emit()
	ui.queue_free()
	await process_frame
	await check_legacy_and_corrupt()
	print("H03B1 RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func check_portrait(ui: Control) -> void:
	for dimensions in [Vector2i(360, 640), Vector2i(480, 800), Vector2i(720, 1280)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		ui._show_home()
		await process_frame
		await process_frame
		for button in [ui.home.continue_button, ui.home.new_button, ui.home.learn_button, ui.home.rules_button]:
			check(button.size.y >= 56 and button.global_position.x >= 0 and button.global_position.x + button.size.x <= dimensions.x, "home touch target fits " + str(dimensions))
		ui.home.continue_button.pressed.emit()
		await process_frame
		await process_frame
		check(ui.board.size.y >= 200 and ui.board.size.x >= 200, "playable board area " + str(dimensions))
		check(ui.home_button.global_position.x >= 0 and ui.selector.global_position.x + ui.selector.size.x <= dimensions.x, "game header fits " + str(dimensions))
		check(ui.next_button.global_position.y + ui.next_button.size.y <= dimensions.y, "game actions fit " + str(dimensions))

func check_legacy_and_corrupt() -> void:
	var path := "user://h03b1-v1.json"
	var legacy := {"version": 1, "current_puzzle_id": "h01_3", "boards": {"h01_3": {"0:3": 1}, "h01_1": {"0:1": 2}}, "completed_ids": []}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var before := FileAccess.get_file_as_string(path)
	var ui = launch(path)
	await process_frame
	check(ui.screen == "home" and not ui.home.continue_button.disabled and FileAccess.get_file_as_string(path) == before, "v1 startup is compatible and read-only")
	ui.home.rules_button.pressed.emit()
	ui.home.rules_back_button.pressed.emit()
	ui.home.continue_button.pressed.emit()
	check(ui.session.current_index == 2 and ui.board.puzzle.bridges == {"0:3": 1}, "continue v1 restores last selection exactly")
	ui.home_button.pressed.emit()
	check(FileAccess.get_file_as_string(path) == before, "v1 navigation does not force migration")
	ui.queue_free()
	await process_frame
	path = "user://h03b1-corrupt.json"
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	ui = launch(path)
	await process_frame
	check(ui.screen == "home" and ui.home.continue_button.disabled and not ui.home.notice.text.is_empty(), "corrupt recovery warns on home")
	ui.home.rules_button.pressed.emit()
	ui.home.rules_back_button.pressed.emit()
	ui._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(FileAccess.get_file_as_string(path) == "{broken", "navigation and pause do not erase bad save")
	ui.queue_free()
	await process_frame
