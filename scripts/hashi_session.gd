class_name HashiSession
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const Sequence = preload("res://scripts/hashi_sequence.gd")
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Story = preload("res://scripts/hashi_story_state.gd")
const StoryCatalog = preload("res://scripts/hashi_story_catalog.gd")
const Quality = preload("res://scripts/hashi_quality.gd")
const Attempts = preload("res://scripts/hashi_story_attempts.gd")
const Store = preload("res://scripts/hashi_save_store.gd")
var base_catalog: Array
var procedural: Dictionary = {}
var catalog: Array
var sequence: Sequence
var store: Store
var current_index := 0
var boards: Dictionary = {}
var completed_ids: Array = []
var run: Dictionary = Mode.fresh()
var story: Dictionary = Story.fresh()
var quality: Dictionary = Quality.fresh()
var story_attempts: Dictionary = Attempts.fresh()

func _init(definitions: Array = [], save_path: String = "user://hashi-save-v1.json") -> void:
	base_catalog = definitions.duplicate(true)
	catalog = definitions.duplicate(true)
	catalog.append_array(Story.definitions(story))
	sequence = Sequence.new(base_catalog)
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
	quality = data.quality.duplicate(true)
	story_attempts = data.story_attempts.duplicate(true)
	story = data.story.duplicate(true)
	catalog.append_array(Story.definitions(story))
	current_index = -1
	for index in catalog.size():
		if str(catalog[index].id) == data.current_puzzle_id:
			current_index = index
			break
	boards = data.boards.duplicate(true)
	completed_ids = data.completed_ids.duplicate()
	run = data.run.duplicate(true)
	return true

func is_procedural() -> bool:
	return current_index >= 0 and current_index < catalog.size() and procedural.has(str(catalog[current_index].id))

func is_story() -> bool:
	return current_index >= 0 and Story.ordinal(story, str(catalog[current_index].id)) >= 0

func story_ordinal() -> int:
	return Story.ordinal(story, str(catalog[current_index].id))

func install_procedural(value: Dictionary) -> bool:
	if not value.get("puzzle") is Dictionary or not value.puzzle.get("id") is String:
		return false
	var id: String = value.puzzle.id
	var recipe := store.normalize_recipe(id, value)
	if recipe.is_empty() or sequence.ids.has(id):
		return false
	if procedural.has(id):
		for i in catalog.size():
			if catalog[i].id == id:
				return select(i)
		return false
	# Keep one recent procedural board; static boards and their progress stay intact.
	for previous in procedural:
		boards.erase(previous)
		completed_ids.erase(previous)
	procedural = {id: recipe}
	run.credited_id = ""
	catalog = base_catalog.duplicate(true)
	catalog.append(recipe.puzzle.duplicate(true))
	catalog.append_array(Story.definitions(story))
	boards[id] = {}
	current_index = base_catalog.size()
	return true

func _staged() -> HashiSession:
	var staged := HashiSession.new(base_catalog, store.path)
	staged.catalog = catalog.duplicate(true)
	staged.procedural = procedural.duplicate(true)
	staged.boards = boards.duplicate(true)
	staged.completed_ids = completed_ids.duplicate()
	staged.current_index = current_index
	staged.run = run.duplicate(true)
	staged.story = story.duplicate(true)
	staged.quality = quality.duplicate(true)
	staged.story_attempts = story_attempts.duplicate(true)
	return staged

func _publish(staged: HashiSession) -> void:
	catalog = staged.catalog
	procedural = staged.procedural
	boards = staged.boards
	completed_ids = staged.completed_ids
	current_index = staged.current_index
	run = staged.run
	story = staged.story
	quality = staged.quality
	story_attempts = staged.story_attempts

func install_procedural_and_save(value: Dictionary, requested_run: Dictionary = {}) -> bool:
	if not quality.pending.is_empty():
		return false
	var staged := _staged()
	if not requested_run.is_empty():
		staged.run = requested_run.duplicate(true)
		if staged.run.mode == "iron":
			staged.quality.iron_ended = false
	if not staged.install_procedural(value):
		store.last_error = "No se pudo validar el nuevo tablero."
		return false
	Quality.prune(staged.quality, staged.boards.keys())
	if not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	_publish(staged)
	return true

func select_and_save(index: int) -> bool:
	if not quality.pending.is_empty():
		return false
	var staged := _staged()
	if not staged.select(index) or not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	_publish(staged)
	return true

func capture_and_save(puzzle: Puzzle, actions: Array = [], verdict: Dictionary = {}) -> bool:
	# Live Board, sticky faults, unresolved prefixes and victory are one transaction.
	var staged := _staged()
	if not staged.capture(puzzle, false) or not Quality.resolve(staged.quality, verdict):
		return false
	var iron: bool = staged.is_procedural() and staged.run.mode == "iron"
	var actual_actions := actions.duplicate(true)
	if actual_actions.is_empty() and puzzle.bridges != boards.get(puzzle.puzzle_id, {}):
		actual_actions.append({"kind": "move", "before": boards.get(puzzle.puzzle_id, {}).duplicate(true), "bridges": puzzle.bridges.duplicate(true)})
	var expected: Dictionary = boards.get(puzzle.puzzle_id, {}).duplicate(true)
	for event in actual_actions:
		if not event is Dictionary or not event.has_all(["before", "bridges"]) or event.before != expected or not store._valid_bridges(event.bridges, catalog[current_index]):
			return false
		expected = event.bridges
	if expected != puzzle.bridges:
		return false
	for event in actual_actions:
		if staged.is_story():
			Attempts.apply_action(staged.story_attempts, puzzle, event)
		if not Quality.action(staged.quality, puzzle, event, iron):
			return false
	if staged.quality.pending.is_empty() and not (iron and staged.quality.iron_ended) and not staged.story_lost():
		staged._award_victory(puzzle)
		Quality.credit(staged.quality, puzzle, iron, int(staged.run.wins))
	if not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	_publish(staged)
	return true

func current_puzzle() -> Puzzle:
	var puzzle := Puzzle.new(catalog[current_index])
	puzzle.bridges = boards.get(puzzle.puzzle_id, {}).duplicate(true)
	return puzzle

func capture(puzzle: Puzzle, award: bool = true) -> bool:
	if is_story() and story_corrections_left() == 0 and puzzle.bridges != boards.get(puzzle.puzzle_id, {}):
		return false
	if is_procedural() and run.mode == "iron" and quality.iron_ended and puzzle.bridges != boards.get(puzzle.puzzle_id, {}):
		return false
	if puzzle.puzzle_id != str(catalog[current_index].id):
		return false
	var snapshot := snapshot_data()
	snapshot.boards[puzzle.puzzle_id] = puzzle.bridges.duplicate(true)
	if not store.valid_snapshot(snapshot, base_catalog):
		return false
	boards = snapshot.boards
	if award and quality.pending.is_empty() and not (is_procedural() and run.mode == "iron" and quality.iron_ended) and not story_lost():
		_award_victory(puzzle)
	return true

func _award_victory(puzzle: Puzzle) -> void:
	if Rules.is_solved(puzzle):
		if puzzle.puzzle_id not in completed_ids:
			completed_ids.append(puzzle.puzzle_id)
		if is_procedural():
			run = Mode.credit(run, puzzle.puzzle_id)
		elif is_story():
			story = Story.credit(story, puzzle.puzzle_id)

func select(index: int) -> bool:
	if index < 0 or index >= catalog.size():
		return false
	var id_candidate := str(catalog[index].id)
	if Story.ordinal(story, id_candidate) >= 0 and not Story.unlocked(story, id_candidate):
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
		"procedural": procedural.duplicate(true), "run": run.duplicate(true), "story": story.duplicate(true), "quality": quality.duplicate(true), "story_attempts": story_attempts.duplicate(true)}

func save_game() -> bool:
	return store.save_game(snapshot_data(), base_catalog)


func story_index(ordinal: int) -> int:
	for i in catalog.size():
		if Story.ordinal(story, str(catalog[i].id)) == ordinal:
			return i
	return -1

func install_story_and_save(ordinal: int, recipe: Dictionary) -> bool:
	if not quality.pending.is_empty():
		return false
	if ordinal < StoryCatalog.COUNT or ordinal != int(story.frontier) or story_index(ordinal) >= 0:
		return false
	var id: String = str(recipe.get("puzzle", {}).get("id", ""))
	if store.normalize_story_recipe(id, recipe).is_empty() or not store._story_kind_matches(story, ordinal, recipe):
		return false
	for definition in catalog:
		if definition.id == id:
			return false
	var staged := _staged()
	staged.story.recipes[str(ordinal)] = recipe.duplicate(true)
	for key in staged.story.recipes.keys():
		if int(key) < ordinal - StoryCatalog.WINDOW + 1:
			var old_id: String = staged.story.recipes[key].puzzle.id
			staged.boards.erase(old_id)
			staged.completed_ids.erase(old_id)
			staged.story.recipes.erase(key)
	staged.catalog = base_catalog.duplicate(true)
	for value in staged.procedural.values():
		staged.catalog.append(value.puzzle.duplicate(true))
	staged.catalog.append_array(Story.definitions(staged.story))
	staged.current_index = staged.story_index(ordinal)
	staged.boards[id] = {}
	Quality.prune(staged.quality, staged.boards.keys())
	Attempts.prune(staged.story_attempts, staged.boards.keys())
	if not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	_publish(staged)
	return true

func story_corrections_left() -> int:
	return Attempts.remaining(story_attempts, str(catalog[current_index].id)) if is_story() else Attempts.LIMIT

func story_lost() -> bool:
	return is_story() and Attempts.lost(story_attempts, str(catalog[current_index].id))

func restart_story_and_save() -> bool:
	if not is_story() or not quality.pending.is_empty():
		return false
	if current_puzzle().bridges.is_empty() and story_corrections_left() == Attempts.LIMIT and not story_lost():
		return true
	var staged := _staged()
	var id: String = str(catalog[current_index].id)
	staged.boards[id] = {}
	Attempts.restart(staged.story_attempts, id)
	Quality.fault(staged.quality, id, false)
	if not store.save_game(staged.snapshot_data(), base_catalog):
		return false
	_publish(staged)
	return true
