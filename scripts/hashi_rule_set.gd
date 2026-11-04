class_name HashiRuleSet
extends RefCounted
## Dispatch at application boundaries; classic engine remains unchanged.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Classic = preload("res://scripts/hashi_rules.gd")
const Variant = preload("res://scripts/hashi_variant_rules.gd")
static func position(item: Dictionary) -> Vector2:
	return Classic.position(item)
static func aligned_neighbors(puzzle: Puzzle, a: String, b: String) -> bool:
	return Classic.aligned_neighbors(puzzle, a, b)
static func valid_definition(puzzle: Puzzle) -> bool:
	if puzzle == null:
		return false
	if puzzle.ruleset == "classic-1":
		for item in puzzle.islands:
			if item.get("variant", "classic") != "classic":
				return false
		return Classic.valid_definition(puzzle)
	return Variant.valid_definition(puzzle)
static func move_error(puzzle: Puzzle, a: String, b: String, count: int) -> String:
	return Classic.move_error(puzzle, a, b, count) if puzzle.ruleset == "classic-1" else Variant.move_error(puzzle, a, b, count)
static func cycle_bridge(puzzle: Puzzle, a: String, b: String) -> String:
	return Classic.cycle_bridge(puzzle, a, b) if puzzle.ruleset == "classic-1" else Variant.cycle_bridge(puzzle, a, b)
static func is_solved(puzzle: Puzzle) -> bool:
	if not valid_definition(puzzle):
		return false
	return Classic.is_solved(puzzle) if puzzle.ruleset == "classic-1" else Variant.is_solved(puzzle)
