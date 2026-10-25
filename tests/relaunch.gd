extends SceneTree
const Main = preload("res://scenes/main.tscn")
const FIRST_SOLUTION = {"0:1": 2, "1:3": 2, "2:3": 1}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var ui = Main.instantiate()
	ui.save_path = "user://h02a-relaunch.json"
	root.add_child(ui)
	await process_frame
	var writing := "--write" in OS.get_cmdline_user_args()
	if writing:
		for edge in FIRST_SOLUTION:
			var ids: PackedStringArray = edge.split(":")
			for count in int(FIRST_SOLUTION[edge]):
				ui.board._connect_islands(ids[0], ids[1])
		ui.next_button.pressed.emit()
		ui.board._connect_islands("0", "1")
	var valid: bool = ui.session.current_index == 1 and ui.board.puzzle.bridge_count("0", "1") == 1 and "h01_1" in ui.session.completed_ids and not ui.save_failed
	if not writing:
		# Undo one new change; restored bridges are the starting point, not history.
		valid = valid and ui.board.history.past.is_empty()
		ui.board._connect_islands("0", "1")
		ui.undo_button.pressed.emit()
		valid = valid and ui.board.puzzle.bridge_count("0", "1") == 1
	ui.queue_free()
	await process_frame
	print("RELAUNCH ", "write" if writing else "read", ": ", "PASS" if valid else "FAIL")
	quit(0 if valid else 1)
