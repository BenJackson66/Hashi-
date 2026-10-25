class_name HashiSession
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Sequence = preload("res://scripts/hashi_sequence.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
var catalog: Array
var sequence: Sequence
var store: Store
var current_index := 0
var boards: Dictionary = {}
var completed_ids: Array = []

func _init(definitions: Array = [], save_path: String = "user://hashi-save-v1.json") -> void:
	catalog = definitions.duplicate(true)
	sequence = Sequence.new(catalog)
	store = Store.new(save_path)
	if not catalog.is_empty():
		boards[str(catalog[0].id)] = {}

func restore() -> bool:
	var data := store.load_game(catalog)
	if data.is_empty():
		return false
	current_index = sequence.ids.find(data.current_puzzle_id)
	boards = data.boards.duplicate(true)
	completed_ids = data.completed_ids.duplicate()
	return true

func current_puzzle() -> Puzzle:
	var puzzle := Puzzle.new(catalog[current_index])
	puzzle.bridges = boards.get(puzzle.puzzle_id, {}).duplicate(true)
	return puzzle

func capture(puzzle: Puzzle) -> bool:
	if puzzle.puzzle_id != str(catalog[current_index].id):
		return false
	var snapshot := snapshot_data()
	snapshot.boards[puzzle.puzzle_id] = puzzle.bridges.duplicate(true)
	if not store.valid_snapshot(snapshot, catalog):
		return false
	boards = snapshot.boards
	if Rules.is_solved(puzzle) and puzzle.puzzle_id not in completed_ids:
		completed_ids.append(puzzle.puzzle_id)
	return true

func select(index: int) -> bool:
	if index < 0 or index >= catalog.size():
		return false
	current_index = index
	var id := str(catalog[index].id)
	if not boards.has(id):
		boards[id] = {}
	return true

func advance() -> bool:
	if not Rules.is_solved(current_puzzle()):
		return false
	var id := sequence.next_id(str(catalog[current_index].id))
	return select(sequence.ids.find(id))

func snapshot_data() -> Dictionary:
	return {"version": Store.VERSION, "current_puzzle_id": str(catalog[current_index].id),
		"boards": boards.duplicate(true), "completed_ids": completed_ids.duplicate()}

func save_game() -> bool:
	return store.save_game(snapshot_data(), catalog)
