class_name HashiSolver
extends RefCounted
## Bounded classic Hashi search. Input bridges are ignored: solve the definition.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const MAX_ISLANDS := 64
var _puzzle: Puzzle
var _edges: Array = []
var _incident: Array = []
var _crossings: Array = []
var _solutions: Array = []
var _stats: Dictionary
var _deadline: int
var _node_limit: int
var _stop_reason := ""

static func valid_input(puzzle: Puzzle) -> bool:
	if puzzle == null or puzzle.islands.is_empty() or puzzle.islands.size() > MAX_ISLANDS:
		return false
	for item in puzzle.islands:
		if not item is Dictionary or not item.has_all(["id", "x", "y", "target"]):
			return false
		if not item.id is String or str(item.get("variant", "classic")) != "classic":
			return false
		for field in ["x", "y", "target"]:
			if not (item[field] is int or item[field] is float) or not is_finite(float(item[field])):
				return false
		var point := Rules.position(item)
		if not point.is_finite():
			return false
	return Rules.valid_definition(puzzle)

static func candidate_edges(puzzle: Puzzle, deadline_usec: int = 0) -> Array:
	var edges: Array = []
	for i in puzzle.islands.size():
		if deadline_usec > 0 and Time.get_ticks_usec() >= deadline_usec:
			return []
		for j in range(i + 1, puzzle.islands.size()):
			var a := str(puzzle.islands[i].id)
			var b := str(puzzle.islands[j].id)
			if Rules.aligned_neighbors(puzzle, a, b):
				edges.append({"a": a, "b": b, "i": i, "j": j})
	return edges

static func edge_crosses(puzzle: Puzzle, first: Dictionary, second: Dictionary) -> bool:
	return Rules.crosses(Rules.position(puzzle.islands[first.i]), Rules.position(puzzle.islands[first.j]),
		Rules.position(puzzle.islands[second.i]), Rules.position(puzzle.islands[second.j]))

func solve(puzzle: Puzzle, limits: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	_solutions = []
	_stop_reason = ""
	_stats = {"islands": 0, "possible_connections": 0, "forced_decisions": 0,
		"assumptions": 0, "backtracks": 0, "search_nodes": 0, "max_depth": 0,
		"double_bridge_ratio": 0.0}
	if puzzle != null and puzzle.islands.size() > MAX_ISLANDS:
		return _result("invalid", "island_limit", started)
	if not valid_input(puzzle):
		return _result("invalid", "invalid_definition", started)
	var time_ms: Variant = limits.get("max_time_ms", 1000)
	var nodes: Variant = limits.get("max_nodes", 100000)
	if not time_ms is int or not nodes is int or time_ms < 0 or time_ms > 60000 or nodes < 0 or nodes > 1000000:
		return _result("invalid", "invalid_limits", started)
	_deadline = started + time_ms * 1000
	_node_limit = nodes
	_puzzle = Puzzle.new({"id": puzzle.puzzle_id, "islands": puzzle.islands})
	_stats.islands = _puzzle.islands.size()
	if _expired():
		return _result("incomplete", _stop_reason, started)
	_edges = candidate_edges(_puzzle, _deadline)
	if _expired():
		return _result("incomplete", _stop_reason, started)
	_stats.possible_connections = _edges.size()
	_incident = []
	_crossings = []
	for i in _puzzle.islands.size():
		_incident.append([])
	for k in _edges.size():
		_incident[_edges[k].i].append(k)
		_incident[_edges[k].j].append(k)
		_crossings.append([])
	for k in _edges.size():
		if _expired():
			return _result("incomplete", _stop_reason, started)
		for j in range(k + 1, _edges.size()):
			if edge_crosses(_puzzle, _edges[k], _edges[j]):
				_crossings[k].append(j)
				_crossings[j].append(k)
	var domains: Array = []
	for edge in _edges:
		domains.append([0, 1, 2])
	_search(domains, 0)
	_expired()
	if _solutions.size() >= 2:
		return _result("multiple", "two_solutions_found", started)
	if not _stop_reason.is_empty():
		return _result("incomplete", _stop_reason, started)
	return _result("unique" if _solutions.size() == 1 else "none", "exhausted", started)

func _expired() -> bool:
	if Time.get_ticks_usec() >= _deadline:
		_stop_reason = "time_limit"
	return not _stop_reason.is_empty()

func _search(domains: Array, depth: int) -> void:
	if _solutions.size() >= 2 or _expired():
		return
	if _stats.search_nodes >= _node_limit:
		_stop_reason = "node_limit"
		return
	_stats.search_nodes += 1
	_stats.max_depth = maxi(_stats.max_depth, depth)
	if not _propagate(domains):
		return
	var selected := -1
	var smallest := 4
	for k in domains.size():
		if domains[k].size() > 1 and domains[k].size() < smallest:
			selected = k
			smallest = domains[k].size()
	if selected == -1:
		var witness := Puzzle.new({"id": _puzzle.puzzle_id, "islands": _puzzle.islands})
		for k in _edges.size():
			if domains[k][0] > 0:
				witness.bridges[witness.key(_edges[k].a, _edges[k].b)] = domains[k][0]
		if Rules.is_solved(witness):
			_solutions.append(witness.bridges.duplicate(true))
		return
	for value in domains[selected]:
		if _solutions.size() >= 2 or _expired():
			return
		_stats.assumptions += 1
		var before := _solutions.size()
		var child := domains.duplicate(true)
		child[selected] = [value]
		_search(child, depth + 1)
		if _stop_reason.is_empty() and _solutions.size() == before:
			_stats.backtracks += 1

func _propagate(domains: Array) -> bool:
	var changed := true
	while changed:
		if _expired():
			return false
		changed = false
		for i in _puzzle.islands.size():
			if _expired():
				return false
			var lower := 0
			var upper := 0
			for k in _incident[i]:
				if domains[k].is_empty():
					return false
				lower += int(domains[k].front())
				upper += int(domains[k].back())
			var target := int(_puzzle.islands[i].target)
			if target < lower or target > upper:
				return false
			for k in _incident[i]:
				var kept: Array = []
				for value in domains[k]:
					if value + lower - int(domains[k].front()) <= target and value + upper - int(domains[k].back()) >= target:
						kept.append(value)
				if kept.is_empty():
					return false
				if kept.size() != domains[k].size():
					if kept.size() == 1 and domains[k].size() > 1:
						_stats.forced_decisions += 1
					domains[k] = kept
					changed = true
		for k in domains.size():
			if int(domains[k].front()) > 0:
				for j in _crossings[k]:
					if not domains[j].has(0):
						return false
					if domains[j].size() > 1:
						domains[j] = [0]
						_stats.forced_decisions += 1
						changed = true
		if not _potentially_connected(domains):
			return false
	return true

func _potentially_connected(domains: Array) -> bool:
	var seen := {0: true}
	var pending: Array = [0]
	while not pending.is_empty():
		var i: int = pending.pop_back()
		for k in _incident[i]:
			if int(domains[k].back()) == 0:
				continue
			var j: int = _edges[k].j if _edges[k].i == i else _edges[k].i
			if not seen.has(j):
				seen[j] = true
				pending.append(j)
	return seen.size() == _puzzle.islands.size()

func _result(status: String, reason: String, started: int) -> Dictionary:
	if not _solutions.is_empty():
		var doubles := 0
		for count in _solutions[0].values():
			if count == 2:
				doubles += 1
		_stats.double_bridge_ratio = float(doubles) / maxf(1, _solutions[0].size())
	_stats.used_assumptions = _stats.assumptions > 0
	_stats.used_backtracking = _stats.backtracks > 0
	_stats.elapsed_ms = (Time.get_ticks_usec() - started) / 1000.0
	return {"status": status, "reason": reason, "solution_count": _solutions.size(),
		"count_capped": _solutions.size() == 2, "solutions": _solutions.duplicate(true),
		"metrics": _stats.duplicate(true)}
