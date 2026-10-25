class_name HashiSaveStore
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_rules.gd")
const VERSION := 1
const MAX_BYTES := 131072
var path: String
var last_error := ""

func _init(save_path: String = "user://hashi-save-v1.json") -> void:
	path = save_path

func valid_snapshot(data: Variant, catalog: Array) -> bool:
	if not data is Dictionary or not data.has_all(["version", "current_puzzle_id", "boards", "completed_ids"]):
		return false
	if not _integer(data.version) or data.version != VERSION:
		return false
	if not data.current_puzzle_id is String or not data.boards is Dictionary or not data.completed_ids is Array:
		return false
	var known := {}
	for definition in catalog:
		known[str(definition.id)] = definition
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

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

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
