extends SceneTree
const Generator = preload("res://scripts/hashi_generator.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL IDENTITY: ", label)

func run() -> void:
	check(Generator.ALGORITHM_VERSION == "h02b-1", "generation algorithm unchanged")
	check(Generator.IDENTITY_SCHEMA_VERSION == 1, "identity schema independently versioned")
	check(Generator.CONTENT_DEFAULTS.keys() == ["width", "height", "island_count"], "current content options explicitly classified")
	check(Generator.BUDGET_DEFAULTS.keys() == ["max_attempts", "max_time_ms", "solver_max_nodes"], "current budget options explicitly classified")
	for name in Generator.CONTENT_DEFAULTS:
		check(not Generator.BUDGET_DEFAULTS.has(name), "content and budget groups disjoint")
	var base := Generator.new().generate(42)
	check(base.status == "success", "baseline generated")
	if base.status != "success":
		quit(1)
		return
	var baseline_id: String = base.puzzle.id
	check(baseline_id == "procedural-id1-h02b-1-9ee1b9751911fc0d573e5aeaf302ca14761da348383407495e46210a0788f362", "identity schema golden seed 42")
	check(baseline_id.begins_with("procedural-id1-h02b-1-") and baseline_id.length() == "procedural-id1-h02b-1-".length() + 64, "versioned SHA-256 format")
	check(JSON.stringify(base.puzzle.islands).sha256_text() == "5373b187791245ed93bc0d5d93f6bf5fd143413c6cd08bd1d2c76e67acb59aff", "old seed 42 golden clues unchanged")
	check(base.attempts == 4, "old number of attempts unchanged")
	var explicit := Generator.CONTENT_DEFAULTS.duplicate(true)
	explicit.merge(Generator.BUDGET_DEFAULTS)
	var permutations := [{}, explicit, {"island_count": 10, "height": 5, "width": 5},
		{"max_attempts": 300}, {"max_time_ms": 5000}, {"solver_max_nodes": 200000},
		{"solver_max_nodes": 200000, "height": 5, "max_time_ms": 5000, "width": 5, "max_attempts": 300, "island_count": 10}]
	for options in permutations:
		var generated := Generator.new().generate(42, options)
		check(generated.status == "success", "equivalent configuration completes")
		if generated.status == "success":
			check(generated.puzzle == base.puzzle, "defaults, key order and budgets preserve identity and clues")
			check(generated.solution == base.solution and generated.construction_solution == base.construction_solution and generated.attempts == base.attempts, "existing generation results preserved")
	var ids := {baseline_id: true}
	for content in [{"width": 6, "height": 5, "island_count": 10}, {"width": 5, "height": 6, "island_count": 10}, {"width": 5, "height": 5, "island_count": 11}]:
		var options: Dictionary = content.duplicate()
		options.max_time_ms = 5000
		options.max_attempts = 300
		var generated := Generator.new().generate(42, options)
		check(generated.status == "success", "changed content configuration completes")
		if generated.status == "success":
			check(not ids.has(generated.puzzle.id), "different content configurations have different IDs")
			ids[generated.puzzle.id] = true
	var next_seed := Generator.new().generate(43)
	check(next_seed.status == "success" and next_seed.puzzle.id != baseline_id, "seed part of identity")
	var normalized_alias := Generator.new().generate(42 + 2147483646)
	check(normalized_alias.status == "success", "PRNG-alias seed generates")
	if normalized_alias.status == "success":
		check(normalized_alias.puzzle.islands == base.puzzle.islands and normalized_alias.solution == base.solution, "PRNG normalization remains unchanged")
		check(normalized_alias.puzzle.id != baseline_id, "original seed remains part of recipe identity")
	var content := Generator.CONTENT_DEFAULTS.duplicate()
	var clues: Array = base.puzzle.islands.duplicate(true)
	check(Generator.puzzle_identity(42, content, clues) == baseline_id, "descriptor recomputes emitted identity")
	var reordered: Array = clues.duplicate(true)
	reordered.reverse()
	check(Generator.puzzle_identity(42, {"island_count": 10, "height": 5, "width": 5}, reordered) == baseline_id, "canonical ordering of options and islands")
	check(clues == base.puzzle.islands and reordered[0] == clues.back(), "identity computation does not mutate input")
	var changed := clues.duplicate(true)
	changed[0].target += 1
	check(Generator.puzzle_identity(42, content, changed) != baseline_id, "different clue cannot share recipe identity")
	changed = clues.duplicate(true)
	changed[0].x += 1
	check(Generator.puzzle_identity(42, content, changed) != baseline_id, "different position changes identity")
	changed = clues.duplicate(true)
	changed[0].variant = "future-variant"
	check(Generator.puzzle_identity(42, content, changed) != baseline_id, "island rule metadata included without implementing a variant")
	# Identity supports every declared content parameter, not a positional field list.
	var future_a := content.duplicate()
	future_a["future_content_option"] = {"a": 1, "b": 2}
	var future_b := content.duplicate()
	future_b["future_content_option"] = {"b": 2, "a": 1}
	check(Generator.puzzle_identity(42, future_a, clues) == Generator.puzzle_identity(42, future_b, clues), "nested content serialization canonical")
	check(Generator.puzzle_identity(42, future_a, clues) != baseline_id, "additional content option is not omitted from identity")
	future_b.future_content_option.a = 2
	check(Generator.puzzle_identity(42, future_a, clues) != Generator.puzzle_identity(42, future_b, clues), "future content parameter values distinguished")
	future_a.future_content_option = 1.0000000000000002
	future_b.future_content_option = 1.0000000000000004
	check(Generator.puzzle_identity(42, future_a, clues) != Generator.puzzle_identity(42, future_b, clues), "full precision for future numeric content options")
	check(Generator.new().generate(42, {"future_content_option": 1}).reason == "invalid_options", "unclassified options remain rejected")
	for options in [{"max_attempts": 1}, {"max_time_ms": 0}, {"solver_max_nodes": 0}]:
		var failed := Generator.new().generate(42, options)
		check(failed.status == "failure" and not failed.has("puzzle"), "insufficient budget cannot issue another board identity")
	print("IDENTITY RESULT: ", checks, " checks, ", failures, " failures")
	print("IDENTITY GOLDEN: ", baseline_id)
	quit(1 if failures else 0)
