extends SceneTree
const Policy = preload("res://scripts/hashi_free_play.gd")
const Logical = preload("res://scripts/hashi_logical_profile.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const Settings = preload("res://scripts/hashi_free_settings.gd")
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FREE PLAY FAIL: ", label)
func wait_ui(ui: Control) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while ui.generation_task != null and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "bounded worker terminates")
func run() -> void:
	var report: Dictionary = {"policy": Policy.VERSION, "profiles": {}}
	for profile in Policy.LABELS:
		var layouts := {}
		var clues := {}
		var times: Array = []
		var candidates := 0
		var started := Time.get_ticks_usec()
		for seed_value in range(1, 51):
			var generated := Policy.new().generate(seed_value, profile)
			check(generated.status == "success", "selected unique puzzle " + profile + " seed=" + str(seed_value))
			if generated.status != "success":
				continue
			times.append(generated.selection.elapsed_ms)
			candidates += int(generated.selection.candidates)
			var puzzle := Puzzle.new(generated.puzzle)
			var classified := Logical.new().analyze(puzzle)
			check(classified.status == "solved" and classified.profile == profile, "requested profile actually proven")
			check(Solver.new().solve(puzzle).status == "unique", "uniqueness independent from rating")
			check(puzzle.bridges.is_empty(), "playable puzzle has no solution placed")
			layouts["%dx%d/%d" % [generated.parameters.width, generated.parameters.height, puzzle.islands.size()]] = true
			clues[JSON.stringify(puzzle.islands).sha256_text()] = true
			if seed_value <= 5:
				var replay := Policy.new().generate(seed_value, profile)
				check(replay.puzzle == generated.puzzle and replay.seed == generated.seed and replay.parameters == generated.parameters, "same seed/profile/policy gives same accepted board")
		check(layouts.size() == 3, "all three structures represented without using size as rating")
		check(clues.size() >= 45, "variety of actual clue definitions")
		times.sort()
		report.profiles[profile] = {"requested": 50, "successes": times.size(), "layouts": layouts.keys(), "distinct_clues": clues.size(),
			"mean_candidates": float(candidates) / maxf(1, times.size()), "mean_selection_ms": times.reduce(func(a: float, b: float): return a + b, 0.0) / maxf(1, times.size()),
			"evaluation_total_ms": float(Time.get_ticks_usec() - started) / 1000.0,
			"p95_selection_ms": times[47] if times.size() == 50 else -1, "max_selection_ms": times.back() if not times.is_empty() else -1}
	check(Policy.new().generate(1, "invented").reason == "invalid_selection", "unsupported rating refused")
	check(Policy.new().generate(1, "local", {}, "", 0).reason == "selection_attempt_limit", "candidate limit")
	check(Policy.new().generate(1, "local", {}, "", 64, 0).reason == "selection_time_limit", "time limit")
	check(Policy.new().generate(1, "local", {"max_attempts": 0}).status == "failure", "generation failure retained")
	var settings := Settings.new("user://free-settings-test")
	settings.restore()
	check(settings.profile == "local", "new preference default")
	check(settings.choose("contradiction1"), "profile saved separately")
	var reopened := Settings.new(settings.path)
	reopened.restore()
	check(reopened.profile == "contradiction1", "next board preference survives restart")
	check(not reopened.choose("normal") and reopened.profile == "contradiction1", "unvalidated middle label cannot be selected")
	await test_ui()
	print("FREE PLAY REPORT: ", JSON.stringify(report))
	print("FREE PLAY RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
func test_ui() -> void:
	var ui = Main.instantiate()
	ui.save_path = "user://free-ui-game.json"
	root.add_child(ui)
	await process_frame
	ui.home.challenge.select(1)
	ui.home.challenge.item_selected.emit(1)
	check(ui.settings.profile == "contradiction1", "home challenge choice reaches selection policy")
	ui.home.new_button.pressed.emit()
	check(ui.home.challenge.disabled, "choice locked during request")
	await wait_ui(ui)
	var first_id: String = ui.board.puzzle.puzzle_id
	check(ui.session.is_procedural() and Logical.new().analyze(ui.board.puzzle).profile == "contradiction1", "UI presents requested profile")
	check(not JSON.stringify(ui.session.snapshot_data()).contains('"solution"'), "no witness in save")
	var solved := Solver.new().solve(ui.board.puzzle)
	for edge in solved.solutions[0]:
		var ids: PackedStringArray = edge.split(":")
		for count in int(solved.solutions[0][edge]):
			ui.board._connect_islands(ids[0], ids[1])
	check(not ui.next_button.disabled and ui.next_button.text == "Siguiente tablero", "victory enables direct next")
	var before: Dictionary = ui.session.snapshot_data()
	var bytes := FileAccess.get_file_as_string(ui.save_path)
	var temporary := ProjectSettings.globalize_path(ui.save_path + ".tmp")
	check(DirAccess.make_dir_absolute(temporary) == OK, "fail next-board write")
	ui.next_button.pressed.emit()
	ui.next_button.pressed.emit()
	check(ui.next_button.disabled and not ui._confirmation_pending, "next starts once, no warning for solved board")
	await wait_ui(ui)
	check(ui.session.snapshot_data() == before and FileAccess.get_file_as_string(ui.save_path) == bytes, "failed next preserves solved board and save")
	check(not ui.next_button.disabled and "guardar" in ui.status.text, "next retry available with explanation")
	DirAccess.remove_absolute(temporary)
	ui.next_button.pressed.emit()
	await wait_ui(ui)
	check(ui.screen == "game" and ui.session.is_procedural() and ui.board.puzzle.puzzle_id != first_id, "next remains in free play with a new board")
	check(Logical.new().analyze(ui.board.puzzle).profile == "contradiction1", "next respects selected challenge")
	var snapshot: Dictionary = ui.session.snapshot_data()
	ui.queue_free()
	await process_frame
	ui = Main.instantiate()
	ui.save_path = "user://free-ui-game.json"
	root.add_child(ui)
	await process_frame
	check(ui.screen == "home" and ui.settings.profile == "contradiction1", "restart retains preference, opens home")
	ui.home.continue_button.pressed.emit()
	check(ui.session.snapshot_data() == snapshot, "v2 free board continues unchanged")
	ui._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(ui.screen == "home", "Android Back from game opens home")
	ui.home.rules_button.pressed.emit()
	ui._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(ui.home.page == "home", "Android Back from rules opens home")
	ui.queue_free()
	await process_frame
