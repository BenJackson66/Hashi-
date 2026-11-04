extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
const Quality = preload("res://scripts/hashi_quality.gd")
var checks := 0
var failures := 0
func _initialize():
	call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		printerr("IRON FAIL: ", label)
func settle(ui):
	var deadline := Time.get_ticks_msec() + 15000
	while (ui.generation_task != null or not ui.session.quality.pending.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null and ui.session.quality.pending.is_empty(), "all bounded work settles")
func solve_ui(ui):
	var result := Solver.new().solve(ui.board.puzzle)
	check(result.status == "unique", "real playable solution")
	for edge in result.solutions[0]:
		var ends: PackedStringArray = str(edge).split(":")
		for n in int(result.solutions[0][edge]):
			ui.board._connect_islands(ends[0], ends[1])
			await settle(ui)
func run():
	var ui = Main.instantiate()
	ui.save_path = "user://iron-ui.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.save_path))
	root.add_child(ui)
	await process_frame
	check(ui.home.iron_button != null and "Alma" in ui.home.iron_button.text, "Alma accessible from home")
	ui.home.iron_button.pressed.emit()
	await settle(ui)
	check(ui.session.run.mode == "iron" and "Alma" in ui.mode_status.text, "new iron run publishes only after recipe")
	for index in 7:
		await solve_ui(ui)
		check(ui.session.quality.streak == index + 1 and ui.session.quality.iron_record == index + 1, "perfect credit and iron record")
		check(Quality.color_name(ui.session.quality) == ("Dorado" if index == 6 else ("Morado" if index >= 2 else "Azul")), "threshold color")
		ui._next_puzzle()
		await settle(ui)
	ui.board.undo()
	check(not ui.session.quality.iron_ended, "no-op undo never faults")
	var chosen: String = Solver.new().solve(ui.board.puzzle).solutions[0].keys()[0]
	var ends: PackedStringArray = chosen.split(":")
	ui.board._connect_islands(ends[0], ends[1])
	await settle(ui)
	check(not ui.session.quality.iron_ended, "correct first bridge does not end iron")
	ui.board.undo()
	check(ui.session.quality.iron_ended and ui.session.quality.streak == 0 and ui.session.quality.iron_record == 7, "actual undo ends iron and preserves record")
	check(not ui.board.input_enabled and ui.next_button.disabled and "terminó" in ui.status.text, "ended state visible and frozen")
	var before: Dictionary = ui.session.snapshot_data()
	ui._next_puzzle()
	check(ui.session.snapshot_data() == before and ui.generation_task == null, "ended challenge cannot advance")
	ui._show_story(); ui._select_story(0)
	check(ui.session.is_story() and ui.board.input_enabled, "normal story remains playable with ended iron paused")
	await solve_ui(ui)
	check(ui.session.quality.streak == 1 and ui.session.story.frontier == 1 and ui.session.quality.iron_ended, "story credits independent streak and progress")
	ui.board.undo()
	check(ui.session.quality.streak == 0 and ui.session.story.frontier == 1, "normal fault preserves story unlock")
	ui._show_home(); ui.home.iron_button.pressed.emit()
	await settle(ui)
	check(ui.session.run.mode == "iron" and not ui.session.quality.iron_ended and ui.session.quality.iron_record == 7, "explicit new challenge retains record")
	var snapshot: Dictionary = ui.session.snapshot_data()
	ui.queue_free(); await process_frame
	ui = Main.instantiate(); ui.save_path = "user://iron-ui.json"; root.add_child(ui)
	await process_frame
	ui._continue_game()
	check(ui.session.snapshot_data() == snapshot, "iron and streak restore exactly")
	ui.queue_free(); await process_frame
	print("IRON STREAKS RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
