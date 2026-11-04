extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Solver = preload("res://scripts/hashi_solver.gd")
const OUTPUT := "res://docs/review/iron-streaks"
var failures := 0
func _initialize():
	call_deferred("run")
func check(value: bool, label: String):
	if not value:
		failures += 1
		printerr("IRON VISUAL FAIL: ", label)
func settle():
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
func capture(ui, name: String, dimensions: Vector2i):
	await settle()
	check(ui.board.size.y >= 200, name + " board height")
	check(ui.next_button.get_global_rect().end.y <= dimensions.y, name + " footer")
	check(ui.selector.get_global_rect().end.x <= dimensions.x, name + " header")
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + name + "-%d.png" % dimensions.x) == OK, "capture")
func work(ui):
	var deadline := Time.get_ticks_msec() + 15000
	while (ui.generation_task != null or not ui.session.quality.pending.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
func run():
	if DisplayServer.get_name() == "headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions in [Vector2i(360,640),Vector2i(480,800)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var ui = Main.instantiate()
		ui.save_path = "user://iron-render-%d-%d.json" % [dimensions.x,Time.get_ticks_usec()]
		root.add_child(ui)
		await settle()
		ui.home.scroll.ensure_control_visible(ui.home.iron_button)
		await settle()
		check(root.get_texture().get_image().save_png(OUTPUT + "/home-%d.png" % dimensions.x) == OK, "home capture")
		ui.home.iron_button.pressed.emit()
		await work(ui)
		await capture(ui,"iron-active",dimensions)
		var result := Solver.new().solve(ui.board.puzzle)
		ui.board.puzzle.bridges = result.solutions[0].duplicate(true)
		ui._save_game()
		await work(ui)
		await capture(ui,"iron-perfect",dimensions)
		ui.board.reset()
		await capture(ui,"iron-ended",dimensions)
		ui._show_story();ui._select_story(0)
		ui.session.quality.serial += 1
		ui.session.quality.pending.append({"serial":ui.session.quality.serial,"id":ui.board.puzzle.puzzle_id,"bridges":{},"iron":false})
		ui.session.save_game()
		ui.quality_worker.limits = {"max_nodes":0}
		var deadline := Time.get_ticks_msec() + 5000
		while not ui.quality_worker.uncertain and Time.get_ticks_msec() < deadline:
			await process_frame
		ui._update_status("")
		check(ui.quality_retry.visible and not ui.board.input_enabled,"pending freezes input and exposes retry")
		await capture(ui,"pending",dimensions)
		ui._show_home()
		check("Comprobando" in ui.home.notice.text or "pendiente" in ui.home.notice.text,"pending notice in home")
		ui._show_story()
		check(ui.story_view.follow_button.disabled and ui.story_view.message.visible,"pending notice in map")
		ui._continue_game()
		ui.session.quality.pending.clear()
		ui.quality_worker.limits.clear()
		var temp := ProjectSettings.globalize_path(ui.save_path + ".tmp")
		DirAccess.make_dir_absolute(temp)
		ui._save_game()
		ui._update_status("")
		check(ui.save_failed and ui.quality_retry.visible and ui.quality_retry.text == "Reintentar guardado", "explicit save retry")
		await capture(ui,"save-failed",dimensions)
		DirAccess.remove_absolute(temp)
		ui.quality_retry.pressed.emit()
		check(not ui.save_failed,"save retry recovery")
		ui.queue_free();await process_frame
	print("IRON RENDER: ",failures," failures;renderer=",RenderingServer.get_video_adapter_name())
	quit(1 if failures else 0)
