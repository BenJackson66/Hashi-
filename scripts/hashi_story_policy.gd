class_name HashiStoryPolicy
extends RefCounted
const Catalog = preload("res://scripts/hashi_story_catalog.gd")
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
		clues.append([int(island.x), int(island.y), int(island.target)])
	clues.sort()
	return JSON.stringify(clues).sha256_text()
static func generate(ordinal: int, budgets: Dictionary = {}, excluded: Array = []) -> Dictionary:
	if ordinal < Catalog.COUNT or ordinal > MAX_ORDINAL:
		return {"status": "failure", "reason": "invalid_story_ordinal"}
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
