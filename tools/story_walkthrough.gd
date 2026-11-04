extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
var failures := 0
const OUTPUT := "res://docs/review/story"
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("STORY VISUAL FAIL: ", label)
func settle() -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "capture " + name)
func click(button: Control, scroller: ScrollContainer = null) -> void:
	await settle()
	if scroller != null:
		scroller.ensure_control_visible(button)
	await settle()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		Input.parse_input_event(event)
		await process_frame
	await settle()
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions in [Vector2i(360, 640), Vector2i(480, 800)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var ui = Main.instantiate()
		ui.save_path = "user://visual-story-%d-%d.json" % [dimensions.x, Time.get_ticks_usec()]
		root.add_child(ui)
		await settle()
		await click(ui.home.story_button, ui.home.scroll)
		check(ui.screen == "story", "story from real pointer click")
		ui.story_view.scroll.scroll_vertical = 0
		await capture("map-top-%d" % dimensions.x)
		check(ui.story_view.level_buttons[1].disabled, "next level visibly locked")
		ui.story_view.scroll.scroll_vertical = 2000
		ui.story_view.scroll.ensure_control_visible(ui.story_view.back_button)
		await capture("map-bottom-%d" % dimensions.x)
		await click(ui.story_view.level_buttons[0], ui.story_view.scroll)
		check(ui.screen == "game" and ui.session.is_story(), "story level via real pointer")
		await settle()
		check(ui.selector.get_global_rect().end.x <= dimensions.x, "header fits viewport")
		check(ui.next_button.get_global_rect().end.y <= dimensions.y, "footer fits viewport")
		check(ui.board.size.y >= 200, "board keeps playable height")
		await capture("game-%d" % dimensions.x)
		for ordinal in 12:
			var solution := Solver.new().solve(ui.board.puzzle)
			check(solution.status == "unique", "solve review fixture")
			ui.board.puzzle.bridges = solution.solutions[0].duplicate(true)
			ui._save_game()
			if ordinal == 0:
				await capture("victory-%d" % dimensions.x)
			await click(ui.next_button)
			var deadline := Time.get_ticks_msec() + 12000
			while ui.generation_task != null and Time.get_ticks_msec() < deadline:
				await process_frame
		check(ui.session.story_ordinal() == 12, "initial levels enter endless route")
		await capture("continuous-%d" % dimensions.x)
		ui._show_story()
		await settle()
		ui.story_view.scroll.scroll_vertical = 2000
		ui.story_view.scroll.ensure_control_visible(ui.story_view.back_button)
		await capture("recent-%d" % dimensions.x)
		await click(ui.story_view.back_button, ui.story_view.scroll)
		check(ui.screen == "home", "map return reachable")
		ui.queue_free()
		await process_frame
	print("STORY RENDER: ", failures, " failures; ", RenderingServer.get_video_adapter_name())
	quit(1 if failures else 0)
