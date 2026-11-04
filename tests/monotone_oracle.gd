extends SceneTree
## Independent complete finite graph enumeration; no production geometry or rule helpers.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Adjudicator = preload("res://scripts/hashi_extension_judge.gd")
var checks := 0
var failures := 0
var cases := 0
var outcomes := {"viable": 0, "impossible": 0}
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures <= 20:
			printerr("MONOTONE ORACLE FAIL: ", label)
func assignments(count: int, edges: Array, crossings: Array, blue: Array, connected: bool) -> Array:
	var result: Array = []
	var combinations := int(pow(3, edges.size()))
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
			if value == 2 and (edge[0] in blue or edge[1] in blue):
				allowed = false
			degree[edge[0]] += value
			degree[edge[1]] += value
		for pair in crossings:
			if values[pair[0]] > 0 and values[pair[1]] > 0:
				allowed = false
		if not allowed:
			continue
		if connected:
			var seen := {0: true}
			var pending := [0]
			while not pending.is_empty():
				var node: int = pending.pop_back()
				for e in edges.size():
					if values[e] == 0 or node not in edges[e]:
						continue
					var other: int = edges[e][1] if node == edges[e][0] else edges[e][0]
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
func group(points: Array, edges: Array, crossing: Array, types: Array) -> void:
	var blue: Array = []
	for i in types.size():
		if types[i] == "blue":
			blue.append(i)
	var complete := assignments(points.size(), edges, crossing, blue, true)
	var partials := assignments(points.size(), edges, crossing, blue, false)
	var clues := {}
	for value in complete:
		var targets: Array = value.degree.duplicate()
		for i in types.size():
			if types[i] == "mystery":
				targets[i] = 0
		clues[JSON.stringify(targets)] = targets
	for targets in clues.values():
		var solutions: Array = []
		for value in complete:
			var matches := true
			for i in types.size():
				if types[i] != "mystery" and value.degree[i] != targets[i]:
					matches = false
			if matches:
				solutions.append(value.bridges)
		var islands: Array = []
		for i in types.size():
			islands.append({"id": "n%d" % i, "x": points[i][0], "y": points[i][1], "target": targets[i], "variant": types[i], "color": "neutral" if types[i] == "classic" else types[i]})
		var classic := true
		for kind in types:
			classic = classic and kind == "classic"
		var definition := {"id": "oracle", "title": "Oracle", "islands": islands}
		if not classic:
			definition.ruleset = "visible-variants-1"
		for partial in partials:
			# Larger graph: retain deterministic diverse subset plus empty/single-edge states.
			if edges.size() > 4 and partial.bridges.size() > 1 and JSON.stringify(partial.bridges).hash() % 17 != 0:
				continue
			var expected := "impossible"
			for solution in solutions:
				var extends_partial := true
				for edge in partial.bridges:
					if int(solution.get(edge, 0)) < int(partial.bridges[edge]):
						extends_partial = false
				if extends_partial:
					expected = "viable"
					break
			var puzzle := Puzzle.new(definition)
			puzzle.bridges = partial.bridges.duplicate(true)
			var before := puzzle.bridges.duplicate(true)
			var result: Dictionary = Adjudicator.new().judge(puzzle, {"max_nodes": 1000000, "max_time_ms": 1000})
			cases += 1
			outcomes[expected] += 1
			check(result.status == expected, "%d expected %s got %s %s %s" % [cases, expected, result.status, targets, partial.bridges])
			check(puzzle.bridges == before, "adjudication does not mutate editing state")
func run() -> void:
	var square := [[0, 0], [2, 0], [0, 2], [2, 2]]
	var edges := [[0, 1], [0, 2], [1, 3], [2, 3]]
	group(square, edges, [], ["classic", "classic", "classic", "classic"])
	group(square, edges, [], ["blue", "classic", "classic", "classic"])
	group(square, edges, [], ["classic", "mystery", "classic", "classic"])
	group(square, edges, [], ["blue", "mystery", "classic", "classic"])
	group([[0, 0], [1, 0], [0, 1], [2, 1], [1, 2], [2, 2]], [[0, 1], [0, 2], [2, 3], [1, 4], [3, 5], [4, 5]], [[2, 3]], ["blue", "classic", "classic", "classic", "classic", "mystery"])
	check(outcomes.viable > 0 and outcomes.impossible > 0, "both outcomes exercised")
	print("MONOTONE ORACLE: ", cases, " partials; ", checks, " checks, ", failures, " failures; ", outcomes)
	quit(1 if failures else 0)
