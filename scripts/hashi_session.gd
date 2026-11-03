class_name HashiSession
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Sequence = preload("res://scripts/hashi_sequence.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
var base_catalog: Array
var procedural: Dictionary = {}
var catalog: Array
var sequence: Sequence
var store: Store
var current_index := 0
var boards: Dictionary = {}
var completed_ids: Array = []

func _init(definitions: Array = [], save_path: String = "user://hashi-save-v1.json") -> void:
	base_catalog = definitions.duplicate(true)
	catalog = definitions.duplicate(true)
	sequence = Sequence.new(catalog)
	store = Store.new(save_path)
	if not catalog.is_empty():
		boards[str(catalog[0].id)] = {}

func restore() -> bool:
	var data := store.load_game(base_catalog)
	if data.is_empty():
		return false
	procedural = data.procedural.duplicate(true)
	catalog = base_catalog.duplicate(true)
	for recipe in procedural.values():
		catalog.append(recipe.puzzle.duplicate(true))
	current_index = -1
	for index in catalog.size():
		if str(catalog[index].id) == data.current_puzzle_id:
			current_index = index
			break
	boards = data.boards.duplicate(true)
	completed_ids = data.completed_ids.duplicate()
	return true

func is_procedural() -> bool:
	return current_index >= base_catalog.size()

func install_procedural(value: Dictionary) -> bool:
	if not value.get("puzzle") is Dictionary or not value.puzzle.get("id") is String:
		return false
	var id: String = value.puzzle.id
	var recipe := store.normalize_recipe(id, value)
	if recipe.is_empty() or sequence.ids.has(id):
		return false
	if procedural.has(id):
		return select(base_catalog.size())
	# Keep one recent procedural board; static boards and their progress stay intact.
	for previous in procedural:
		boards.erase(previous)
		completed_ids.erase(previous)
	procedural = {id: recipe}
	catalog = base_catalog.duplicate(true)
	catalog.append(recipe.puzzle.duplicate(true))
	boards[id] = {}
	current_index = catalog.size() - 1
	return true

func install_procedural_and_save(value: Dictionary) -> bool:
	# Stage the replacement without mutating the live session or its UI/history.
	var staged := HashiSession.new(base_catalog, store.path)
	staged.catalog = catalog.duplicate(true)
	staged.procedural = procedural.duplicate(true)
	staged.boards = boards.duplicate(true)
	staged.completed_ids = completed_ids.duplicate()
	staged.current_index = current_index
	if not staged.install_procedural(value):
		store.last_error = "No se pudo validar el nuevo tablero."
		return false
	# The store atomically replaces the file. Publish live state only after success.
	if not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	catalog = staged.catalog
	procedural = staged.procedural
	boards = staged.boards
	completed_ids = staged.completed_ids
	current_index = staged.current_index
	return true

func select_and_save(index: int) -> bool:
	# Selection is also committed before replacing the visible board/history.
	var staged := HashiSession.new(base_catalog, store.path)
	staged.catalog = catalog.duplicate(true)
	staged.procedural = procedural.duplicate(true)
	staged.boards = boards.duplicate(true)
	staged.completed_ids = completed_ids.duplicate()
	staged.current_index = current_index
	if not staged.select(index) or not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	boards = staged.boards
	current_index = staged.current_index
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
	if not store.valid_snapshot(snapshot, base_catalog):
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
	if is_procedural():
		return select(0)
	var id := sequence.next_id(str(catalog[current_index].id))
	return select(sequence.ids.find(id))

func snapshot_data() -> Dictionary:
	return {"version": Store.VERSION, "current_puzzle_id": str(catalog[current_index].id),
		"boards": boards.duplicate(true), "completed_ids": completed_ids.duplicate(),
		"procedural": procedural.duplicate(true)}

func save_game() -> bool:
	return store.save_game(snapshot_data(), base_catalog)
