class_name HashiStoryState
extends RefCounted
const Catalog = preload("res://scripts/hashi_story_catalog.gd")
const Policy = preload("res://scripts/hashi_story_policy.gd")
static func fresh() -> Dictionary:
	return {"version": 1, "policy": Policy.VERSION, "frontier": 0, "recipes": {}}
static func ordinal(state: Dictionary, id: String) -> int:
	var intro := Catalog.intro_ordinal(id)
	if intro >= 0:
		return intro
	for key in state.recipes:
		if state.recipes[key].puzzle.id == id:
			return int(key)
	return -1
static func unlocked(state: Dictionary, id: String) -> bool:
	var value := ordinal(state, id)
	return value >= 0 and value <= state.frontier
static func credit(state: Dictionary, id: String) -> Dictionary:
	var result := state.duplicate(true)
	if ordinal(state, id) == int(state.frontier):
		result.frontier = mini(int(state.frontier) + 1, Policy.MAX_ORDINAL)
	return result
static func definitions(state: Dictionary) -> Array:
	var result := Catalog.definitions()
	var keys: Array = state.recipes.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for key in keys:
		result.append(state.recipes[key].puzzle.duplicate(true))
	return result
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.has_all(["version", "policy", "frontier", "recipes"]):
		return false
	if value.version != 1 or value.policy != Policy.VERSION or not (value.frontier is int or value.frontier is float) or not is_finite(float(value.frontier)) or float(value.frontier) != floor(float(value.frontier)) or value.frontier < 0 or value.frontier > Policy.MAX_ORDINAL:
		return false
	if not value.recipes is Dictionary or value.recipes.size() > Catalog.WINDOW:
		return false
	for key in value.recipes:
		if not key is String or not key.is_valid_int() or str(key.to_int()) != key or key.to_int() < Catalog.COUNT or key.to_int() > value.frontier or key.to_int() < maxi(Catalog.COUNT, int(value.frontier) - Catalog.WINDOW):
			return false
		if not value.recipes[key] is Dictionary or not value.recipes[key].get("puzzle") is Dictionary:
			return false
	return true
