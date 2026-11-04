class_name HashiSaveStore
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rule_set.gd")
const VariantRecipe = preload("res://scripts/hashi_variant_recipe.gd")
const Generator = preload("res://scripts/hashi_generator.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const Mode = preload("res://scripts/hashi_play_mode.gd")
const Story = preload("res://scripts/hashi_story_state.gd")
const StoryCatalog = preload("res://scripts/hashi_story_catalog.gd")
const Quality = preload("res://scripts/hashi_quality.gd")
const Attempts = preload("res://scripts/hashi_story_attempts.gd")
const VERSION := 7
const MAX_BYTES := 131072
var path: String
var last_error := ""

func _init(save_path: String = "user://hashi-save-v1.json") -> void:
	path = save_path

func valid_snapshot(data: Variant, catalog: Array) -> bool:
	if not data is Dictionary or not data.has_all(["version", "current_puzzle_id", "boards", "completed_ids"]):
		return false
	if not _integer(data.version) or int(data.version) not in [1, 2, 3, 4, 5, 6, VERSION]:
		return false
	if not data.current_puzzle_id is String or not data.boards is Dictionary or not data.completed_ids is Array:
		return false
	var allowed := ["version", "current_puzzle_id", "boards", "completed_ids"]
	if data.version >= 2:
		allowed.append("procedural")
		if not data.get("procedural") is Dictionary or data.procedural.size() > 1:
			return false
	if data.version >= 3:
		allowed.append("run")
		if not Mode.valid(data.get("run"), data.procedural):
			return false
	if data.version >= 4:
		allowed.append("story")
		if not Story.valid(data.get("story")):
			return false
	if data.version >= 6:
		allowed.append("quality")
	if data.version >= 7:
		allowed.append("story_attempts")
	for field in data:
		if field not in allowed:
			return false
	var known := {}
	var story_definitions: Array = []
	for definition in catalog:
		known[str(definition.id)] = definition
	if data.version >= 2:
		for id in data.procedural:
			if not id is String or known.has(id):
				return false
			var recipe := normalize_recipe(id, data.procedural[id])
			if recipe.is_empty():
				return false
			known[id] = recipe.puzzle
	if data.version >= 4:
		story_definitions = StoryCatalog.definitions()
		for definition in story_definitions:
			if known.has(definition.id):
				return false
			known[definition.id] = definition
		for ordinal in data.story.recipes:
			var recipe: Dictionary = data.story.recipes[ordinal]
			var id: String = str(recipe.puzzle.get("id", ""))
			if known.has(id) or normalize_story_recipe(id, recipe).is_empty() or not _story_kind_matches(data.story, int(ordinal), recipe):
				return false
			known[id] = recipe.puzzle
		if Story.ordinal(data.story, data.current_puzzle_id) >= 0 and not Story.unlocked(data.story, data.current_puzzle_id):
			return false
	if data.version >= 6:
		if not Quality.valid(data.get("quality"), known):
			return false
		for event in data.quality.pending:
			if event.id != data.current_puzzle_id or not _valid_bridges(event.bridges, known[event.id]) or (event.iron and (data.run.mode != "iron" or not data.procedural.has(event.id))):
				return false
	if not known.has(data.current_puzzle_id) or not data.boards.has(data.current_puzzle_id):
		return false
	if data.boards.size() > known.size() or data.completed_ids.size() > known.size():
		return false
	if data.version >= 7:
		var story_ids: Array = []
		for id in known:
			if Story.ordinal(data.story, id) >= 0:
				story_ids.append(id)
		if not Attempts.valid(data.get("story_attempts"), story_ids, data.boards):
			return false
	for id in data.boards:
		if not id is String or not known.has(id) or not _valid_bridges(data.boards[id], known[id]):
			return false
	if data.version >= 7:
		for id in data.story_attempts.levels:
			var entry: Dictionary = data.story_attempts.levels[id]
			if entry.left == 0 and not entry.lost:
				var solved_board := Puzzle.new(known[id])
				solved_board.bridges = data.boards[id].duplicate(true)
				if not Rules.is_solved(solved_board):
					return false
	var completed := {}
	for id in data.completed_ids:
		if not id is String or not known.has(id) or completed.has(id):
			return false
		if data.version >= 4 and Story.ordinal(data.story, id) >= int(data.story.frontier):
			return false
		completed[id] = true
	if data.version >= 4:
		for i in mini(StoryCatalog.COUNT, int(data.story.frontier)):
			if story_definitions[i].id not in completed:
				return false
	return true

func normalize_recipe(id: String, value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 5 or not value.has_all(["seed", "algorithm_version", "identity_schema", "parameters", "puzzle"]):
		return {}
	if not value.seed is String or not value.seed.is_valid_int() or str(value.seed.to_int()) != value.seed:
		return {}
	if value.algorithm_version != Generator.ALGORITHM_VERSION or not _integer(value.identity_schema) or value.identity_schema != Generator.IDENTITY_SCHEMA_VERSION:
		return {}
	var settings: Variant = value.parameters
	if not settings is Dictionary or settings.size() != Generator.CONTENT_DEFAULTS.size() + Generator.BUDGET_DEFAULTS.size():
		return {}
	var normalized := {}
	for name in Generator.CONTENT_DEFAULTS.keys() + Generator.BUDGET_DEFAULTS.keys():
		if not settings.has(name) or not _integer(settings[name]):
			return {}
		normalized[name] = int(settings[name])
	if normalized.width < 1 or normalized.width > 16 or normalized.height < 1 or normalized.height > 16 or normalized.island_count < 2 or normalized.island_count > 64 or normalized.island_count > normalized.width * normalized.height or normalized.max_attempts < 1 or normalized.max_attempts > 10000 or normalized.max_time_ms < 1 or normalized.max_time_ms > 60000 or normalized.solver_max_nodes < 1 or normalized.solver_max_nodes > 1000000:
		return {}
	var definition: Variant = value.puzzle
	if not definition is Dictionary or definition.size() != 3 or not definition.has_all(["id", "title", "islands"]):
		return {}
	if definition.id != id or not definition.title is String or definition.title.length() > 80 or not definition.islands is Array or definition.islands.size() != normalized.island_count:
		return {}
	var islands: Array = definition.islands.duplicate(true)
	for item in islands:
		if not item is Dictionary or item.size() != 6 or not item.has_all(["id", "x", "y", "target", "variant", "color"]):
			return {}
		if not item.id is String or item.id.length() > 32 or item.variant != "classic" or item.color != "neutral":
			return {}
		for field in ["x", "y", "target"]:
			if not _integer(item[field]):
				return {}
			item[field] = int(item[field])
		if item.x < 0 or item.x >= normalized.width or item.y < 0 or item.y >= normalized.height:
			return {}
	var puzzle := Puzzle.new({"id": id, "title": definition.title, "islands": islands})
	if not Solver.valid_input(puzzle):
		return {}
	var content := {}
	for name in Generator.CONTENT_DEFAULTS:
		content[name] = normalized[name]
	if Generator.puzzle_identity(value.seed.to_int(), content, islands) != id:
		return {}
	return {"seed": value.seed, "algorithm_version": Generator.ALGORITHM_VERSION,
		"identity_schema": Generator.IDENTITY_SCHEMA_VERSION, "parameters": normalized,
		"puzzle": {"id": id, "title": definition.title, "islands": islands}}

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) <= 9007199254740991.0 and float(value) == floor(float(value))

func _valid_bridges(bridges: Variant, definition: Dictionary) -> bool:
	if not bridges is Dictionary:
		return false
	var puzzle := Puzzle.new(definition)
	if not Rules.valid_definition(puzzle):
		return false
	# Validate every endpoint before invoking geometry on any saved edge.
	for edge in bridges:
		if not edge is String or not _integer(bridges[edge]) or bridges[edge] < 1 or bridges[edge] > 2:
			return false
		var ids: PackedStringArray = edge.split(":")
		if ids.size() != 2 or puzzle.key(ids[0], ids[1]) != edge or not Rules.aligned_neighbors(puzzle, ids[0], ids[1]):
			return false
	puzzle.bridges = bridges.duplicate(true)
	for edge in puzzle.bridges:
		var ids: PackedStringArray = edge.split(":")
		if not Rules.move_error(puzzle, ids[0], ids[1], int(puzzle.bridges[edge])).is_empty():
			return false
	# Excess degrees and disconnected partial boards are legal editing states.
	return true

func load_game(catalog: Array) -> Dictionary:
	last_error = ""
	if not path.begins_with("user://"):
		last_error = "Ruta de guardado inválida."
		return {}
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		last_error = "No se pudo leer la partida."
		return {}
	var parser := JSON.new()
	var text := file.get_as_text()
	file.close()
	if parser.parse(text) != OK or not valid_snapshot(parser.data, catalog):
		last_error = "La partida guardada no es compatible o contiene datos inválidos."
		return {}
	var restored: Dictionary = parser.data.duplicate(true)
	# JSON numbers are floats in Godot; normalize validated counts for the model.
	restored.version = VERSION
	restored.story_attempts = parser.data.get("story_attempts", Attempts.fresh()).duplicate(true)
	restored.story_attempts.version = 1
	for id in restored.story_attempts.levels:
		restored.story_attempts.levels[id].left = int(restored.story_attempts.levels[id].left)
	restored.quality = parser.data.get("quality", Quality.fresh()).duplicate(true)
	if parser.data.version < 6:
		for id in parser.data.boards:
			restored.quality.marks[id] = {"spoiled": true, "credited": id in parser.data.completed_ids}
	for key in ["version", "streak", "best", "iron_record", "serial"]:
		restored.quality[key] = int(restored.quality[key])
	for event in restored.quality.pending:
		event.serial = int(event.serial)
		for edge in event.bridges:
			event.bridges[edge] = int(event.bridges[edge])
	restored.story = Story.migrate(parser.data.get("story", Story.fresh()))
	for ordinal in restored.story.recipes:
		var recipe: Dictionary = restored.story.recipes[ordinal]
		restored.story.recipes[ordinal] = normalize_story_recipe(str(recipe.puzzle.id), recipe)
	restored.run = parser.data.get("run", Mode.fresh()).duplicate(true)
	restored.run.wins = int(restored.run.wins)
	restored.run.version = Mode.VERSION
	restored.procedural = {}
	for id in parser.data.get("procedural", {}):
		restored.procedural[id] = normalize_recipe(id, parser.data.procedural[id])
	if parser.data.version < 3 and not restored.procedural.is_empty():
		var previous_id: String = restored.procedural.keys()[0]
		# Historical completions are not wins in a newly introduced run.
		if previous_id in restored.completed_ids:
			restored.run.credited_id = previous_id
		if "Reflexivo" in str(restored.procedural[previous_id].puzzle.title):
			restored.run.board_profile = "contradiction1"
	for id in restored.boards:
		for edge in restored.boards[id]:
			restored.boards[id][edge] = int(restored.boards[id][edge])
	return restored

func save_game(data: Dictionary, catalog: Array) -> bool:
	last_error = ""
	if not path.begins_with("user://") or not valid_snapshot(data, catalog):
		last_error = "No se pudo validar la partida."
		return false
	var encoded := JSON.stringify(data)
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "La partida supera el tamaño permitido."
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "No se pudo guardar la partida."
		return false
	file.store_string(encoded)
	file.flush()
	var result := file.get_error()
	file.close()
	if result == OK:
		result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		last_error = "No se pudo guardar la partida."
		return false
	return true


func normalize_story_recipe(id: String, recipe: Variant) -> Dictionary:
	if recipe is Dictionary and recipe.get("algorithm_version") == VariantRecipe.VERSION:
		return VariantRecipe.normalize(id, recipe)
	return normalize_recipe(id, recipe)
func _story_kind_matches(story: Dictionary, ordinal: int, recipe: Dictionary) -> bool:
	var expected := Story.kind(story, ordinal)
	return recipe.get("algorithm_version") == Generator.ALGORITHM_VERSION if expected == "classic" else recipe.get("algorithm_version") == VariantRecipe.VERSION and recipe.get("parameters", {}).get("kind") == expected
