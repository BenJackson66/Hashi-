class_name HashiStoryPolicy
extends RefCounted
const Catalog = preload("res://scripts/hashi_story_catalog.gd")
const Variants = preload("res://scripts/hashi_variant_generator.gd")
const Free = preload("res://scripts/hashi_free_play.gd")
## Fixed ruleset/version and content schedule. Budgets only limit computation.
const VERSION := "classic-continuation-1"
const MAX_ORDINAL := 9007199254740000
static func profile(ordinal: int) -> String:
	if ordinal < Catalog.COUNT:
		return str(Catalog.entries()[ordinal].profile)
	return "local" if ordinal % Catalog.STAGE_SIZE < 2 else "contradiction1"
static func seed_for(ordinal: int, retry: int = 0) -> int:
	var digest := (VERSION + ":" + str(ordinal) + ":" + str(retry)).sha256_text()
	return digest.substr(0, 8).hex_to_int() % 2147483646
static func fingerprint(definition: Dictionary) -> String:
	var clues: Array = []
	for island in definition.islands:
		clues.append([int(island.x), int(island.y), int(island.target), str(island.get("variant", "classic"))])
	clues.sort()
	return JSON.stringify(clues).sha256_text()
static func generate(ordinal: int, budgets: Dictionary = {}, excluded: Array = [], variant_from: int = -1) -> Dictionary:
	if ordinal < Catalog.COUNT or ordinal > MAX_ORDINAL:
		return {"status": "failure", "reason": "invalid_story_ordinal"}
	var kind := kind_at(ordinal, variant_from)
	if kind != "classic":
		return _generate_variant(ordinal, kind, budgets, excluded)
	var started := Time.get_ticks_msec()
	for retry in 16:
		var remaining := 10000 - (Time.get_ticks_msec() - started)
		if remaining <= 0:
			break
		var generated := Free.new().generate(seed_for(ordinal, retry), profile(ordinal), budgets, "", 128, remaining)
		if generated.status != "success":
			return generated
		var duplicate := false
		for definition in excluded:
			if generated.puzzle.id == definition.id or fingerprint(generated.puzzle) == fingerprint(definition):
				duplicate = true
		if duplicate:
			continue
		generated.puzzle.title = Catalog.title(ordinal)
		return {"status": "success", "recipe": {"seed": str(generated.seed),
			"algorithm_version": generated.algorithm_version, "identity_schema": 1,
			"parameters": generated.parameters, "puzzle": generated.puzzle}}
	return {"status": "failure", "reason": "story_selection_limit"}

static func kind_at(ordinal: int, variant_from: int = -1) -> String:
	if variant_from < Catalog.COUNT or ordinal < variant_from:
		return "classic"
	return ["blue", "mystery", "combined", "classic"][((ordinal - variant_from) / Catalog.STAGE_SIZE) % 4]
static func _generate_variant(ordinal: int, kind: String, budgets: Dictionary, excluded: Array) -> Dictionary:
	var time_budget: Variant = budgets.get("max_time_ms", 5000)
	if not time_budget is int or time_budget < 1 or time_budget > 10000:
		return {"status": "failure", "reason": "invalid_variant_budget"}
	var deadline: int = Time.get_ticks_msec() + time_budget
	for retry in 8:
		var remaining := deadline - Time.get_ticks_msec()
		if remaining <= 0:
			return {"status": "failure", "reason": "variant_time_limit"}
		var options := budgets.duplicate(true)
		options.max_time_ms = mini(time_budget, remaining)
		var digest := ("visible-route-1:" + str(ordinal) + ":" + str(retry)).sha256_text()
		var result := Variants.new().generate(digest.substr(0, 8).hex_to_int() % 2147483646, kind, options)
		if result.status != "success":
			return result
		var duplicate := false
		for definition in excluded:
			if result.recipe.puzzle.id == definition.id or fingerprint(result.recipe.puzzle) == fingerprint(definition):
				duplicate = true
		if not duplicate:
			result.recipe.puzzle.title = Catalog.title(ordinal)
			return result
	return {"status": "failure", "reason": "variant_selection_limit"}
