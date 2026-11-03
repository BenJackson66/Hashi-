class_name HashiLogicalProfile
extends RefCounted
## Bounded runtime port of H03-A's justified repertoire, not a uniqueness solver.
## Does not read witnesses. Incomplete classification is never a difficulty label.
const Solver = preload("res://scripts/hashi_solver.gd")
const VERSION := "logical-profile-1"
var _puzzle: RefCounted
var _edges: Array
var _incident: Array = []
var _crossings: Array = []
var _deadline: int
var _expired := false
var _probes := 0
var _highest := 1
var _trace: Array = []

func analyze(puzzle: RefCounted, max_time_ms: int = 1000, max_probes: int = 10000) -> Dictionary:
	_deadline = Time.get_ticks_usec() + maxi(0, max_time_ms) * 1000
	_expired = false
	_probes = 0
	_highest = 1
	_trace = []
	_incident = []
	_crossings = []
	if not Solver.valid_input(puzzle) or max_probes < 0:
		return _result("invalid", [])
	_puzzle = puzzle
	_edges = Solver.candidate_edges(puzzle, _deadline)
	for i in puzzle.islands.size():
		_incident.append([])
	var domains: Array = []
	for e in _edges.size():
		_incident[_edges[e].i].append(e)
		_incident[_edges[e].j].append(e)
		domains.append([0, 1, 2])
		for f in range(e + 1, _edges.size()):
			if Solver.edge_crosses(puzzle, _edges[e], _edges[f]):
				_crossings.append([e, f])
	while not _timed_out():
		var closure := _close(domains, false, _trace)
		if closure != "ok":
			return _result(closure, domains)
		var complete := true
		for domain in domains:
			complete = complete and domain.size() == 1
		if complete:
			return _result("solved" if _reachable(domains).size() == puzzle.islands.size() else "contradiction", domains)
		var change := _step(domains, true)
		if change.has("error"):
			return _result(str(change.error), domains)
		if not change.is_empty():
			_apply(domains, change, _trace)
			_highest = maxi(_highest, 2)
			continue
		var rejected := false
		for e in domains.size():
			if domains[e].size() == 1:
				continue
			for value in domains[e]:
				if _probes >= max_probes:
					return _result("probe_limit", domains)
				if _timed_out():
					return _result("time_limit", domains)
				_probes += 1
				var trial := domains.duplicate(true)
				var proof: Array = []
				trial[e] = [value]
				var outcome := _close(trial, true, proof)
				if outcome == "time_limit":
					return _result(outcome, domains)
				if outcome == "contradiction":
					var kept: Array = domains[e].duplicate()
					kept.erase(value)
					_apply(domains, {"edge": e, "kept": kept, "technique": "single_assumption_contradiction", "assumed": value, "proof": proof}, _trace)
					_highest = 3
					rejected = true
					break
			if rejected:
				break
		if not rejected:
			return _result("unresolved", domains)
	return _result("time_limit", domains)

func _timed_out() -> bool:
	_expired = _expired or Time.get_ticks_usec() >= _deadline
	return _expired

func _reachable(domains: Array, omit: int = -1) -> Array:
	var seen := {0: true}
	var pending := [0]
	while not pending.is_empty():
		if _timed_out():
			return []
		var i: int = pending.pop_back()
		for e in _incident[i]:
			if e == omit or int(domains[e].back()) == 0:
				continue
			var j: int = _edges[e].j if _edges[e].i == i else _edges[e].i
			if not seen.has(j):
				seen[j] = true
				pending.append(j)
	var ordered := seen.keys()
	ordered.sort()
	return ordered

func _step(domains: Array, cuts: bool) -> Dictionary:
	if _timed_out():
		return {"error": "time_limit"}
	for domain in domains:
		if domain.is_empty():
			return {"error": "contradiction"}
	for i in _incident.size():
		var lower := 0
		var upper := 0
		for e in _incident[i]:
			lower += int(domains[e].front())
			upper += int(domains[e].back())
		var target := int(_puzzle.islands[i].target)
		if target < lower or target > upper:
			return {"error": "contradiction"}
		for e in _incident[i]:
			var kept: Array = []
			for value in domains[e]:
				if value + lower - int(domains[e].front()) <= target and value + upper - int(domains[e].back()) >= target:
					kept.append(value)
			if kept != domains[e]:
				return {"edge": e, "kept": kept, "technique": "local_capacity", "island": i}
	for pair in _crossings:
		for direction in [[pair[0], pair[1]], [pair[1], pair[0]]]:
			var a: int = direction[0]
			var b: int = direction[1]
			if int(domains[a].front()) > 0:
				if not domains[b].has(0):
					return {"error": "contradiction"}
				if domains[b] != [0]:
					return {"edge": b, "kept": [0], "technique": "crossing_exclusion", "positive_edge": a}
	if cuts:
		if _reachable(domains).size() != _puzzle.islands.size():
			return {"error": "time_limit" if _expired else "contradiction"}
		for e in domains.size():
			if domains[e].size() <= 1 or int(domains[e].back()) == 0:
				continue
			var side := _reachable(domains, e)
			if _expired:
				return {"error": "time_limit"}
			if side.size() < _puzzle.islands.size():
				var kept: Array = domains[e].duplicate()
				if kept.has(0):
					kept.erase(0)
					return {"edge": e, "kept": kept, "technique": "connectivity_cut", "cut_side": side}
				var total := 0
				for i in side:
					total += int(_puzzle.islands[i].target)
				kept = []
				for value in domains[e]:
					if int(value) % 2 == total % 2:
						kept.append(value)
				if kept.is_empty():
					return {"error": "contradiction"}
				if kept != domains[e]:
					return {"edge": e, "kept": kept, "technique": "cut_parity", "cut_side": side}
	return {}

func _apply(domains: Array, change: Dictionary, trace: Array) -> void:
	var event := change.duplicate(true)
	event.before = domains[change.edge].duplicate()
	trace.append(event)
	domains[change.edge] = change.kept

func _close(domains: Array, cuts: bool, trace: Array) -> String:
	while true:
		var change := _step(domains, cuts)
		if change.has("error"):
			return str(change.error)
		if change.is_empty():
			return "ok"
		_apply(domains, change, trace)
	return "ok"

func _result(status: String, domains: Array) -> Dictionary:
	if _expired:
		status = "time_limit"
	return {"status": status, "profile": ["local", "connectivity", "contradiction1"][_highest - 1] if status == "solved" else "unclassified",
		"version": VERSION, "probes": _probes, "domains": domains.duplicate(true), "trace": _trace.duplicate(true)}
