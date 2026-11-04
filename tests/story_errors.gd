extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
var checks := 0
var failures := 0
var ui: Control
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("STORY ERROR FAIL: ", label)
func wait_worker() -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "worker terminates")
func run() -> void:
	ui = Main.instantiate()
	ui.save_path = "user://story-errors.json"
	root.add_child(ui)
	await process_frame
	ui._show_story()
	var before: Dictionary = ui.session.snapshot_data()
	var temporary := ProjectSettings.globalize_path(ui.save_path + ".tmp")
	check(DirAccess.make_dir_absolute(temporary) == OK, "block selection save")
	ui._select_story(0)
	check(ui.screen == "story" and ui.session.snapshot_data() == before, "failed selection preserves session")
	check(ui.story_view.message.visible and "guardar" in ui.story_view.message.text, "failed selection visible in map")
	DirAccess.remove_absolute(temporary)
	ui._select_story(0)
	for ordinal in 12:
		var solved := Solver.new().solve(ui.board.puzzle)
		check(solved.status == "unique", "intro fixture uniquely solvable")
		ui.board.puzzle.bridges = solved.solutions[0].duplicate(true)
		ui._save_game()
		if ordinal < 11:
			ui._next_puzzle()
	ui._show_story()
	before = ui.session.snapshot_data()
	var bytes := FileAccess.get_file_as_string(ui.save_path)
	ui.generation_options.max_attempts = 0
	ui._select_story(12)
	check(ui.story_view.follow_button.disabled and not ui.story_view.back_button.disabled, "busy locks selection while back remains available")
	await wait_worker()
	check(ui.story_view.message.visible and "generar" in ui.story_view.message.text, "generation failure visible in map")
	check(ui.session.snapshot_data() == before and FileAccess.get_file_as_string(ui.save_path) == bytes, "failed generation preserves frontier and save")
	ui.generation_options.max_attempts = 100
	DirAccess.make_dir_absolute(temporary)
	ui._select_story(12)
	await wait_worker()
	check(ui.story_view.message.visible and "guardar" in ui.story_view.message.text, "new level write failure visible in map")
	check(ui.session.snapshot_data() == before and FileAccess.get_file_as_string(ui.save_path) == bytes, "new level write failure preserves snapshot")
	DirAccess.remove_absolute(temporary)
	ui._select_story(12)
	ui._show_home()
	ui._show_story()
	await wait_worker()
	check(ui.screen == "story" and ui.session.snapshot_data() == before, "navigation discards obsolete recipe and selection")
	check(not ui.story_view.message.visible, "obsolete request message cleared")
	ui.queue_free()
	await process_frame
	print("STORY ERRORS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
