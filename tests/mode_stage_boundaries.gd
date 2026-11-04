extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("review")
func verify(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("MINERVA FAIL: ", label)
func wait_worker(ui: Control) -> void:
	var limit := Time.get_ticks_msec() + 15000
	while (ui.generation_task != null or not ui.session.quality.pending.is_empty()) and Time.get_ticks_msec() < limit:
		await process_frame
	verify(ui.generation_task == null and ui.session.quality.pending.is_empty(), "worker finishes")
func review() -> void:
	var ui = Main.instantiate()
	ui.save_path = "user://minerva-frontiers.json"
	root.add_child(ui)
	await process_frame
	ui.home.progression_button.pressed.emit()
	await wait_worker(ui)
	var expected := ["local", "local", "local", "local", "contradiction1", "local", "contradiction1", "contradiction1"]
	for index in expected.size():
		verify(ui.session.run.mode == "progression", "mode retained at board " + str(index + 1))
		verify(ui.session.run.board_profile == expected[index], "actual board profile at " + str(index + 1))
		verify(ui.session.run.wins == index, "count before win " + str(index + 1))
		var answer := Solver.new().solve(ui.board.puzzle)
		verify(answer.status == "unique", "independent solution")
		for edge in answer.solutions[0]:
			var ends: PackedStringArray = str(edge).split(":")
			for repetition in int(answer.solutions[0][edge]):
				ui.board._connect_islands(ends[0], ends[1])
				await wait_worker(ui)
		verify(ui.session.run.wins == index + 1, "one committed win")
		ui.board.undo()
		await wait_worker(ui)
		ui.board.redo()
		await wait_worker(ui)
		verify(ui.session.run.wins == index + 1, "undo/redo cannot duplicate win")
		if index in [2, 6]:
			var state: Dictionary = ui.session.snapshot_data()
			ui.queue_free()
			await process_frame
			ui = Main.instantiate()
			ui.save_path = "user://minerva-frontiers.json"
			root.add_child(ui)
			await process_frame
			ui.home.continue_button.pressed.emit()
			verify(ui.session.snapshot_data() == state, "restart at stage frontier")
		ui.next_button.pressed.emit()
		await wait_worker(ui)
	verify(ui.session.run.wins == 8 and ui.session.run.board_profile == "contradiction1", "final stage keeps running")
	ui.queue_free()
	await process_frame
	print("MINERVA MODES: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
