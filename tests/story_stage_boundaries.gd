extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
var checks := 0
var failures := 0
var ui: Control
var saved_run: Dictionary
var procedural_id: String
var procedural_bridges: Dictionary
func _initialize() -> void:
	call_deferred("review")
func verify(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("MINERVA STORY FAIL: ", label)
func settle_worker() -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	verify(ui.generation_task == null, "bounded story worker")
func reopen() -> void:
	var before: Dictionary = ui.session.snapshot_data()
	ui.queue_free()
	await process_frame
	ui = Main.instantiate()
	ui.save_path = "user://minerva-story.json"
	root.add_child(ui)
	await process_frame
	ui.home.continue_button.pressed.emit()
	verify(ui.session.snapshot_data() == before, "exact durable reopening")
func solve_board() -> void:
	var solution := Solver.new().solve(ui.board.puzzle)
	verify(solution.status == "unique", "unique actual story level")
	if solution.status != "unique":
		return
	for edge in solution.solutions[0]:
		var ends: PackedStringArray = str(edge).split(":")
		for repetition in int(solution.solutions[0][edge]):
			ui.board._connect_islands(ends[0], ends[1])
func review() -> void:
	ui = Main.instantiate()
	ui.save_path = "user://minerva-story.json"
	root.add_child(ui)
	await process_frame
	ui.home.challenge.select(1)
	ui.home.challenge.item_selected.emit(1)
	ui.home.fixed_button.pressed.emit()
	await settle_worker()
	var edges := Solver.candidate_edges(ui.board.puzzle)
	ui.board._connect_islands(edges[0].a, edges[0].b)
	saved_run = ui.session.run.duplicate(true)
	procedural_id = ui.board.puzzle.puzzle_id
	procedural_bridges = ui.board.puzzle.bridges.duplicate(true)
	ui._show_home()
	ui._show_story()
	ui._select_story(0)
	verify(ui.session.is_story() and not ui.session.is_procedural(), "story channel separate")
	var generated_ids: Array = []
	for ordinal in 18:
		verify(ui.session.story_ordinal() == ordinal, "ordered level " + str(ordinal))
		verify(int(ui.session.story.frontier) == ordinal, "frontier before victory")
		if ordinal >= 12:
			verify(ui.board.puzzle.puzzle_id not in generated_ids, "new continuation ID")
			generated_ids.append(ui.board.puzzle.puzzle_id)
		solve_board()
		verify(int(ui.session.story.frontier) == ordinal + 1, "one story credit")
		ui.board.undo()
		ui.board.redo()
		verify(int(ui.session.story.frontier) == ordinal + 1, "no replay story credit")
		verify(ui.session.run == saved_run and ui.session.boards[procedural_id] == procedural_bridges, "fixed run survives campaign")
		verify(ui.session.story.recipes.size() <= 4, "bounded recent recipes")
		if ordinal == 11:
			await reopen()
		ui.next_button.pressed.emit()
		await settle_worker()
	verify(ui.session.story_ordinal() == 18 and ui.session.story.frontier == 18, "continuous path beyond introduction")
	verify(ui.session.story.recipes.size() == 4 and not ui.session.story.recipes.has("12"), "old tail outside retained window")
	await reopen()
	var current_id: String = ui.board.puzzle.puzzle_id
	ui._show_home()
	ui._show_story()
	ui._select_story(11)
	verify(ui.session.story_ordinal() == 11, "initial levels remain replayable")
	ui.next_button.pressed.emit()
	await settle_worker()
	verify(ui.session.story_ordinal() == 18 and ui.board.puzzle.puzzle_id == current_id, "replay skips archived tail without replacing frontier")
	verify(ui.session.run == saved_run and ui.session.boards[procedural_id] == procedural_bridges, "independent state remains intact")
	ui.queue_free()
	await process_frame
	print("MINERVA STORY: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
