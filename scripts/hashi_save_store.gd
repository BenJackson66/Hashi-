class_name HashiSaveStore
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const Generator = preload("res://scripts/hashi_generator.gd")
const Solver = preload("res://scripts/hashi_solver.gd")
const VERSION := 2
const MAX_BYTES := 131072
var path: String
var last_error := ""

func _init(save_path: String = "user://hashi-save-v1.json") -> void:
	path = save_path

func valid_snapshot(data: Variant, catalog: Array) -> bool:
	if not data is Dictionary or not data.has_all(["version", "current_puzzle_id", "boards", "completed_ids"]):
		return false
	if not _integer(data.version) or (data.version != 1 and data.version != VERSION):
		return false
	if not data.current_puzzle_id is String or not data.boards is Dictionary or not data.completed_ids is Array:
		return false
	var allowed := ["version", "current_puzzle_id", "boards", "completed_ids"]
	if data.version == VERSION:
		allowed.append("procedural")
		if not data.get("procedural") is Dictionary or data.procedural.size() > 1:
			return false
	for field in data:
		if field not in allowed:
			return false
	var known := {}
	for definition in catalog:
		known[str(definition.id)] = definition
	if data.version == VERSION:
		for id in data.procedural:
			if not id is String or known.has(id):
				return false
			var recipe := normalize_recipe(id, data.procedural[id])
			if recipe.is_empty():
				return false
			known[id] = recipe.puzzle
	if not known.has(data.current_puzzle_id) or not data.boards.has(data.current_puzzle_id):
		return false
	if data.boards.size() > known.size() or data.completed_ids.size() > known.size():
		return false
	for id in data.boards:
		if not id is String or not known.has(id) or not _valid_bridges(data.boards[id], known[id]):
			return false
	var completed := {}
	for id in data.completed_ids:
		if not id is String or not known.has(id) or completed.has(id):
			return false
		completed[id] = true
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
	restored.procedural = {}
	for id in parser.data.get("procedural", {}):
		restored.procedural[id] = normalize_recipe(id, parser.data.procedural[id])
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
