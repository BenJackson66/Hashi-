class_name HashiHistory
extends RefCounted
## Only actual state changes are recorded; snapshots never alias live bridges.
var past: Array[Dictionary] = []
var future: Array[Dictionary] = []

func clear() -> void:
	past.clear()
	future.clear()

func record(before: Dictionary, after: Dictionary) -> bool:
	if before == after:
		return false
	past.append({"before": before.duplicate(true), "after": after.duplicate(true)})
	future.clear()
	return true

func undo(puzzle: HashiPuzzle) -> bool:
	if past.is_empty():
		return false
	var move: Dictionary = past.pop_back()
	puzzle.bridges = move.before.duplicate(true)
	future.append(move)
	return true

func redo(puzzle: HashiPuzzle) -> bool:
	if future.is_empty():
		return false
	var move: Dictionary = future.pop_back()
	puzzle.bridges = move.after.duplicate(true)
	past.append(move)
	return true
