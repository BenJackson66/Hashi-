extends SceneTree
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Policy = preload("res://scripts/hashi_free_play.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var catalog: Array

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("PLAY MODES FAIL: ", label)

func recipe(seed_value: int, profile: String = "local") -> Dictionary:
	var value := Policy.new().generate(seed_value, profile)
	check(value.status == "success", "recipe available")
	return {"seed": str(value.seed), "algorithm_version": value.algorithm_version, "identity_schema": 1,
		"parameters": value.parameters, "puzzle": value.puzzle}

func solved(puzzle: Puzzle) -> Puzzle:
	var result := Solver.new().solve(puzzle)
	check(result.status == "unique", "independent solve")
	puzzle.bridges = result.solutions[0].duplicate(true)
	return puzzle

func wait_ui(ui: Control) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "worker completes")

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func settle_quality(ui: Control) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while not ui.session.quality.pending.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not ui.session.quality.pending.is_empty():
		check(false, "quality decision settles before next UI action")

func run() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var progression := Mode.fresh("progression")
	var expected := ["local", "local", "local", "local", "contradiction1", "local", "contradiction1", "contradiction1", "contradiction1"]
	for wins in expected.size():
		progression.wins = wins
		check(Mode.next_profile(progression) == expected[wins], "exact progression at win " + str(wins))
	var fixed := Mode.fresh("fixed", "contradiction1")
	check(Mode.next_profile(fixed, "local") == "contradiction1", "fixed ignores free preference")
	check(Mode.next_profile(Mode.fresh(), "contradiction1") == "contradiction1", "free retains preference")
	await test_transactions()
	await test_ui()
	print("PLAY MODES RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)

func test_transactions() -> void:
	var path := "user://modes-session.json"
	var session := Session.new(catalog, path)
	var value := recipe(1)
	var run_state := Mode.fresh("progression")
	check(session.install_procedural_and_save(value, run_state), "new run and recipe saved atomically")
	var puzzle := solved(session.current_puzzle())
	var before := session.snapshot_data()
	var bytes := FileAccess.get_file_as_string(path)
	var temporary := ProjectSettings.globalize_path(path + ".tmp")
	check(DirAccess.make_dir_absolute(temporary) == OK, "block actual victory write")
	check(not session.capture_and_save(puzzle), "victory write fails")
	check(session.snapshot_data() == before and FileAccess.get_file_as_string(path) == bytes, "failed victory does not publish bridges or credit")
	DirAccess.remove_absolute(temporary)
	check(session.capture_and_save(puzzle) and session.run.wins == 1, "retry credits committed victory once")
	check(session.capture_and_save(puzzle) and session.run.wins == 1, "repeated victory no double credit")
	puzzle.reset()
	check(session.capture_and_save(puzzle) and session.run.wins == 1, "reset retains milestone")
	puzzle = solved(puzzle)
	check(session.capture_and_save(puzzle) and session.run.wins == 1, "replay no double credit")
	var reopened := Session.new(catalog, path)
	check(reopened.restore() and reopened.snapshot_data() == session.snapshot_data(), "run and credited ID survive reopening")
	check(reopened.capture_and_save(puzzle) and reopened.run.wins == 1, "reopening before Next does not double credit")
	before = session.snapshot_data()
	bytes = FileAccess.get_file_as_string(path)
	var replacement := recipe(2, "contradiction1")
	var next_run := Mode.fresh("fixed", "contradiction1")
	check(DirAccess.make_dir_absolute(temporary) == OK, "block mode replacement")
	check(not session.install_procedural_and_save(replacement, next_run), "new fixed run not committed")
	check(session.snapshot_data() == before and FileAccess.get_file_as_string(path) == bytes, "mode failure preserves old run and file")
	DirAccess.remove_absolute(temporary)
	check(session.install_procedural_and_save(replacement, next_run), "fixed run installed")
	check(session.run.wins == 0 and session.run.credited_id.is_empty() and session.run.mode == "fixed", "fresh fixed run starts clean")
	check(session.select_and_save(0) and session.run.mode == "fixed", "learning selection preserves procedural mode")
	check(session.select_and_save(catalog.size()) and session.run.mode == "fixed", "return to mode unchanged")
	# v2 fixture is written with its original schema and never rewritten on open.
	var legacy := session.snapshot_data()
	legacy.version = 2
	legacy.erase("run")
	legacy.erase("story")
	legacy.erase("quality")
	legacy.erase("story_attempts")
	var id: String = legacy.procedural.keys()[0]
	legacy.completed_ids.append(id)
	write_json(path, legacy)
	bytes = FileAccess.get_file_as_string(path)
	reopened = Session.new(catalog, path)
	check(reopened.restore(), "actual v2 payload accepted")
	check(reopened.run.mode == "free" and reopened.run.wins == 0 and reopened.run.credited_id == id, "no retrospective run wins")
	check(FileAccess.get_file_as_string(path) == bytes, "v2 open leaves bytes untouched")
	check(reopened.save_game() and JSON.parse_string(FileAccess.get_file_as_string(path)).version == Store.VERSION, "next explicit save migrates atomically")
	var valid := reopened.snapshot_data()
	for change in [{"wins": -1}, {"wins": 1.5}, {"wins": true}, {"mode": "unknown"}, {"credited_id": "foreign"}, {"board_profile": "normal"}]:
		var invalid := valid.duplicate(true)
		invalid.run.merge(change, true)
		check(not reopened.store.valid_snapshot(invalid, catalog), "malformed run rejected " + str(change))
	# Constant-size credit marker, even for an effectively infinite final stage.
	var final_run := Mode.fresh("progression")
	final_run.wins = 1000000
	for i in 1000:
		final_run = Mode.credit(final_run, "current-" + str(i))
	check(final_run.size() == 6 and final_run.credited_id == "current-999" and Mode.next_profile(final_run) == "contradiction1", "final stage keeps bounded metadata and continues")

func test_ui() -> void:
	var ui = Main.instantiate()
	ui.save_path = "user://modes-ui.json"
	root.add_child(ui)
	await process_frame
	ui.home.challenge.select(1)
	ui.home.challenge.item_selected.emit(1)
	ui.home.fixed_button.pressed.emit()
	check(ui.session.run.mode == "free", "requested mode not published during worker")
	await wait_ui(ui)
	check(ui.session.run.mode == "fixed" and ui.session.run.fixed_profile == "contradiction1", "fixed button starts selected profile")
	check("Dificultad fija" in ui.mode_status.text, "mode is visible")
	ui._show_home()
	ui.home.challenge.select(0)
	ui.home.challenge.item_selected.emit(0)
	ui.home.continue_button.pressed.emit()
	check(ui.settings.profile == "local" and Mode.next_profile(ui.session.run, ui.settings.profile) == "contradiction1", "free preference independent of active fixed run")
	var edges := Solver.candidate_edges(ui.board.puzzle)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	await settle_quality(ui)
	var before: Dictionary = ui.session.snapshot_data()
	ui._show_home()
	ui.home.progression_button.pressed.emit()
	check(ui._confirmation_pending and ui.session.snapshot_data() == before, "switching mode protects partial board")
	ui.home.cancel_button.pressed.emit()
	check(ui.session.snapshot_data() == before and ui.session.run.mode == "fixed", "cancel preserves mode and state")
	ui.home.progression_button.pressed.emit()
	ui.home.confirm_button.pressed.emit()
	await wait_ui(ui)
	check(ui.session.run.mode == "progression" and ui.session.run.board_profile == "local" and ui.session.run.wins == 0, "confirm retains intended new mode")
	# Fail the winning move. Live Board must be retained while durable Session stays old.
	var solution: Dictionary = Solver.new().solve(ui.board.puzzle).solutions[0]
	var keys: Array = solution.keys()
	for n in keys.size():
		var ids: PackedStringArray = str(keys[n]).split(":")
		for count in int(solution[keys[n]]):
			if n == keys.size() - 1 and count == int(solution[keys[n]]) - 1:
				DirAccess.make_dir_absolute(ProjectSettings.globalize_path(ui.save_path + ".tmp"))
			ui.board._connect_islands(ids[0], ids[1])
			await settle_quality(ui)
	check(ui.save_failed and Rules.is_solved(ui.board.puzzle) and ui.session.run.wins == 0, "uncommitted winning move retains Board, not credit")
	ui._next_puzzle()
	check(ui.generation_task == null and ui.next_button.disabled, "Next cannot consume uncommitted victory")
	ui._show_home()
	ui.home.lesson_requested.emit(0)
	check(ui.session.is_procedural() and Rules.is_solved(ui.board.puzzle), "selection cannot discard dirty board")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.save_path + ".tmp"))
	ui._save_game()
	check(not ui.save_failed and ui.session.run.wins == 1, "retry captures newest Board and credit together")
	var snapshot: Dictionary = ui.session.snapshot_data()
	ui.queue_free()
	await process_frame
	ui = Main.instantiate()
	ui.save_path = "user://modes-ui.json"
	root.add_child(ui)
	await process_frame
	ui.home.continue_button.pressed.emit()
	check(ui.session.snapshot_data() == snapshot and ui.session.run.wins == 1, "Continue restores exact mode and credited victory")
	ui._next_puzzle()
	await wait_ui(ui)
	check(ui.session.run.wins == 1 and ui.session.run.mode == "progression" and ui.session.run.credited_id.is_empty(), "Next retains series and resets only current credit marker")
	# Ordinary unsaved input cannot be lost by selecting learning either.
	var temporary := ProjectSettings.globalize_path(ui.save_path + ".tmp")
	DirAccess.make_dir_absolute(temporary)
	var edge: Dictionary = Solver.candidate_edges(ui.board.puzzle)[0]
	ui.board._connect_islands(edge.a, edge.b)
	await settle_quality(ui)
	var dirty: Dictionary = ui.board.puzzle.bridges.duplicate(true)
	ui._select_puzzle(0)
	check(ui.save_failed and ui.session.is_procedural() and ui.board.puzzle.bridges == dirty, "ordinary failed move survives attempted selection")
	DirAccess.remove_absolute(temporary)
	ui._save_game()
	check(not ui.save_failed and ui.session.boards[ui.board.puzzle.puzzle_id] == dirty, "ordinary move retried from newest Board")
	ui.board.reset()
	ui._show_home()
	var unchanged: Dictionary = ui.session.snapshot_data()
	ui.generation_options.max_attempts = 0
	ui.home.fixed_button.pressed.emit()
	await wait_ui(ui)
	check(ui.session.snapshot_data() == unchanged, "generation failure cannot reset prior mode or counter")
	ui.generation_options.max_attempts = 100
	ui.home.fixed_button.pressed.emit()
	ui.home.rules_button.pressed.emit()
	await wait_ui(ui)
	check(ui.session.snapshot_data() == unchanged and ui.home.page == "rules", "navigation invalidates pending mode and recipe together")
	ui.queue_free()
	await process_frame
