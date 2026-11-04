class_name HashiVariantGenerator
extends RefCounted
## Transform and prove within the worker. No witness crosses this class boundary.
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Generator = preload("res://scripts/hashi_generator.gd")
const Solver = preload("res://scripts/hashi_variant_solver.gd")
const Rules = preload("res://scripts/hashi_variant_rules.gd")
const Recipe = preload("res://scripts/hashi_variant_recipe.gd")
func generate(seed_value: int, kind: String, budgets: Dictionary = {}) -> Dictionary:
	if seed_value < 0 or seed_value >= 2147483646 or kind not in Recipe.KINDS:
		return {"status": "failure", "reason": "invalid_variant_request"}
	var time_budget: Variant = budgets.get("max_time_ms", 5000)
	var node_budget: Variant = budgets.get("solver_max_nodes", 100000)
	var attempts: Variant = budgets.get("max_attempts", 100)
	if not time_budget is int or time_budget < 1 or time_budget > 10000 or not node_budget is int or node_budget < 1 or node_budget > 1000000 or not attempts is int or attempts < 1 or attempts > 10000:
		return {"status": "failure", "reason": "invalid_variant_budget"}
	var deadline: int = Time.get_ticks_msec() + time_budget
	for attempt in mini(attempts, 64):
		var remaining: int = deadline - Time.get_ticks_msec()
		if remaining <= 0:
			return {"status": "failure", "reason": "variant_time_limit"}
		var candidate_seed := (str(seed_value) + ":" + str(attempt) + ":" + Recipe.VERSION).sha256_text().substr(0, 8).hex_to_int() % 2147483646
		var options := {"width": 5, "height": 5, "island_count": 10, "max_time_ms": mini(remaining, 1500), "max_attempts": 100, "solver_max_nodes": node_budget}
		var generated := Generator.new().generate(candidate_seed, options)
		if generated.status != "success":
			if generated.reason == "attempt_limit":
				continue
			return {"status": "failure", "reason": "variant_source_" + str(generated.reason)}
		var definition: Dictionary = generated.puzzle.duplicate(true)
		definition.ruleset = Rules.VERSION
		var witness: Dictionary = generated.solution
		# Sort candidates so blue with two or more visible bridges is preferred.
		var eligible: Array = []
		for item in definition.islands:
			var simple := true
			for edge in witness:
				if item.id in str(edge).split(":") and witness[edge] == 2:
					simple = false
			if simple:
				eligible.append(item)
		eligible.sort_custom(func(a, b): return int(a.target) > int(b.target))
		if kind in ["blue", "combined"]:
			if eligible.is_empty() or int(eligible[0].target) < 2:
				continue
			eligible[0].variant = "blue"
			eligible[0].color = "blue"
		if kind in ["mystery", "combined"]:
			var accepted := 0
			for item in definition.islands:
				if item.variant != "classic":
					continue
				remaining = deadline - Time.get_ticks_msec()
				if remaining <= 0:
					return {"status": "failure", "reason": "variant_time_limit"}
				var original := int(item.target)
				item.target = 0
				item.variant = "mystery"
				item.color = "mystery"
				var result := Solver.new().solve(Puzzle.new(definition), {"max_time_ms": mini(remaining, 1000), "max_nodes": node_budget})
				if result.status == "unique":
					accepted += 1
				elif result.status == "multiple":
					item.target = original
					item.variant = "classic"
					item.color = "neutral"
				else:
					return {"status": "failure", "reason": "variant_solver_" + str(result.reason) if result.status == "incomplete" else "variant_solver_inconsistent"}
				if accepted == 2:
					break
			if accepted == 0:
				continue
		remaining = deadline - Time.get_ticks_msec()
		if remaining <= 0:
			return {"status": "failure", "reason": "variant_time_limit"}
		var verified := Solver.new().solve(Puzzle.new(definition), {"max_time_ms": mini(remaining, 1000), "max_nodes": node_budget})
		if verified.status != "unique":
			return {"status": "failure", "reason": "variant_solver_" + str(verified.reason) if verified.status == "incomplete" else "variant_solver_inconsistent"}
		var parameters := {"width": 5, "height": 5, "island_count": 10, "kind": kind}
		definition.id = Recipe.identity(str(candidate_seed), parameters, definition.islands)
		definition.title = "Historia · " + {"blue": "Azules", "mystery": "Misteriosas", "combined": "Combinadas"}[kind]
		return {"status": "success", "recipe": {"seed": str(candidate_seed), "algorithm_version": Recipe.VERSION, "identity_schema": 1, "parameters": parameters, "puzzle": definition}}
	return {"status": "failure", "reason": "variant_attempt_limit"}
