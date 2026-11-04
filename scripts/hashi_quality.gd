class_name HashiQuality
extends RefCounted
## Player-wide streak, bounded retained-board marks and unresolved gesture prefixes.
const Judge = preload("res://scripts/hashi_extension_judge.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const MAX_PENDING := 16
const MAX_COUNT := 9007199254740000
static func fresh() -> Dictionary:
	return {"version": 1, "streak": 0, "best": 0, "iron_record": 0, "iron_ended": false, "serial": 0, "marks": {}, "pending": []}
static func mark(state: Dictionary, id: String) -> Dictionary:
	if not state.marks.has(id):
		state.marks[id] = {"spoiled": false, "credited": false}
	return state.marks[id]
static func fault(state: Dictionary, id: String, iron: bool) -> void:
	mark(state, id).spoiled = true
	state.streak = 0
	if iron:
		state.iron_ended = true
static func action(state: Dictionary, puzzle: Puzzle, event: Dictionary, iron: bool) -> bool:
	var id := puzzle.puzzle_id
	mark(state, id)
	var reduced: bool = event.get("kind", "") == "undo"
	for edge in event.get("before", {}):
		if int(event.before[edge]) > int(event.bridges.get(edge, 0)):
			reduced = true
	if reduced:
		fault(state, id, iron)
		return true
	var snapshot := Puzzle.new({"id": id, "islands": puzzle.islands, "ruleset": puzzle.ruleset})
	snapshot.bridges = event.bridges.duplicate(true)
	# A solved visible board is already a constructive proof of its own extension.
	# Earlier unresolved prefixes still remain in state.pending and block credit.
	if Rules.is_solved(snapshot):
		return true
	# Cheap bounded decision; unresolved work moves to a worker, never blocks a frame for seconds.
	var verdict := Judge.new().judge(snapshot, {"max_time_ms": 5, "max_nodes": 1000})
	if verdict.status == "impossible":
		fault(state, id, iron)
	elif verdict.status == "indeterminate":
		if state.pending.size() >= MAX_PENDING:
			return false
		state.serial = mini(int(state.serial) + 1, MAX_COUNT)
		state.pending.append({"serial": state.serial, "id": id, "bridges": snapshot.bridges.duplicate(true), "iron": iron})
	elif verdict.status != "viable":
		return false
	return true
static func resolve(state: Dictionary, verdict: Dictionary) -> bool:
	if verdict.is_empty():
		return true
	if state.pending.is_empty() or int(state.pending[0].serial) != int(verdict.get("serial", -1)) or verdict.get("status") not in ["viable", "impossible"]:
		return false
	var event: Dictionary = state.pending.pop_front()
	if verdict.status == "impossible":
		fault(state, event.id, event.iron)
	return true
static func credit(state: Dictionary, puzzle: Puzzle, iron: bool, iron_wins: int) -> void:
	var current := mark(state, puzzle.puzzle_id)
	if current.spoiled or current.credited or not Rules.is_solved(puzzle):
		return
	for event in state.pending:
		if event.id == puzzle.puzzle_id:
			return
	current.credited = true
	state.streak = mini(int(state.streak) + 1, MAX_COUNT)
	state.best = maxi(int(state.best), int(state.streak))
	if iron and not state.iron_ended:
		state.iron_record = maxi(int(state.iron_record), iron_wins)
static func prune(state: Dictionary, ids: Array) -> void:
	for id in state.marks.keys():
		if id not in ids:
			state.marks.erase(id)
static func color_name(state: Dictionary) -> String:
	return "Dorado" if state.streak >= 7 else ("Morado" if state.streak >= 3 else ("Azul" if state.streak >= 1 else "Sin racha"))
static func valid(value: Variant, known: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 8 or not value.has_all(["version", "streak", "best", "iron_record", "iron_ended", "serial", "marks", "pending"]) or value.version != 1 or not value.iron_ended is bool:
		return false
	for key in ["streak", "best", "iron_record", "serial"]:
		if not _integer(value[key]) or value[key] < 0 or value[key] > MAX_COUNT:
			return false
	if value.best < value.streak or not value.marks is Dictionary or value.marks.size() > known.size() or not value.pending is Array or value.pending.size() > MAX_PENDING:
		return false
	for id in value.marks:
		var entry: Variant = value.marks[id]
		if not known.has(id) or not entry is Dictionary or entry.size() != 2 or not entry.has_all(["spoiled", "credited"]) or not entry.spoiled is bool or not entry.credited is bool:
			return false
	var serial := -1
	for event in value.pending:
		if not event is Dictionary or event.size() != 4 or not event.has_all(["serial", "id", "bridges", "iron"]) or not event.iron is bool or not known.has(event.id) or not _integer(event.serial) or event.serial <= serial or event.serial > value.serial or not event.bridges is Dictionary:
			return false
		serial = int(event.serial)
	return true
static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
