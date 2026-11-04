extends SceneTree
## Independent finite graph enumeration: no production rules or candidate-edge builder.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Solver = preload("res://scripts/hashi_variant_solver.gd")
var checks := 0
var failures := 0
var cases := 0
var status_counts := {"none": 0, "unique": 0, "multiple": 0}
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("VARIANT ORACLE FAIL: ", label)
func physical_assignments(count: int, edges: Array, crossing_pairs: Array, blues: Array) -> Array:
	var result: Array = []
	var combinations := 1
	for e in edges.size():
		combinations *= 3
	for mask in combinations:
		var remainder := mask
		var values: Array = []
		var degree: Array = []
		degree.resize(count)
		degree.fill(0)
		var allowed := true
		for edge in edges:
			var value := remainder % 3
			remainder = int(remainder / 3)
			values.append(value)
			if value == 2 and (edge[0] in blues or edge[1] in blues):
				allowed = false
			degree[edge[0]] += value
			degree[edge[1]] += value
		for crossing in crossing_pairs:
			if values[crossing[0]] > 0 and values[crossing[1]] > 0:
				allowed = false
		if not allowed:
			continue
		var seen := {0: true}
		var pending := [0]
		while not pending.is_empty():
			var current: int = pending.pop_back()
			for e in edges.size():
				if values[e] == 0 or current not in edges[e]:
					continue
				var other: int = edges[e][1] if edges[e][0] == current else edges[e][0]
				if not seen.has(other):
					seen[other] = true
					pending.append(other)
		if seen.size() != count:
			continue
		var bridges := {}
		for e in edges.size():
			if values[e] > 0:
				bridges["n%d:n%d" % [edges[e][0], edges[e][1]]] = values[e]
		result.append({"degree": degree, "bridges": bridges})
	return result
func definition(points: Array, types: Array, targets: Array) -> Dictionary:
	var islands: Array = []
	for i in points.size():
		islands.append({"id": "n%d" % i, "x": points[i][0], "y": points[i][1], "target": targets[i], "variant": types[i], "color": "neutral" if types[i] == "classic" else types[i]})
	return {"id": "oracle-%d" % cases, "title": "Oracle", "ruleset": "visible-variants-1", "islands": islands}
func compare(points: Array, types: Array, targets: Array, physical: Array) -> void:
	cases += 1
	var expected: Array = []
	for assignment in physical:
		var matches := true
		for i in types.size():
			if types[i] != "mystery" and assignment.degree[i] != targets[i]:
				matches = false
		if matches:
			expected.append(assignment.bridges)
	var expected_status := "none" if expected.is_empty() else ("unique" if expected.size() == 1 else "multiple")
	status_counts[expected_status] += 1
	var puzzle := Puzzle.new(definition(points, types, targets))
	var result := Solver.new().solve(puzzle, {"max_time_ms": 3000, "max_nodes": 1000000})
	check(result.status == expected_status, "status case %d expected %s got %s" % [cases, expected_status, result.status])
	check(result.solutions.size() == mini(2, expected.size()), "solution count case " + str(cases))
	for witness in result.solutions:
		check(witness in expected, "witness belongs to independently enumerated set")
func run() -> void:
	var square := [[0, 0], [2, 0], [0, 2], [2, 2]]
	var square_physical := physical_assignments(4, [[0, 1], [0, 2], [1, 3], [2, 3]], [], [0])
	for code in 32:
		compare(square, ["blue", "mystery", "classic", "classic"], [1 + code % 2, 0, 1 + int(code / 2) % 4, 1 + int(code / 8) % 4], square_physical)
	# The two middle connections cross; two exterior corners connect the halves.
	var crossed := [[0, 0], [1, 0], [0, 1], [2, 1], [1, 2], [2, 2]]
	var cross_physical := physical_assignments(6, [[0, 1], [0, 2], [2, 3], [1, 4], [3, 5], [4, 5]], [[2, 3]], [0])
	for code in 256:
		compare(crossed, ["blue", "classic", "classic", "classic", "classic", "mystery"], [2, 1 + code % 4, 1 + int(code / 4) % 4, 1 + int(code / 16) % 4, 1 + int(code / 64) % 4, 0], cross_physical)
	var pair := [[0, 0], [1, 0]]
	compare(pair, ["mystery", "mystery"], [0, 0], physical_assignments(2, [[0, 1]], [], []))
	compare(pair, ["blue", "mystery"], [1, 0], physical_assignments(2, [[0, 1]], [], [0]))
	compare(pair, ["blue", "mystery"], [2, 0], physical_assignments(2, [[0, 1]], [], [0]))
	for outcome in status_counts:
		check(status_counts[outcome] > 0, "oracle exercises " + outcome)
	var invalid := definition(pair, ["blue", "mystery"], [1, 7])
	check(Solver.new().solve(Puzzle.new(invalid)).status == "invalid", "nonzero hidden number rejected instead of used")
	print("VARIANT ORACLE: ", cases, " visible clue cases; ", checks, " checks, ", failures, " failures; ", status_counts)
	quit(1 if failures else 0)
