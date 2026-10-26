extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
const Store = preload("res://scripts/hashi_save_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var ui = Main.instantiate()
	ui.save_path = "user://h02c-process-game.json"
	root.add_child(ui)
	await process_frame
	var writing := "--write" in OS.get_cmdline_user_args()
	var valid := true
	var starts_at_home: bool = ui.screen == "home" and ui.home.visible and not ui.game_view.visible
	if writing:
		ui.home.new_button.pressed.emit()
		var deadline := Time.get_ticks_msec() + 5000
		while ui.generation_task != null and Time.get_ticks_msec() < deadline:
			await process_frame
		valid = ui.generation_task == null and ui.session.is_procedural()
		if valid:
			var edge: Dictionary = Solver.candidate_edges(ui.board.puzzle)[0]
			ui.board._connect_islands(edge.a, edge.b)
			ui.board._connect_islands(edge.a, edge.b)
			ui.undo_button.pressed.emit()
			ui.redo_button.pressed.emit()
			ui.undo_button.pressed.emit()
			ui._select_puzzle(1)
			ui._select_puzzle(3)
			valid = Store.new("user://h02c-process-expected.json").save_game(ui.session.snapshot_data(), catalog)
	else:
		ui.home.continue_button.pressed.emit()
		var expected := Store.new("user://h02c-process-expected.json").load_game(catalog)
		valid = not expected.is_empty() and ui.session.snapshot_data() == expected and ui.session.is_procedural() and ui.selector.selected == 3 and ui.generation_task == null
		if valid:
			var edge: Dictionary = Solver.candidate_edges(ui.board.puzzle)[0]
			var original: Dictionary = ui.board.puzzle.bridges.duplicate()
			ui.board._connect_islands(edge.a, edge.b)
			ui.undo_button.pressed.emit()
			valid = ui.board.puzzle.bridges == original
	var snapshot: Dictionary = ui.session.snapshot_data()
	valid = valid and starts_at_home and ui.screen == "game" and not ui.save_failed and ui.board.puzzle.bridges.size() == 1 and ui.board.puzzle.bridges.values()[0] == 1 and not JSON.stringify(snapshot).contains('"solution"') and not JSON.stringify(snapshot).contains('"construction_solution"')
	ui.queue_free()
	await process_frame
	print("PROCEDURAL RELAUNCH ", "write" if writing else "read", ": ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
