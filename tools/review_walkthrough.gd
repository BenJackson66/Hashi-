extends SceneTree
## Real rendered desktop review; use X11/GL, not --headless. Test data only.
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
var failures := 0
var output := "res://.local/visual-review"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("VISUAL WALK FAIL: ", label)

func settle() -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "rendered image " + name)
	check(image.save_png(output + "/" + name + ".png") == OK, "saved screenshot " + name)

func click(button: Control) -> void:
	await settle()
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("This review requires a real renderer (X11/Xvfb supported).")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var ui = Main.instantiate()
	ui.save_path = "user://visual-review-%d.json" % Time.get_ticks_usec()
	root.size = Vector2i(480, 800)
	root.content_scale_size = root.size
	root.add_child(ui)
	await capture("01-home-480")
	await click(ui.home.rules_button)
	check(ui.home.page == "rules", "rules actual pointer dispatch")
	await capture("02-rules-480")
	# Scroll to the actual return control, then click it.
	ui.home.scroll.scroll_vertical = 2000
	await click(ui.home.rules_back_button)
	check(ui.home.page == "home", "rules return")
	await click(ui.home.learn_button)
	await capture("03-learn-480")
	await click(ui.home.lesson_buttons[1])
	check(ui.screen == "game" and ui.session.current_index == 1, "learn choice actual pointer dispatch")
	await capture("04-learning-game-480")
	await click(ui.home_button)
	await click(ui.home.new_button)
	var deadline := Time.get_ticks_msec() + 10000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.session.is_procedural(), "new board")
	await capture("05-free-game-480")
	var edge: Dictionary = Solver.candidate_edges(ui.board.puzzle)[0]
	ui.board._layout_islands()
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = ui.board.global_position + ui.board.centers[edge.a if pressed else edge.b]
		Input.parse_input_event(event)
		await process_frame
	check(ui.board.puzzle.bridge_count(edge.a, edge.b) == 1, "touch routed through viewport")
	await click(ui.new_board_button)
	check(ui.home.page == "confirm", "replacement warning")
	await capture("06-confirm-480")
	await click(ui.home.cancel_button)
	check(ui.screen == "game", "cancel")
	await click(ui.restart_button)
	var solution := Solver.new().solve(ui.board.puzzle)
	for key in solution.solutions[0]:
		var ids: PackedStringArray = key.split(":")
		for count in int(solution.solutions[0][key]):
			ui.board._connect_islands(ids[0], ids[1])
	await capture("07-victory-480")
	var old_id: String = ui.board.puzzle.puzzle_id
	await click(ui.next_button)
	deadline = Time.get_ticks_msec() + 10000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.session.is_procedural() and ui.board.puzzle.puzzle_id != old_id, "next free board actual click")
	for dimensions in [Vector2i(360, 640), Vector2i(720, 1280)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await capture("08-game-%d" % dimensions.x)
		await click(ui.home_button)
		await capture("09-home-%d" % dimensions.x)
		await click(ui.home.continue_button)
	root.size = Vector2i(480, 800)
	root.content_scale_size = root.size
	await click(ui.home_button)
	ui.home.challenge.select(1)
	ui.home.challenge.item_selected.emit(1)
	await capture("10-reflexive-home-480")
	await click(ui.home.new_button)
	deadline = Time.get_ticks_msec() + 10000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.session.is_procedural() and "Reflexivo" in ui.board.puzzle.title, "reflexive selection rendered")
	await capture("11-reflexive-game-480")
	ui.queue_free()
	await process_frame
	print("RENDERED WALK: ", failures, " failures; renderer=", RenderingServer.get_video_adapter_name())
	quit(1 if failures else 0)
