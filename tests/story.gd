extends SceneTree
const Catalog = preload("res://scripts/hashi_story_catalog.gd")
const Policy = preload("res://scripts/hashi_story_policy.gd")
const State = preload("res://scripts/hashi_story_state.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const VariantSolver = preload("res://scripts/hashi_variant_solver.gd")
const Logical = preload("res://scripts/hashi_logical_profile.gd")
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Free = preload("res://scripts/hashi_free_play.gd")
const Main = preload("res://scenes/main.tscn")
var checks := 0
var failures := 0
var tutorials: Array
func _initialize():
	call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		printerr("STORY FAIL: ", label)
func solution(puzzle: Puzzle) -> Puzzle:
	var result: Dictionary = Solver.new().solve(puzzle) if puzzle.ruleset == "classic-1" else VariantSolver.new().solve(puzzle)
	check(result.status == "unique", "unique solution")
	puzzle.bridges = result.solutions[0].duplicate(true)
	return puzzle
func run():
	tutorials = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var ids: Array = []
	var fingerprints: Array = []
	for i in Catalog.COUNT:
		var definition: Dictionary = Catalog.entries()[i].puzzle
		var puzzle := solution(Puzzle.new(definition))
		check(Logical.new().analyze(Puzzle.new(definition)).profile == Policy.profile(i), "curated profile " + str(i))
		check(definition.id not in ids and Policy.fingerprint(definition) not in fingerprints, "distinct intro clues")
		check(definition.size() == 3 and not definition.has("bridges"), "no packaged witness")
		ids.append(definition.id)
		fingerprints.append(Policy.fingerprint(definition))
	await transactions()
	await ui_walk()
	print("STORY RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
func transactions():
	var path := "user://story-tests.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var session := Session.new(tutorials, path)
	check(not session.select_and_save(session.story_index(1)), "Session refuses locked level")
	var free := Free.new().generate(42, "local")
	var recipe := {"seed": str(free.seed), "algorithm_version": free.algorithm_version, "identity_schema": 1, "parameters": free.parameters, "puzzle": free.puzzle}
	check(session.install_procedural_and_save(recipe, Mode.fresh("fixed")), "preserve existing fixed series")
	var prior_run: Dictionary = session.run.duplicate(true)
	var procedural: Dictionary = session.procedural.duplicate(true)
	check(session.select_and_save(session.story_index(0)) and session.is_story() and not session.is_procedural(), "story channel separate")
	var won := solution(session.current_puzzle())
	var before := session.snapshot_data()
	var bytes := FileAccess.get_file_as_string(path)
	var temp := ProjectSettings.globalize_path(path + ".tmp")
	DirAccess.make_dir_absolute(temp)
	check(not session.capture_and_save(won) and session.snapshot_data() == before, "failed victory publishes no credit")
	check(FileAccess.get_file_as_string(path) == bytes and session.story.frontier == 0, "failed victory preserves bytes and unlock")
	DirAccess.remove_absolute(temp)
	check(session.capture_and_save(won) and session.story.frontier == 1, "victory unlock atomic")
	check(session.capture_and_save(won) and session.story.frontier == 1, "victory credits once")
	won.bridges = {}
	check(session.capture_and_save(won) and session.story.frontier == 1, "reset never relocks")
	check(session.capture_and_save(solution(won)) and session.story.frontier == 1, "replay no duplicate advance")
	for ordinal in range(1, 12):
		check(session.select_and_save(session.story_index(ordinal)), "intro unlock " + str(ordinal))
		check(session.capture_and_save(solution(session.current_puzzle())), "intro victory " + str(ordinal))
	var seen: Array = []
	for ordinal in range(12, 22):
		var result := Policy.generate(ordinal, {}, State.definitions(session.story), int(session.story.variant_from))
		check(result.status == "success", "tail generated " + str(ordinal))
		if result.status != "success":
			return
		var fingerprint := Policy.fingerprint(result.recipe.puzzle)
		check(fingerprint not in seen, "tail clues distinct across repeated profiles")
		seen.append(fingerprint)
		if ordinal == 12:
			var repeat := Policy.generate(ordinal, {}, State.definitions(session.story), int(session.story.variant_from))
			check(repeat.recipe == result.recipe, "deterministic continuation recipe")
			before = session.snapshot_data()
			DirAccess.make_dir_absolute(temp)
			check(not session.install_story_and_save(ordinal, result.recipe) and session.snapshot_data() == before, "failed install preserves old state")
			DirAccess.remove_absolute(temp)
		check(session.install_story_and_save(ordinal, result.recipe), "install tail atomically")
		check(session.capture_and_save(solution(session.current_puzzle())), "tail victory")
		check(session.story.frontier == ordinal + 1 and session.story.recipes.size() <= 4, "bounded window and exact frontier")
		var restored := Session.new(tutorials, path)
		check(restored.restore() and restored.snapshot_data() == session.snapshot_data(), "reopen full snapshot")
	check(session.story_index(12) == -1 and session.story_index(21) >= 0, "expired tail unavailable")
	check(session.procedural == procedural and session.run == prior_run, "story never mutates independent series")
	check(session.select_and_save(session.story_index(0)), "return to initial always possible")
	check(session.capture_and_save(solution(session.current_puzzle())) and session.story.frontier == 22, "old intro replay leaves frontier unchanged")
	check(FileAccess.get_file_as_string(path).to_utf8_buffer().size() < Store.MAX_BYTES, "bounded save below budget")
	for version in [1, 2, 3]:
		var legacy := Session.new(tutorials, path).snapshot_data()
		legacy.version = version
		legacy.erase("story")
		legacy.erase("quality")
		if version < 3:
			legacy.erase("run")
		if version < 2:
			legacy.erase("procedural")
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(legacy)); file.close()
		bytes = FileAccess.get_file_as_string(path)
		var restored := Session.new(tutorials, path)
		check(restored.restore() and restored.story == State.fresh(), "read version " + str(version))
		check(FileAccess.get_file_as_string(path) == bytes, "opening legacy does not rewrite")
		check(restored.save_game(), "explicit write migrates")
func ui_walk():
	var ui = Main.instantiate()
	ui.save_path = "user://story-ui.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.save_path))
	root.add_child(ui)
	await process_frame
	ui.home.story_button.pressed.emit()
	check(ui.screen == "story" and ui.story_view.level_buttons[1].disabled, "map displays locked level")
	ui._select_story(1)
	check(not ui.session.is_story(), "UI refuses locked ordinal")
	ui._select_story(0)
	check(ui.session.is_story() and ui.screen == "game", "map opens first level")
	var solved := solution(ui.board.puzzle)
	ui.board.puzzle.bridges = solved.bridges
	ui._save_game()
	ui._next_puzzle()
	check(ui.session.story_ordinal() == 1, "Next follows story without tutorial wrap")
	var snapshot: Dictionary = ui.session.snapshot_data()
	ui.queue_free()
	await process_frame
	ui = Main.instantiate(); ui.save_path = "user://story-ui.json"
	root.add_child(ui)
	await process_frame
	ui._continue_game()
	check(ui.session.snapshot_data() == snapshot and ui.session.is_story(), "Continue restores exact story selection")
	ui.queue_free()
	await process_frame
