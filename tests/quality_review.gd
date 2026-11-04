extends SceneTree
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Session = preload("res://scripts/hashi_session.gd")
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Quality = preload("res://scripts/hashi_quality.gd")
const Generator = preload("res://scripts/hashi_generator.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("QUALITY REVIEW FAIL: ", label)
func pair(id: String, target: int) -> Dictionary:
	return {"id": id, "title": id, "islands": [{"id": "a", "x": 0, "y": 0, "target": target}, {"id": "b", "x": 1, "y": 0, "target": target}]}
func event(kind: String, before: Dictionary, after: Dictionary) -> Dictionary:
	return {"kind": kind, "before": before.duplicate(true), "bridges": after.duplicate(true)}
func bytes(path: String) -> String:
	return FileAccess.get_file_as_string(path)
func block(path: String) -> void:
	check(DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp")) == OK, "actual write obstruction created")
func unblock(path: String) -> void:
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp")) == OK, "write obstruction removed")
func reopen(catalog: Array, path: String, expected: Dictionary) -> Session:
	var restored := Session.new(catalog, path)
	check(restored.restore(), "reopen succeeds")
	check(restored.snapshot_data() == expected, "all durable state restored exactly")
	return restored
func run() -> void:
	var catalog: Array = [pair("review-double", 2), pair("review-single", 1), pair("review-new", 1)]
	var path := "user://minerva-quality-review.json"
	var session := Session.new(catalog, path)
	check(session.save_game(), "fresh quality state valid")
	var puzzle := session.current_puzzle()
	puzzle.bridges = {"a:b": 1}
	check(session.capture_and_save(puzzle, [event("add", {}, puzzle.bridges)]), "simple lower bound can grow to double")
	check(not session.quality.marks[puzzle.puzzle_id].spoiled and session.quality.streak == 0, "first of two bridges stays clean without victory")
	puzzle.bridges = {"a:b": 2}
	var before := session.snapshot_data()
	var original := bytes(path)
	block(path)
	check(not session.capture_and_save(puzzle, [event("add", {"a:b": 1}, puzzle.bridges)]), "real victory write fails")
	check(session.snapshot_data() == before and bytes(path) == original, "failed victory publishes neither bridges nor perfect credit")
	unblock(path)
	check(session.capture_and_save(puzzle, [event("add", {"a:b": 1}, puzzle.bridges)]), "victory retries atomically")
	check(session.quality.streak == 1 and session.quality.best == 1 and Quality.color_name(session.quality) == "Azul", "first perfect turns bridges blue")
	check(session.capture_and_save(puzzle) and session.quality.streak == 1, "repeated save never farms credit")
	session = reopen(catalog, path, session.snapshot_data())
	before = session.snapshot_data()
	original = bytes(path)
	block(path)
	# Undo then redo before a failed write is retried: final board equals committed board.
	var actions := [event("undo", {"a:b": 2}, {"a:b": 1}), event("redo", {"a:b": 1}, {"a:b": 2})]
	check(not session.capture_and_save(puzzle, actions), "fault write fails")
	check(session.snapshot_data() == before and bytes(path) == original, "failed fault preserves committed streak/file")
	unblock(path)
	check(session.capture_and_save(puzzle, actions), "fault prefix retries even if final bridges equal old board")
	check(session.quality.streak == 0 and session.quality.best == 1 and session.quality.marks[puzzle.puzzle_id].spoiled, "undo fault remains sticky after redo")
	check(puzzle.puzzle_id in session.completed_ids, "normal fault does not erase completion")
	check(session.select_and_save(1), "select fresh normal board")
	puzzle = session.current_puzzle()
	puzzle.bridges = {"a:b": 1}
	check(session.capture_and_save(puzzle, [event("add", {}, puzzle.bridges)]) and session.quality.streak == 1, "new perfect restarts streak")
	var legacy := session.snapshot_data()
	legacy.version = 5
	legacy.erase("quality")
	legacy.erase("story_attempts")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	original = bytes(path)
	var restored := Session.new(catalog, path)
	check(restored.restore(), "actual v5 file migrates")
	check(bytes(path) == original, "opening legacy leaves bytes untouched")
	check(restored.boards == legacy.boards and restored.completed_ids == legacy.completed_ids and restored.run == legacy.run and restored.story == legacy.story, "legacy boards/completion/run/story preserved")
	check(restored.quality.streak == 0 and restored.quality.best == 0 and restored.quality.iron_record == 0, "legacy never invents perfects or records")
	check(restored.capture_and_save(restored.current_puzzle()) and restored.quality.streak == 0, "old solved board cannot retroactively credit")
	check(restored.select_and_save(2), "unvisited legacy catalog board available")
	puzzle = restored.current_puzzle()
	puzzle.bridges = {"a:b": 1}
	check(restored.capture_and_save(puzzle, [event("add", {}, puzzle.bridges)]) and restored.quality.streak == 1, "unvisited board can earn new perfect")
	reopen(catalog, path, restored.snapshot_data())
	await iron_prefix(catalog)
	pending_roundtrip(catalog)
	await iron_record_scope(catalog)
	print("QUALITY REVIEW: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
func iron_prefix(catalog: Array) -> void:
	var generated := Generator.new().generate(42, {})
	check(generated.status == "success", "iron fixture generated")
	if generated.status != "success":
		return
	var recipe := {"seed": str(generated.seed), "algorithm_version": generated.algorithm_version, "identity_schema": 1, "parameters": generated.parameters, "puzzle": generated.puzzle}
	var path := "user://minerva-iron-prefix.json"
	var session := Session.new(catalog, path)
	check(session.install_procedural_and_save(recipe, Mode.fresh("iron")), "iron challenge installed")
	var puzzle := session.current_puzzle()
	var solution := Solver.new().solve(puzzle)
	check(solution.status == "unique", "iron visible solution unique")
	if solution.status != "unique":
		return
	var wrong := {}
	for edge in Solver.candidate_edges(puzzle):
		var key := puzzle.key(edge.a, edge.b)
		if int(solution.solutions[0].get(key, 0)) < 2:
			wrong[key] = int(solution.solutions[0].get(key, 0)) + 1
			break
	check(not wrong.is_empty(), "monotone-impossible prefix selected")
	puzzle.bridges = solution.solutions[0].duplicate(true)
	var actions := [event("add", {}, wrong), event("reset", wrong, {}), event("add", {}, puzzle.bridges)]
	var before := session.snapshot_data()
	var original := bytes(path)
	block(path)
	check(not session.capture_and_save(puzzle, actions), "iron fault/solved-prefix write fails")
	check(session.snapshot_data() == before and bytes(path) == original, "failed iron result publishes nothing")
	unblock(path)
	check(session.capture_and_save(puzzle, actions), "iron failed-action prefix retry commits")
	check(session.quality.iron_ended, "first fault ends iron despite final solved state")
	check(session.run.wins == 0 and session.quality.iron_record == 0 and puzzle.puzzle_id not in session.completed_ids, "failed iron never gains victory or record")
	var ended := session.snapshot_data()
	puzzle.bridges = {}
	check(not session.capture_and_save(puzzle, [event("reset", ended.boards[puzzle.puzzle_id], {})]), "domain rejects mutation after iron ends")
	check(session.snapshot_data() == ended, "ended challenge state remains frozen")
	reopen(catalog, path, ended)

func pending_roundtrip(catalog: Array) -> void:
	var path := "user://minerva-quality-pending.json"
	var session := Session.new(catalog, path)
	var puzzle := session.current_puzzle()
	puzzle.bridges = {"a:b": 2}
	# Valid durable unresolved state. Prefix has one bridge, current board is complete.
	session.boards[puzzle.puzzle_id] = puzzle.bridges.duplicate(true)
	session.quality.serial = 1
	session.quality.pending = [{"serial": 1, "id": puzzle.puzzle_id, "bridges": {"a:b": 1}, "iron": false}]
	check(session.save_game(), "unresolved prefix state valid on disk")
	session = reopen(catalog, path, session.snapshot_data())
	check(not session.select_and_save(1), "pending resolution prevents changing puzzle")
	check(session.capture_and_save(puzzle), "pending same state can be saved")
	check(session.completed_ids.is_empty() and session.quality.streak == 0, "pending complete board cannot award victory or perfect")
	var before := session.snapshot_data()
	check(not session.capture_and_save(puzzle, [], {"serial": 2, "status": "viable"}) and session.snapshot_data() == before, "stale/mismatched result cannot clear pending")
	var original := bytes(path)
	block(path)
	check(not session.capture_and_save(puzzle, [], {"serial": 1, "status": "viable"}), "verdict write actually fails")
	check(session.snapshot_data() == before and bytes(path) == original, "failed verdict retains prefix and all prior credits")
	unblock(path)
	check(session.capture_and_save(puzzle, [], {"serial": 1, "status": "viable"}), "correct verdict retries atomically")
	check(session.quality.pending.is_empty() and session.quality.streak == 1 and puzzle.puzzle_id in session.completed_ids, "resolved viability awards victory exactly once")
	before = session.snapshot_data()
	check(not session.capture_and_save(puzzle, [], {"serial": 1, "status": "viable"}) and session.snapshot_data() == before, "duplicate old verdict cannot credit twice")
	reopen(catalog, path, before)
func iron_record_scope(catalog: Array) -> void:
	var generated := Generator.new().generate(847, {})
	check(generated.status == "success", "record fixture available")
	if generated.status != "success":
		return
	var recipe := {"seed": str(generated.seed), "algorithm_version": generated.algorithm_version, "identity_schema": 1, "parameters": generated.parameters, "puzzle": generated.puzzle}
	var path := "user://minerva-iron-record.json"
	var session := Session.new(catalog, path)
	check(session.install_procedural_and_save(recipe, Mode.fresh("iron")), "fresh iron installed for record")
	var puzzle := session.current_puzzle()
	var solved := Solver.new().solve(puzzle)
	check(solved.status == "unique", "record board uniquely solvable")
	if solved.status != "unique":
		return
	puzzle.bridges = solved.solutions[0].duplicate(true)
	check(session.capture_and_save(puzzle, [event("add", {}, puzzle.bridges)]), "perfect iron victory saves")
	check(session.run.wins == 1 and session.quality.iron_record == 1 and session.quality.streak == 1, "iron win updates record and global color")
	var reduced := puzzle.bridges.duplicate(true)
	var key: String = str(reduced.keys()[0])
	if int(reduced[key]) == 1:
		reduced.erase(key)
	else:
		reduced[key] = 1
	var old := puzzle.bridges.duplicate(true)
	puzzle.bridges = reduced
	check(session.capture_and_save(puzzle, [event("undo", old, reduced)]), "iron undo commits loss")
	check(session.quality.iron_ended and session.quality.iron_record == 1 and session.run.wins == 1 and session.quality.streak == 0, "ended challenge preserves earned record")
	var other := Generator.new().generate(2081, {})
	check(other.status == "success", "new challenge fixture available")
	if other.status != "success":
		return
	var next := {"seed": str(other.seed), "algorithm_version": other.algorithm_version, "identity_schema": 1, "parameters": other.parameters, "puzzle": other.puzzle}
	check(session.install_procedural_and_save(next, Mode.fresh("iron")), "explicit new challenge after defeat succeeds")
	check(not session.quality.iron_ended and session.run.wins == 0 and session.quality.iron_record == 1, "new challenge resets run but preserves record")
	check(session.select_and_save(0), "normal board accessible with paused iron challenge")
	puzzle = session.current_puzzle()
	puzzle.bridges = {"a:b": 1}
	check(session.capture_and_save(puzzle, [event("add", {}, puzzle.bridges)]), "normal move saved while iron paused")
	puzzle.bridges = {}
	check(session.capture_and_save(puzzle, [event("undo", {"a:b": 1}, {})]), "normal undo saved while iron paused")
	check(not session.quality.iron_ended and session.run.wins == 0 and session.quality.iron_record == 1, "normal fault does not end paused iron or touch record")
	reopen(catalog, path, session.snapshot_data())
