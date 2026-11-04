extends SceneTree
const Main = preload("res://scenes/main.tscn")
const Classic = preload("res://scripts/hashi_solver.gd")
const Variants = preload("res://scripts/hashi_variant_solver.gd")
const OUTPUT := "res://docs/review/art"
var failures := 0
func _initialize():
	call_deferred("run")
func check(value: bool, label: String):
	if not value:
		failures += 1
		printerr("VARIANT VISUAL FAIL: ", label)
func settle():
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String):
	await settle()
	check(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, name)
func run():
	if DisplayServer.get_name() == "headless":
		quit(2); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for dimensions in [Vector2i(360,640)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var ui = Main.instantiate()
		ui.save_path = "user://variants-render-%d-%d.json" % [dimensions.x, Time.get_ticks_usec()]
		root.add_child(ui)
		await settle()
		for ordinal in 21:
			ui._select_story(ordinal)
			var deadline := Time.get_ticks_msec() + 12000
			while ui.generation_task != null and Time.get_ticks_msec() < deadline:
				await process_frame
			check(ui.session.story_ordinal() == ordinal, "actual ordinal")
			if ordinal in [12,16,20]:
				await settle()
				check(ui.board.size.y >= 200, "playable board")
				check(ui.next_button.get_global_rect().end.y <= dimensions.y, "footer in viewport")
				check(ui.selector.get_global_rect().end.x <= dimensions.x, "header in viewport")
				await capture("%s-game-%d" % [{12:"blue",16:"mystery",20:"combined"}[ordinal], dimensions.x])
				ui._show_story()
				ui.story_view.scroll.scroll_vertical = 0
				await capture("%s-map-%d" % [{12:"blue",16:"mystery",20:"combined"}[ordinal], dimensions.x])
				ui._continue_game()
			var result: Dictionary = Classic.new().solve(ui.board.puzzle) if ui.board.puzzle.ruleset == "classic-1" else Variants.new().solve(ui.board.puzzle)
			check(result.status == "unique", "solvable render fixture")
			if result.status != "unique":
				quit(1); return
			ui.board.puzzle.bridges = result.solutions[0]
			ui._save_game()
		ui.queue_free()
		await process_frame
	print("VARIANT RENDER: ", failures, " failures; renderer=", RenderingServer.get_video_adapter_name())
	quit(1 if failures else 0)
