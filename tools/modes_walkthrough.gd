extends SceneTree
## Rendered X11 review, separate from headless logic tests and real Android.
const Main = preload("res://scenes/main.tscn")
var failures := 0
var output := "res://docs/review/play-modes"
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("MODES VISUAL FAIL: ", label)
func settle() -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK, name)
func click(button: Control, scroll: ScrollContainer = null) -> void:
	if scroll != null:
		scroll.ensure_control_visible(button)
	await settle()
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await process_frame
	await settle()
func wait_generation(ui: Control) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "generation done")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for dimensions in [Vector2i(360, 640), Vector2i(480, 800)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var ui = Main.instantiate()
		ui.save_path = "user://modes-render-%d.json" % Time.get_ticks_usec()
		root.add_child(ui)
		await capture("home-top-%d" % dimensions.x)
		ui.home.scroll.scroll_vertical = 3000
		await capture("home-bottom-%d" % dimensions.x)
		await click(ui.home.rules_button, ui.home.scroll)
		check(ui.home.page == "rules", "rules accessible below scroll")
		await click(ui.home.rules_back_button, ui.home.scroll)
		await click(ui.home.learn_button, ui.home.scroll)
		check(ui.home.page == "learn", "learning accessible below scroll")
		await click(ui.home.learn_back_button, ui.home.scroll)
		ui.home.challenge.select(1)
		ui.home.challenge.item_selected.emit(1)
		await click(ui.home.fixed_button, ui.home.scroll)
		await wait_generation(ui)
		check(ui.session.run.mode == "fixed" and ui.session.run.board_profile == "contradiction1", "fixed actual button")
		await capture("fixed-reflexive-%d" % dimensions.x)
		check(ui.board.size.y >= 200 and ui.next_button.get_global_rect().end.y <= dimensions.y, "mode label leaves board and actions inside viewport")
		await click(ui.home_button)
		await click(ui.home.progression_button, ui.home.scroll)
		await wait_generation(ui)
		check(ui.session.run.mode == "progression", "progression actual button")
		await capture("progression-%d" % dimensions.x)
		ui.queue_free()
		await process_frame
	print("MODES RENDERED WALK: ", failures, " failures; renderer=", RenderingServer.get_video_adapter_name())
	quit(1 if failures else 0)
