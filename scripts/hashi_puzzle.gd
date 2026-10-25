class_name HashiPuzzle
extends RefCounted
## UI-independent state. Stable IDs and metadata leave room for variants and saves.
## No generation, solving, persistence or variant behavior is implemented here.
var puzzle_id: String
var title: String
var islands: Array = []
var bridges: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	puzzle_id = str(data.get("id", ""))
	title = str(data.get("title", ""))
	islands = data.get("islands", []).duplicate(true)

func island(id: String) -> Dictionary:
	for item in islands:
		if str(item.id) == id:
			return item
	return {}

func key(a: String, b: String) -> String:
	return a + ":" + b if a < b else b + ":" + a

func bridge_count(a: String, b: String) -> int:
	return int(bridges.get(key(a, b), 0))

func degree(id: String) -> int:
	var total := 0
	for edge in bridges:
		if id in edge.split(":"):
			total += int(bridges[edge])
	return total

func reset() -> void:
	bridges.clear()
