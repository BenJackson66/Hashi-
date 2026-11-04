extends SceneTree
const Generator = preload("res://scripts/hashi_variant_generator.gd")
const Recipe = preload("res://scripts/hashi_variant_recipe.gd")
const Solver = preload("res://scripts/hashi_variant_solver.gd")
const Classic = preload("res://scripts/hashi_solver.gd")
const Rules = preload("res://scripts/hashi_variant_rules.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
const Story = preload("res://scripts/hashi_story_state.gd")
const Policy = preload("res://scripts/hashi_story_policy.gd")
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
		printerr("VARIANTS FAIL: ", label)
func run():
	tutorials = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	for kind in Recipe.KINDS:
		for seed_value in [1, 42, 847, 2081, 30109]:
			var generated := Generator.new().generate(seed_value, kind)
			check(generated.status == "success", "generated " + kind + str(seed_value))
			if generated.status != "success":
				continue
			var recipe: Dictionary = generated.recipe
			check(Recipe.normalize(recipe.puzzle.id, recipe) == recipe, "canonical public recipe")
			check(Store.new().normalize_recipe(recipe.puzzle.id, recipe).is_empty(), "free rejects variant recipe")
			check(generated.size() == 2 and recipe.size() == 5 and recipe.puzzle.size() == 4, "no witness crosses worker boundary")
			var puzzle := Puzzle.new(recipe.puzzle)
			var result := Solver.new().solve(puzzle)
			check(result.status == "unique", "public rules unique")
			check(Classic.new().solve(puzzle).status == "invalid", "classic solver remains strict")
			puzzle.bridges = result.solutions[0]
			check(Rules.is_solved(puzzle), "visible victory accepts witness")
			for item in puzzle.islands:
				if item.variant == "mystery":
					check(item.target == 0, "no secret mystery target")
					var bad: Dictionary = recipe.duplicate(true)
					for changed in bad.puzzle.islands:
						if changed.id == item.id:
							changed.target = 7
					check(Solver.new().solve(Puzzle.new(bad.puzzle)).status == "invalid" and Recipe.normalize(bad.puzzle.id, bad).is_empty(), "altered mystery target rejected")
				if item.variant == "blue":
					check(item.target >= 2, "blue supplies a meaningful simple constraint in seed corpus")
					for edge in puzzle.bridges:
						if item.id in str(edge).split(":"):
							check(puzzle.bridges[edge] == 1, "blue witness has only singles")
			var repeated := Generator.new().generate(seed_value, kind)
			check(repeated == generated, "deterministic public recipe")
			check(Solver.new().solve(Puzzle.new(recipe.puzzle), {"max_nodes": 0}).status == "incomplete", "node budget never claims uniqueness")
			check(Solver.new().solve(Puzzle.new(recipe.puzzle), {"max_time_ms": 0}).status == "incomplete", "time budget never claims uniqueness")
	check(Generator.new().generate(1, "combined", {"max_attempts": 0}).status == "failure", "invalid generation budget fails closed")
	var no_budget := Policy.generate(12, {"max_time_ms": 0}, [], 12)
	check(no_budget.status == "failure" and not no_budget.has("recipe"), "story variant respects zero requested budget")
	await integration()
	print("VARIANTS RESULT: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
func solve_ui(ui):
	var result: Dictionary = Classic.new().solve(ui.board.puzzle) if ui.board.puzzle.ruleset == "classic-1" else Solver.new().solve(ui.board.puzzle)
	check(result.status == "unique", "UI actual level unique")
	if result.status != "unique":
		return
	for edge in result.solutions[0]:
		var ends: PackedStringArray = str(edge).split(":")
		for n in int(result.solutions[0][edge]):
			ui.board._connect_islands(ends[0], ends[1])
			await settle(ui)
func settle(ui):
	var deadline := Time.get_ticks_msec() + 12000
	while (ui.generation_task != null or not ui.session.quality.pending.is_empty()) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ui.generation_task == null, "bounded worker")
func integration():
	var ui = Main.instantiate()
	ui.save_path = "user://variants-ui.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ui.save_path))
	root.add_child(ui)
	await process_frame
	for ordinal in 25:
		ui._select_story(ordinal)
		await settle(ui)
		check(ui.session.story_ordinal() == ordinal, "selected ordinal " + str(ordinal))
		var kind := Story.kind(ui.session.story, ordinal)
		check(ui.board.puzzle.ruleset == ("classic-1" if kind == "classic" else Rules.VERSION), "stage ruleset")
		if kind != "classic":
			check("Directo" not in ui.mode_status.text and "Reflexivo" not in ui.mode_status.text, "no classical difficulty claimed")
		if ordinal == 12:
			ui.board.warnings_enabled = true
			check("simples" in ui.mode_status.text, "blue rule visible in game")
			check("S: 0 → 1 → 0" in ui.gesture_hint.text, "blue gesture hint matches actual cycle")
			var blue: Dictionary = {}
			for item in ui.board.puzzle.islands:
				if item.variant == "blue":
					blue = item
			var original_bridges: Dictionary = ui.board.puzzle.bridges.duplicate(true)
			var incident: Array = []
			for candidate in Classic.candidate_edges(ui.board.puzzle):
				if candidate.a == blue.id or candidate.b == blue.id:
					incident.append(ui.board.puzzle.key(candidate.a, candidate.b))
			for edge in incident:
				ui.board.puzzle.bridges[edge] = 2
			check(ui.board.island_fill(blue) == Color("a33e51"), "blue excess remains visibly warned")
			ui.board.puzzle.bridges = original_bridges
			var edges := Classic.candidate_edges(ui.board.puzzle)
			for edge in edges:
				if edge.a == blue.id or edge.b == blue.id:
					ui.board._connect_islands(edge.a, edge.b)
					check(ui.board.puzzle.bridge_count(edge.a, edge.b) == 1, "blue touch adds single")
					ui.board._connect_islands(edge.a, edge.b)
					check(ui.board.puzzle.bridge_count(edge.a, edge.b) == 0, "blue touch removes instead of double")
					break
		if ordinal == 16:
			check("sin número" in ui.mode_status.text, "mystery rule visible")
			check("Puentes: 0 → 1 → 2 → 0" in ui.gesture_hint.text, "mystery retains ordinary cycle hint")
			ui.board.warnings_enabled = true
			for item in ui.board.puzzle.islands:
				if item.variant == "mystery":
					check(ui.board.island_fill(item) == Color("554478"), "empty mystery has no target feedback")
		if ordinal == 20:
			check("simples" in ui.mode_status.text and "sin número" in ui.mode_status.text, "combined legend visible")
		await solve_ui(ui)
		check(ui.session.story.frontier == ordinal + 1, "victory unlock once")
		if ordinal in [12, 16, 20, 24]:
			var before: Dictionary = ui.session.snapshot_data()
			var store := Store.new(ui.save_path)
			check(store.load_game(tutorials).story == before.story, "variant snapshot roundtrip")
			ui.board.undo()
			await settle(ui)
			ui.board.redo()
			await settle(ui)
			check(ui.session.story.frontier == ordinal + 1, "undo redo no duplicate unlock")
	var old: Dictionary = ui.session.snapshot_data()
	old.version = 4
	old.erase("quality")
	old.erase("story_attempts")
	old.story = {"version": 1, "policy": Policy.VERSION, "frontier": 0, "recipes": {}}
	old.procedural = {}
	old.boards = {str(tutorials[0].id): {}}
	old.current_puzzle_id = str(tutorials[0].id)
	old.completed_ids = []
	var file := FileAccess.open(ui.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old)); file.close()
	var bytes := FileAccess.get_file_as_string(ui.save_path)
	var restored := Session.new(tutorials, ui.save_path)
	check(restored.restore() and restored.story.variant_from == 12, "v4 route migration")
	check(FileAccess.get_file_as_string(ui.save_path) == bytes, "migration never rewrites on open")
	for frontier in [12, 13, 20, 27]:
		var migrated := Story.migrate({"version": 1, "policy": Policy.VERSION, "frontier": frontier, "recipes": {}})
		check(migrated.variant_from > frontier and int(migrated.variant_from) % 4 == 0, "strict next stage boundary")
	ui.queue_free()
	await process_frame
