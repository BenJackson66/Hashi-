class_name HashiStoryCatalog
extends RefCounted
## Immutable introduction; generated continuation has a separate policy namespace.
const COUNT := 12
const STAGE_SIZE := 4
const WINDOW := 4
const VERSION := "story-classic-v1"
static var _cached_entries: Array = []
static func _data() -> Array:
	if _cached_entries.is_empty():
		_cached_entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/story-classic-v1.json"))
	return _cached_entries
static func entries() -> Array:
	return _data().duplicate(true)
static func definitions() -> Array:
	var result: Array = []
	for entry in _data():
		result.append(entry.puzzle.duplicate(true))
	return result
static func intro_ordinal(id: String) -> int:
	var values := _data()
	for i in values.size():
		if values[i].puzzle.id == id:
			return i
	return -1
static func title(ordinal: int) -> String:
	return "Etapa %d · Nivel %d" % [ordinal / STAGE_SIZE + 1, ordinal % STAGE_SIZE + 1]
