class_name HashiStoryAttempts
extends RefCounted
## One correction per real action, irrespective of the number of removed edges.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const LIMIT := 3
static func fresh() -> Dictionary:
	return {"version": 1, "levels": {}}
static func remaining(state: Dictionary, id: String) -> int:
	return int(state.levels.get(id, {}).get("left", LIMIT))
static func lost(state: Dictionary, id: String) -> bool:
	return bool(state.levels.get(id, {}).get("lost", false))
static func correction(event: Dictionary) -> bool:
	if event.get("before", {}) == event.get("bridges", {}):
		return false
	if event.get("kind", "") == "undo":
		return true
	for edge in event.before:
		if int(event.before[edge]) > int(event.bridges.get(edge, 0)):
			return true
	return false
static func apply_action(state: Dictionary, puzzle: Puzzle, event: Dictionary) -> void:
	var id := puzzle.puzzle_id
	if lost(state, id):
		return
	if not correction(event):
		return
	var left := maxi(0, remaining(state, id) - 1)
	var after := Puzzle.new({"id": id, "ruleset": puzzle.ruleset, "islands": puzzle.islands})
	after.bridges = event.bridges.duplicate(true)
	state.levels[id] = {"left": left, "lost": left == 0 and not Rules.is_solved(after)}
static func restart(state: Dictionary, id: String) -> void:
	state.levels[id] = {"left": LIMIT, "lost": false}
static func prune(state: Dictionary, ids: Array) -> void:
	for id in state.levels.keys():
		if id not in ids:
			state.levels.erase(id)
static func valid(value: Variant, story_ids: Array, boards: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 2 or not value.has_all(["version", "levels"]) or value.version != 1 or not value.levels is Dictionary or value.levels.size() > story_ids.size():
		return false
	for id in value.levels:
		var item: Variant = value.levels[id]
		if not id is String or id not in story_ids or not boards.has(id) or not item is Dictionary or item.size() != 2 or not item.has_all(["left", "lost"]) or not item.lost is bool:
			return false
		if not (item.left is int or item.left is float) or not is_finite(float(item.left)) or float(item.left) != floor(float(item.left)) or item.left < 0 or item.left > LIMIT or (item.lost and item.left != 0):
			return false
	return true
