class_name HashiExtensionJudge
extends RefCounted
## Private monotone completion adjudicator. Returns decisions, never witnesses.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const Geometry = preload("res://scripts/hashi_solver.gd")
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
	return puzzle != null and puzzle.islands.size() <= MAX_ISLANDS and Rules.valid_definition(puzzle)
static func candidate_edges(puzzle: Puzzle, deadline_usec: int = 0) -> Array:
	return Geometry.candidate_edges(puzzle, deadline_usec)
static func edge_crosses(puzzle: Puzzle, first: Dictionary, second: Dictionary) -> bool:
	return Geometry.edge_crosses(puzzle, first, second)

func judge(puzzle: Puzzle, limits: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	_solutions = []
	_stop_reason = ""
	_stats = {"islands": 0, "possible_connections": 0, "forced_decisions": 0,
		"assumptions": 0, "backtracks": 0, "search_nodes": 0, "max_depth": 0,
		"double_bridge_ratio": 0.0}
	if puzzle != null and puzzle.islands.size() > MAX_ISLANDS:
		return _result("invalid", "island_limit", started)
	if not valid_input(puzzle) or not _valid_lower_bounds(puzzle):
		return _result("invalid", "invalid_definition", started)
	var time_ms: Variant = limits.get("max_time_ms", 1000)
	var nodes: Variant = limits.get("max_nodes", 100000)
	if not time_ms is int or not nodes is int or time_ms < 0 or time_ms > 60000 or nodes < 0 or nodes > 1000000:
		return _result("invalid", "invalid_limits", started)
	_deadline = started + time_ms * 1000
	_node_limit = nodes
	_puzzle = Puzzle.new({"id": puzzle.puzzle_id, "islands": puzzle.islands, "ruleset": puzzle.ruleset})
	_stats.islands = _puzzle.islands.size()
	if _expired():
		return _result("indeterminate", _stop_reason, started)
	_edges = candidate_edges(_puzzle, _deadline)
	if _expired():
		return _result("indeterminate", _stop_reason, started)
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
			return _result("indeterminate", _stop_reason, started)
		for j in range(k + 1, _edges.size()):
			if edge_crosses(_puzzle, _edges[k], _edges[j]):
				_crossings[k].append(j)
				_crossings[j].append(k)
	var domains: Array = []
	for edge in _edges:
		var lower := puzzle.bridge_count(edge.a, edge.b)
		var domain: Array = []
		for value in range(lower, _capacity(puzzle, edge.a, edge.b) + 1):
			domain.append(value)
		domains.append(domain)
	_search(domains, 0)
	_expired()
	if _solutions.size() >= 1:
		return _result("viable", "extension_found", started)
	if not _stop_reason.is_empty():
		return _result("indeterminate", _stop_reason, started)
	return _result("viable" if _solutions.size() == 1 else "impossible", "exhausted", started)

func _expired() -> bool:
	if Time.get_ticks_usec() >= _deadline:
		_stop_reason = "time_limit"
	return not _stop_reason.is_empty()

func _search(domains: Array, depth: int) -> void:
	if _solutions.size() >= 1 or _expired():
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
		var witness := Puzzle.new({"id": _puzzle.puzzle_id, "islands": _puzzle.islands, "ruleset": _puzzle.ruleset})
		for k in _edges.size():
			if domains[k][0] > 0:
				witness.bridges[witness.key(_edges[k].a, _edges[k].b)] = domains[k][0]
		if Rules.is_solved(witness):
			_solutions.append(witness.bridges.duplicate(true))
		return
	for value in domains[selected]:
		if _solutions.size() >= 1 or _expired():
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
			if _puzzle.islands[i].get("variant", "classic") == "mystery":
				continue
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
	return {"status": status, "reason": reason, "nodes": int(_stats.search_nodes), "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
static func _capacity(puzzle: Puzzle, a: String, b: String) -> int:
	return 1 if puzzle.island(a).get("variant") == "blue" or puzzle.island(b).get("variant") == "blue" else 2
static func _valid_lower_bounds(puzzle: Puzzle) -> bool:
	for edge in puzzle.bridges:
		if not edge is String:
			return false
		var ends: PackedStringArray = edge.split(":")
		var value: Variant = puzzle.bridges[edge]
		if ends.size() != 2 or not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or value < 1 or value > 2 or puzzle.key(ends[0], ends[1]) != edge or not Rules.move_error(puzzle, ends[0], ends[1], int(value)).is_empty():
			return false
	return true
