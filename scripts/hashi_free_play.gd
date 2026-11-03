class_name HashiFreePlay
extends RefCounted
## Selection/rejection policy, separate from generation, rules and presentation.
const Generator = preload("res://scripts/hashi_generator.gd")
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Logical = preload("res://scripts/hashi_logical_profile.gd")
const VERSION := "free-play-1"
const LABELS := {"local": "Directo", "contradiction1": "Reflexivo"}
const LAYOUTS := [Vector3i(5, 5, 10), Vector3i(6, 6, 12), Vector3i(7, 7, 16)]

func generate(seed_value: int, profile: String, budgets: Dictionary = {}, excluded_id: String = "", max_candidates: int = 64, max_time_ms: int = 3000) -> Dictionary:
	if not LABELS.has(profile) or max_candidates < 0 or max_candidates > 128 or max_time_ms < 0 or max_time_ms > 10000:
		return {"status": "failure", "reason": "invalid_selection"}
	var started := Time.get_ticks_usec()
	var deadline := started + max_time_ms * 1000
	for attempt in max_candidates:
		var remaining := int((deadline - Time.get_ticks_usec()) / 1000)
		if remaining <= 0:
			return {"status": "failure", "reason": "selection_time_limit"}
		var candidate_seed := posmod(seed_value + attempt * 104729, 2147483646)
		var layout: Vector3i = LAYOUTS[posmod(seed_value + attempt, LAYOUTS.size())]
		var options := {"width": layout.x, "height": layout.y, "island_count": layout.z}
		# Budgets constrain work, never define difficulty. Content comes from policy.
		for key in Generator.BUDGET_DEFAULTS:
			options[key] = budgets.get(key, Generator.BUDGET_DEFAULTS[key])
		options.max_time_ms = mini(int(options.max_time_ms), remaining)
		var generated := Generator.new().generate(candidate_seed, options)
		if generated.status != "success":
			return generated
		if generated.puzzle.id == excluded_id:
			continue
		remaining = int((deadline - Time.get_ticks_usec()) / 1000)
		var classified := Logical.new().analyze(Puzzle.new(generated.puzzle), maxi(0, remaining))
		if Time.get_ticks_usec() >= deadline:
			return {"status": "failure", "reason": "selection_time_limit"}
		if classified.status in ["invalid", "contradiction"]:
			return {"status": "failure", "reason": "logical_inconsistent"}
		if classified.status in ["time_limit", "probe_limit"]:
			return {"status": "failure", "reason": "classification_limit"}
		if classified.status == "solved" and classified.profile == profile:
			generated.puzzle.title = "Libre · " + str(LABELS[profile])
			generated.selection = {"version": VERSION, "profile": profile, "candidates": attempt + 1,
				"elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
			return generated
	return {"status": "failure", "reason": "selection_attempt_limit"}
