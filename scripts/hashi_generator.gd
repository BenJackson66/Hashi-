class_name HashiGenerator
extends RefCounted
## Deterministic, bounded rejection sampling. No Node, SceneTree or file access.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const ALGORITHM_VERSION := "h02b-1"
var _random_state: int

func _random(limit: int) -> int:
	# Park–Miller: products fit in signed 64 bits; independent of engine RNG changes.
	_random_state = (_random_state * 48271) % 2147483647
	return _random_state % limit

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _random(i + 1)
		var item: Variant = items[i]
		items[i] = items[j]
		items[j] = item

func generate(seed_value: int, options: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	var settings := {"width": 5, "height": 5, "island_count": 10, "max_attempts": 100,
		"max_time_ms": 1500, "solver_max_nodes": 100000}
	for name in options:
		if not settings.has(name) or not options[name] is int:
			return _failure("invalid_options", 0, started)
		settings[name] = options[name]
	if settings.width < 1 or settings.width > 16 or settings.height < 1 or settings.height > 16 or settings.island_count < 2 or settings.island_count > Solver.MAX_ISLANDS or settings.island_count > settings.width * settings.height or settings.max_attempts < 0 or settings.max_attempts > 10000 or settings.max_time_ms < 0 or settings.max_time_ms > 60000 or settings.solver_max_nodes < 0 or settings.solver_max_nodes > 1000000:
		return _failure("invalid_options", 0, started)
	var deadline: int = started + settings.max_time_ms * 1000
	_random_state = posmod(seed_value, 2147483646) + 1
	for attempt in settings.max_attempts:
		if Time.get_ticks_usec() >= deadline:
			return _failure("time_limit", attempt, started)
		var candidate := _candidate(settings, deadline)
		if Time.get_ticks_usec() >= deadline:
			return _failure("time_limit", attempt + 1, started)
		if candidate.is_empty():
			continue
		var remaining_ms := int((deadline - Time.get_ticks_usec()) / 1000)
		if remaining_ms <= 0:
			return _failure("time_limit", attempt + 1, started)
		var puzzle := Puzzle.new(candidate.puzzle)
		var solved := Solver.new().solve(puzzle, {"max_time_ms": remaining_ms, "max_nodes": settings.solver_max_nodes})
		if solved.status == "incomplete":
			# Never skip a timed-out candidate: a faster machine could accept it.
			return _failure("solver_" + str(solved.reason), attempt + 1, started)
		if Time.get_ticks_usec() >= deadline:
			return _failure("time_limit", attempt + 1, started)
		if solved.status not in ["unique", "multiple"]:
			return _failure("solver_inconsistent", attempt + 1, started)
		if solved.status == "unique":
			if solved.solutions[0] != candidate.solution:
				return _failure("solution_mismatch", attempt + 1, started)
			var data: Dictionary = candidate.puzzle
			data.id = "procedural-%s-%d-%dx%d-%d" % [ALGORITHM_VERSION, seed_value, settings.width, settings.height, settings.island_count]
			return {"status": "success", "algorithm_version": ALGORITHM_VERSION, "seed": seed_value,
				"parameters": settings, "attempts": attempt + 1, "puzzle": data,
				"solution": solved.solutions[0], "construction_solution": candidate.solution,
				"uniqueness": solved.status, "metrics": solved.metrics,
				"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
	return _failure("attempt_limit", settings.max_attempts, started)

func _candidate(settings: Dictionary, deadline: int) -> Dictionary:
	var points: Array = []
	for y in settings.height:
		for x in settings.width:
			points.append(Vector2i(x, y))
	_shuffle(points)
	points.resize(settings.island_count)
	# Stable row-major order for IDs and solver tie breaking.
	points.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var data := {"id": "candidate", "title": "Hashi procedural", "islands": []}
	for i in points.size():
		data.islands.append({"id": "i%02d" % i, "x": points[i].x, "y": points[i].y,
			"target": 1, "variant": "classic", "color": "neutral"})
	var puzzle := Puzzle.new(data)
	var edges := Solver.candidate_edges(puzzle, deadline)
	_shuffle(edges)
	var components: Array = []
	for i in points.size():
		components.append(i)
	# Random noncrossing spanning tree. Unconnectable layouts are rejected.
	for edge in edges:
		if Time.get_ticks_usec() >= deadline:
			return {}
		if components[edge.i] == components[edge.j]:
			continue
		if not Rules.move_error(puzzle, edge.a, edge.b, 1).is_empty():
			continue
		var old: int = components[edge.j]
		var replacement: int = components[edge.i]
		for i in components.size():
			if components[i] == old:
				components[i] = replacement
		puzzle.bridges[puzzle.key(edge.a, edge.b)] = 1 + _random(2)
	if not Rules.network_connected(puzzle):
		return {}
	# Additional edges introduce cycles without changing the classic constraints.
	for edge in edges:
		if Time.get_ticks_usec() >= deadline:
			return {}
		if puzzle.bridge_count(edge.a, edge.b) == 0 and _random(3) == 0:
			var count := 1 + _random(2)
			if Rules.move_error(puzzle, edge.a, edge.b, count).is_empty():
				puzzle.bridges[puzzle.key(edge.a, edge.b)] = count
	for item in puzzle.islands:
		item.target = puzzle.degree(str(item.id))
	data.islands = puzzle.islands.duplicate(true)
	if not Rules.is_solved(puzzle):
		return {}
	return {"puzzle": data, "solution": puzzle.bridges.duplicate(true)}

func _failure(reason: String, attempts: int, started: int) -> Dictionary:
	return {"status": "failure", "reason": reason, "algorithm_version": ALGORITHM_VERSION,
		"attempts": attempts, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
