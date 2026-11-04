class_name HashiVariantRules
extends RefCounted
## Public rules only. Mystery target 0 is a sentinel, never a hidden equation.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Classic = preload("res://scripts/hashi_rules.gd")
const VERSION := "visible-variants-1"
static func valid_definition(puzzle: Puzzle) -> bool:
	if puzzle == null or puzzle.ruleset != VERSION or puzzle.islands.size() < 2 or puzzle.islands.size() > 64:
		return false
	var geometry: Array = []
	var special := false
	for item in puzzle.islands:
		if not item is Dictionary or item.size() != 6 or not item.has_all(["id", "x", "y", "target", "variant", "color"]) or not item.id is String or item.id.length() > 32:
			return false
		for field in ["x", "y", "target"]:
			if not (item[field] is int or item[field] is float) or not is_finite(float(item[field])) or float(item[field]) != floor(float(item[field])):
				return false
		if item.x < 0 or item.x >= 16 or item.y < 0 or item.y >= 16:
			return false
		if item.variant not in ["classic", "blue", "mystery"]:
			return false
		if item.variant == "mystery":
			if item.target != 0 or item.color != "mystery":
				return false
		elif item.target < 1 or item.target > 8 or item.color != ("blue" if item.variant == "blue" else "neutral"):
			return false
		special = special or item.variant != "classic"
		var copy: Dictionary = item.duplicate(true)
		if item.variant == "mystery":
			copy.target = 1
		geometry.append(copy)
	return special and Classic.valid_definition(Puzzle.new({"islands": geometry}))
static func capacity(puzzle: Puzzle, a: String, b: String) -> int:
	return 1 if puzzle.island(a).get("variant") == "blue" or puzzle.island(b).get("variant") == "blue" else 2
static func move_error(puzzle: Puzzle, a: String, b: String, count: int) -> String:
	var error := Classic.move_error(puzzle, a, b, count)
	if not error.is_empty():
		return error
	if count > capacity(puzzle, a, b):
		return "Las islas azules solo admiten puentes simples."
	return ""
static func cycle_bridge(puzzle: Puzzle, a: String, b: String) -> String:
	if not Classic.aligned_neighbors(puzzle, a, b):
		return "Elige dos islas vecinas en la misma fila o columna."
	var count := (puzzle.bridge_count(a, b) + 1) % (capacity(puzzle, a, b) + 1)
	var error := move_error(puzzle, a, b, count)
	if error.is_empty():
		if count == 0:
			puzzle.bridges.erase(puzzle.key(a, b))
		else:
			puzzle.bridges[puzzle.key(a, b)] = count
	return error
static func is_solved(puzzle: Puzzle) -> bool:
	if not valid_definition(puzzle):
		return false
	for edge in puzzle.bridges:
		if not edge is String:
			return false
		var ids: PackedStringArray = edge.split(":")
		var count: Variant = puzzle.bridges[edge]
		if ids.size() != 2 or puzzle.key(ids[0], ids[1]) != edge or not (count is int or count is float) or float(count) != floor(float(count)) or count < 1 or count > 2 or not move_error(puzzle, ids[0], ids[1], int(count)).is_empty():
			return false
	for item in puzzle.islands:
		if item.variant != "mystery" and puzzle.degree(item.id) != int(item.target):
			return false
	return Classic.network_connected(puzzle)
