extends SceneTree
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const Generator = preload("res://scripts/hashi_generator.gd")
var checks := 0
var failures := 0
var reference_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL H02B: ", label)

func make(points: Array, targets: Array) -> Puzzle:
	var islands: Array = []
	for i in points.size():
		islands.append({"id": str(i), "x": points[i][0], "y": points[i][1], "target": targets[i]})
	return Puzzle.new({"id": "test", "islands": islands})

func oracle(puzzle: Puzzle, edges: Array, index: int) -> void:
	if reference_count >= 2:
		return
	for item in puzzle.islands:
		var id := str(item.id)
		var remaining := 0
		for k in range(index, edges.size()):
			if id in edges[k]:
				remaining += 2
		if puzzle.degree(id) > item.target or puzzle.degree(id) + remaining < item.target:
			return
	if index == edges.size():
		if Rules.is_solved(puzzle):
			reference_count += 1
		return
	var a: String = edges[index][0]
	var b: String = edges[index][1]
	for value in [0, 1, 2]:
		if not Rules.move_error(puzzle, a, b, value).is_empty():
			continue
		if value == 0:
			puzzle.bridges.erase(puzzle.key(a, b))
		else:
			puzzle.bridges[puzzle.key(a, b)] = value
		oracle(puzzle, edges, index + 1)
	puzzle.bridges.erase(puzzle.key(a, b))

func run() -> void:
	var started := Time.get_ticks_usec()
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles.json"))
	for data in catalog:
		var puzzle := Puzzle.new(data)
		puzzle.bridges = {"input-state-is-not-a-clue": 99}
		var before := puzzle.bridges.duplicate()
		var result := Solver.new().solve(puzzle)
		check(result.status == "unique", "existing puzzle unique " + str(data.id))
		check(puzzle.bridges == before, "solver does not mutate input")
		if result.status == "unique":
			var witness := Puzzle.new(data)
			witness.bridges = result.solutions[0]
			check(Rules.is_solved(witness), "solution respects existing rules")
	var square := [[0, 0], [2, 0], [0, 2], [2, 2]]
	var multiple := Solver.new().solve(make(square, [3, 3, 3, 3]))
	check(multiple.status == "multiple" and multiple.solution_count == 2 and multiple.count_capped, "stop after two solutions")
	check(multiple.metrics.assumptions > 0, "assumptions measured")
	check(Solver.new().solve(make(square, [1, 1, 1, 1])).status == "none", "disconnected complete degrees cannot solve")
	check(Solver.new().solve(make([[0, 0], [1, 0]], [1, 2])).status == "none", "unsatisfiable degrees")
	check(Solver.new().solve(make([[0, 0]], [1])).status == "none", "isolated island")
	var cross := make([[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [1, 2]], [2, 3, 2, 3, 3, 1])
	check(Solver.new().solve(cross).status == "none", "forced crossing rejected even with potential connectivity")
	check(Solver.new().solve(make(square, [2, 2, 2, 2])).status == "unique", "connectivity removes disconnected alternatives")
	check(Solver.new().solve(make([[0, 0], [1, 0], [2, 0]], [2, 4, 2])).status == "unique", "neighbor detection cannot pass through islands")
	for invalid in [null, Puzzle.new(), make([[0, 0], [0, 0]], [1, 1]), make(square, [9, 1, 1, 1]), make(square, [0, 1, 1, 1]), make(square, [1.5, 1, 1, 1]), Puzzle.new({"islands": [3]}), Puzzle.new({"islands": [{"id": "x", "x": "bad", "y": 0, "target": 1}]})]:
		check(Solver.new().solve(invalid).status == "invalid", "invalid definitions rejected safely")
	var variant := make([[0, 0], [1, 0]], [1, 1])
	variant.islands[0].variant = "future-rule"
	check(Solver.new().solve(variant).status == "invalid", "unsupported variants never silently solved as classic")
	var cutoff := Solver.new().solve(make(square, [3, 3, 3, 3]), {"max_nodes": 0})
	check(cutoff.status == "incomplete" and cutoff.reason == "node_limit", "node budget is not no-solution")
	var partial := Solver.new().solve(make(square, [3, 3, 3, 3]), {"max_nodes": 2})
	check(partial.status == "incomplete" and partial.solution_count == 1, "one witness without exhausted search is not uniqueness")
	check(Solver.new().solve(make(square, [3, 3, 3, 3]), {"max_time_ms": 0}).status == "incomplete", "zero deadline terminates")
	check(Solver.new().solve(make(square, [3, 3, 3, 3]), {"max_nodes": -1}).status == "invalid", "negative budgets rejected")
	# Independent exhaustive reference, with no propagation/domains shared with solver.
	for a in range(1, 5):
		for b in range(1, 5):
			for c in range(1, 5):
				for d in range(1, 5):
					var puzzle := make(square, [a, b, c, d])
					reference_count = 0
					oracle(puzzle, [["0", "1"], ["0", "2"], ["1", "3"], ["2", "3"]], 0)
					var solved := Solver.new().solve(puzzle)
					check(solved.solution_count == reference_count and solved.status in ["none", "unique", "multiple"], "reference enumeration " + str([a, b, c, d]))
	# Cross-shaped graph: compare a second topology with an independent oracle.
	for index in range(64):
		var targets: Array = []
		for i in range(6):
			targets.append(1 + ((index >> i) & 1))
		var puzzle := make([[0, 0], [1, 0], [2, 0], [0, 1], [2, 1], [1, 2]], targets)
		reference_count = 0
		oracle(puzzle, [["0", "1"], ["0", "3"], ["1", "2"], ["1", "5"], ["2", "4"], ["3", "4"]], 0)
		var solved := Solver.new().solve(puzzle)
		check(solved.solution_count == reference_count and solved.status in ["none", "unique", "multiple"], "cross topology reference " + str(index))
	var dense_points: Array = []
	var dense_targets: Array = []
	for y in range(8):
		for x in range(8):
			dense_points.append([x, y])
			dense_targets.append(1)
	var timed := Solver.new().solve(make(dense_points, dense_targets), {"max_time_ms": 1})
	check(timed.status == "incomplete" and timed.reason == "time_limit", "positive deadline bounds hard search")
	check(timed.metrics.elapsed_ms < 250, "deadline overshoot bounded on available executor")
	var options := {"width": 5, "height": 5, "island_count": 10, "max_time_ms": 5000}
	var first := Generator.new().generate(42, options)
	var second := Generator.new().generate(42, options)
	check(first.status == "success" and second.status == "success", "known seed generates")
	if first.status == "success" and second.status == "success":
		check(first.puzzle == second.puzzle and first.solution == second.solution and first.attempts == second.attempts, "same seed gives same board")
		check(JSON.stringify(first.puzzle.islands).sha256_text() == "5373b187791245ed93bc0d5d93f6bf5fd143413c6cd08bd1d2c76e67acb59aff", "algorithm v1 golden seed 42")
		check(first.algorithm_version == Generator.ALGORITHM_VERSION, "algorithm version recorded")
	var signatures := {}
	for dimensions in [[1, 8, 6], [8, 1, 6], [4, 4, 8], [5, 6, 12], [7, 5, 14]]:
		for seed_value in [1, 42, 2026]:
			var result := Generator.new().generate(seed_value, {"width": dimensions[0], "height": dimensions[1], "island_count": dimensions[2], "max_time_ms": 5000, "max_attempts": 300})
			check(result.status == "success", "generation " + str([dimensions, seed_value]) + " " + str(result.get("reason", "")))
			if result.status != "success":
				continue
			var puzzle := Puzzle.new(result.puzzle)
			check(puzzle.islands.size() == dimensions[2], "requested island count")
			check(puzzle.bridges.is_empty(), "playable definition has no preplaced bridges")
			for item in puzzle.islands:
				check(item.x >= 0 and item.x < dimensions[0] and item.y >= 0 and item.y < dimensions[1], "coordinates inside dimensions")
			puzzle.bridges = result.construction_solution
			check(Rules.is_solved(puzzle), "construction solution valid")
			check(result.solution == result.construction_solution, "unique solution equals constructed witness")
			var independently := Solver.new().solve(Puzzle.new(result.puzzle), {"max_time_ms": 5000})
			check(independently.status == "unique", "fresh uniqueness check")
			check(result.metrics.forced_decisions >= 0 and result.metrics.double_bridge_ratio >= 0 and result.metrics.double_bridge_ratio <= 1, "experimental metrics bounded")
			signatures[JSON.stringify(result.puzzle.islands)] = true
	var reused := Generator.new()
	var negative := reused.generate(-7, options)
	reused.generate(999, options)
	var negative_again := reused.generate(-7, options)
	check(negative.status == "success" and negative_again.status == "success" and negative.puzzle == negative_again.puzzle, "negative seed and reused generator reset PRNG")
	check(signatures.size() > 5, "seeds and dimensions yield varied boards")
	var exhausted := Generator.new().generate(42, {"max_attempts": 1})
	check(exhausted.status == "failure" and exhausted.reason == "attempt_limit" and exhausted.attempts == 1, "positive attempt budget exhausted")
	var timed_generation := Generator.new().generate(42, {"width": 16, "height": 16, "island_count": 64, "max_time_ms": 1})
	check(timed_generation.status == "failure" and timed_generation.reason in ["time_limit", "solver_time_limit"], "positive generator deadline terminates")
	check(timed_generation.elapsed_ms < 250, "generator deadline bounded on executor")
	check(Generator.new().generate(1, {"max_attempts": 0}).reason == "attempt_limit", "attempt exhaustion reported")
	check(Generator.new().generate(1, {"max_time_ms": 0}).reason == "time_limit", "generation deadline terminates")
	check(Generator.new().generate(42, {"width": 1, "height": 2, "island_count": 2, "solver_max_nodes": 0}).reason == "solver_node_limit", "unproven uniqueness cannot be accepted")
	for bad_options in [{"width": 0}, {"height": 17}, {"island_count": 65}, {"width": 1, "height": 1, "island_count": 2}, {"max_time_ms": -1}, {"width": "5"}, {"unknown": 1}]:
		check(Generator.new().generate(1, bad_options).reason == "invalid_options", "invalid generation bounds")
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	check(elapsed_ms < 20000, "suite terminates within generous 20s watchdog")
	print("H02B RESULT: ", checks, " checks, ", failures, " failures; elapsed_ms=", elapsed_ms)
	quit(1 if failures else 0)
