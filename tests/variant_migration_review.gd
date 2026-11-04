extends SceneTree
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Classic = preload("res://scripts/hashi_generator.gd")
const ClassicSolver = preload("res://scripts/hashi_solver.gd")
const VariantSolver = preload("res://scripts/hashi_variant_solver.gd")
const Story = preload("res://scripts/hashi_story_state.gd")
const Policy = preload("res://scripts/hashi_story_policy.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("VARIANT MIGRATION FAIL: ", label)
func recipe(value: Dictionary) -> Dictionary:
	return {"seed": str(value.seed), "algorithm_version": value.algorithm_version, "identity_schema": 1, "parameters": value.parameters, "puzzle": value.puzzle}
func solve_board(session: Session) -> void:
	var puzzle := session.current_puzzle()
	var solved := ClassicSolver.new().solve(puzzle) if puzzle.ruleset == "classic-1" else VariantSolver.new().solve(puzzle)
	check(solved.status == "unique", "unique level fixture")
	puzzle.bridges = solved.solutions[0].duplicate(true)
	check(session.capture_and_save(puzzle), "victory durable")
func run() -> void:
	var tutorials: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	var path := "user://minerva-legacy-variant.json"
	var session := Session.new(tutorials, path)
	session.story = {"version": 1, "policy": "classic-continuation-1", "frontier": 0, "recipes": {}}
	var generated := Classic.new().generate(42, {})
	check(generated.status == "success", "classic fixed-series fixture")
	check(session.install_procedural_and_save(recipe(generated), Mode.fresh("fixed")), "independent series installed")
	var saved_run := session.run.duplicate(true)
	var saved_procedural := session.procedural.duplicate(true)
	for ordinal in 12:
		check(session.select_and_save(session.story_index(ordinal)), "open legacy introduction")
		solve_board(session)
	for ordinal in range(12, 15):
		var next := Policy.generate(ordinal, {}, Story.definitions(session.story))
		check(next.status == "success", "legacy continuation generated")
		check(session.install_story_and_save(ordinal, next.recipe), "legacy recipe installed")
		if ordinal < 14:
			solve_board(session)
	var puzzle := session.current_puzzle()
	var edges := ClassicSolver.candidate_edges(puzzle)
	puzzle.bridges[puzzle.key(edges[0].a, edges[0].b)] = 1
	check(session.capture_and_save(puzzle), "legacy partial board retained")
	var old_recipes: Dictionary = session.story.recipes.duplicate(true)
	var old_bridges := puzzle.bridges.duplicate(true)
	var legacy := session.snapshot_data()
	legacy.version = 4
	legacy.erase("quality")
	legacy.erase("story_attempts")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var bytes := FileAccess.get_file_as_string(path)
	var reopened := Session.new(tutorials, path)
	check(reopened.restore(), "actual v4 legacy file restored")
	check(FileAccess.get_file_as_string(path) == bytes, "opening does not migrate bytes")
	check(reopened.story.frontier == 14 and reopened.story.variant_from == 16, "variants start at future stage")
	check(reopened.story.recipes == old_recipes and reopened.current_puzzle().bridges == old_bridges, "legacy recipes and partial bridges unchanged")
	check(reopened.run == saved_run and reopened.procedural == saved_procedural, "fixed-series state independent through migration")
	check(reopened.save_game(), "explicit atomic migration")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 7, "new schema written")
	solve_board(reopened)
	var last_classic := Policy.generate(15, {}, Story.definitions(reopened.story), int(reopened.story.variant_from))
	check(last_classic.status == "success" and last_classic.recipe.algorithm_version == "h02b-1", "unfinished old stage remains classical")
	check(reopened.install_story_and_save(15, last_classic.recipe), "remaining classic level installed")
	solve_board(reopened)
	var blue := Policy.generate(16, {}, Story.definitions(reopened.story), int(reopened.story.variant_from))
	check(blue.status == "success" and blue.recipe.parameters.kind == "blue", "next stage introduces blue rules")
	var before := reopened.snapshot_data()
	bytes = FileAccess.get_file_as_string(path)
	var temporary := ProjectSettings.globalize_path(path + ".tmp")
	check(DirAccess.make_dir_absolute(temporary) == OK, "block new variant write")
	check(not reopened.install_story_and_save(16, blue.recipe), "variant installation write refused")
	check(reopened.snapshot_data() == before and FileAccess.get_file_as_string(path) == bytes, "failed variant installation preserves old state")
	DirAccess.remove_absolute(temporary)
	check(reopened.install_story_and_save(16, blue.recipe), "variant transition atomic after retry")
	check(not reopened.install_procedural(blue.recipe), "variant cannot enter classic procedural channel")
	var snapshot := reopened.snapshot_data()
	var again := Session.new(tutorials, path)
	check(again.restore() and again.snapshot_data() == snapshot, "variant save roundtrip exact")
	check(again.story.variant_from == 16 and again.current_puzzle().ruleset == "visible-variants-1", "reopening never moves the curriculum boundary")
	check(again.run == saved_run and again.procedural == saved_procedural, "unrelated series still intact after transition")
	print("VARIANT MIGRATION REVIEW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
