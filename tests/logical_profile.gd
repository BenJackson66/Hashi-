extends SceneTree
const Logical = preload("res://scripts/hashi_logical_profile.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("LOGICAL FAIL: ", label)
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(2)
		return
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	check(records.size() == 1000, "full independent H03-A oracle")
	var started := Time.get_ticks_usec()
	for record in records:
		var puzzle := Puzzle.new(record.puzzle)
		var before := JSON.stringify(puzzle.islands)
		var classified := Logical.new().analyze(puzzle)
		check(classified.status == "solved" and classified.profile == record.expected.profile, "same profile as h03a-1 " + puzzle.puzzle_id)
		check(classified.probes == int(record.expected.probe_tests), "same deterministic probe count")
		var edges := Solver.candidate_edges(puzzle)
		for e in edges.size():
			check(classified.domains[e].size() == record.expected.domains[e].size() and int(classified.domains[e][0]) == int(record.expected.domains[e][0]), "same final domains")
		var technique_names: Array = []
		for event in classified.trace:
			technique_names.append(event.technique)
			var edge: Dictionary = edges[event.edge]
			var solution_value := int(record.solution.get(puzzle.key(edge.a, edge.b), 0))
			check(event.kept.has(solution_value), "deduction preserves unique witness")
		var expected_names: Array = []
		for event in record.expected.trace:
			expected_names.append(event.technique)
		check(technique_names == expected_names, "same ordered techniques as h03a-1")
		check(JSON.stringify(puzzle.islands) == before and puzzle.bridges.is_empty(), "classification leaves input untouched")
	var sample := Puzzle.new(records[0].puzzle)
	check(Logical.new().analyze(sample, 0).status == "time_limit", "timeout cannot be a profile")
	check(Logical.new().analyze(null).status == "invalid", "invalid input")
	var ambiguous := Puzzle.new({"id": "ambiguous", "islands": [{"id": "a", "x": 0, "y": 0, "target": 3}, {"id": "b", "x": 2, "y": 0, "target": 3}, {"id": "c", "x": 0, "y": 2, "target": 3}, {"id": "d", "x": 2, "y": 2, "target": 3}]})
	check(Logical.new().analyze(ambiguous).status == "unresolved", "ambiguous board cannot get a profile")
	check(Logical.new().analyze(ambiguous, 1000, 0).status == "probe_limit", "probe budget cannot get a profile")
	var disconnected := Puzzle.new({"id": "disconnected", "islands": [{"id": "a", "x": 0, "y": 0, "target": 1}, {"id": "b", "x": 1, "y": 0, "target": 1}, {"id": "c", "x": 2, "y": 2, "target": 1}, {"id": "d", "x": 3, "y": 2, "target": 1}]})
	check(Logical.new().analyze(disconnected).status == "contradiction", "complete disconnected local network rejected")
	var crossing := Puzzle.new({"id": "crossing", "islands": [{"id": "a", "x": 1, "y": 0, "target": 1}, {"id": "b", "x": 0, "y": 1, "target": 1}, {"id": "c", "x": 2, "y": 1, "target": 1}, {"id": "d", "x": 1, "y": 2, "target": 1}]})
	check(Logical.new().analyze(crossing).status == "contradiction", "forced crossing rejected")
	print("LOGICAL PROFILE: ", checks, " checks, ", failures, " failures; 1000 archived boards; ms=", (Time.get_ticks_usec() - started) / 1000.0)
	quit(1 if failures else 0)
