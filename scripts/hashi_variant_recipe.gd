class_name HashiVariantRecipe
extends RefCounted
const Puzzle = preload("res://scripts/hashi_puzzle.gd")
const Rules = preload("res://scripts/hashi_variant_rules.gd")
const VERSION := "visible-variants-generator-1"
const KINDS := ["blue", "mystery", "combined"]
static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= 9007199254740991.0
static func identity(seed_value: String, parameters: Dictionary, islands: Array) -> String:
	var clues: Array = []
	for item in islands:
		clues.append([item.id, int(item.x), int(item.y), int(item.target), item.variant, item.color])
	clues.sort()
	return "variant-1-" + JSON.stringify([VERSION, Rules.VERSION, seed_value, int(parameters.width), int(parameters.height), int(parameters.island_count), parameters.kind, clues]).sha256_text()
static func normalize(id: String, value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 5 or not value.has_all(["seed", "algorithm_version", "identity_schema", "parameters", "puzzle"]):
		return {}
	if value.algorithm_version != VERSION or value.identity_schema != 1 or not integer(value.identity_schema) or not value.seed is String or not value.seed.is_valid_int() or str(value.seed.to_int()) != value.seed or value.seed.to_int() < 0 or value.seed.to_int() >= 2147483646:
		return {}
	var parameters: Variant = value.parameters
	if not parameters is Dictionary or parameters.size() != 4 or not parameters.has_all(["width", "height", "island_count", "kind"]) or parameters.kind not in KINDS:
		return {}
	for field in ["width", "height", "island_count"]:
		if not integer(parameters[field]):
			return {}
	if parameters.width < 1 or parameters.width > 16 or parameters.height < 1 or parameters.height > 16 or parameters.island_count < 2 or parameters.island_count > 64:
		return {}
	var definition: Variant = value.puzzle
	if not definition is Dictionary or definition.size() != 4 or not definition.has_all(["id", "title", "islands", "ruleset"]) or definition.id != id or not definition.title is String or definition.title.length() > 80 or not definition.islands is Array or definition.islands.size() != parameters.island_count:
		return {}
	var puzzle := Puzzle.new(definition)
	if not Rules.valid_definition(puzzle):
		return {}
	var blues := 0
	var mysteries := 0
	var islands: Array = definition.islands.duplicate(true)
	for item in islands:
		if item.x >= parameters.width or item.y >= parameters.height:
			return {}
		if item.variant == "blue":
			blues += 1
		if item.variant == "mystery":
			mysteries += 1
		for field in ["x", "y", "target"]:
			item[field] = int(item[field])
	if mysteries > 2 or (parameters.kind == "blue" and (blues == 0 or mysteries != 0)) or (parameters.kind == "mystery" and (mysteries == 0 or blues != 0)) or (parameters.kind == "combined" and (blues == 0 or mysteries == 0)):
		return {}
	var normalized := {"width": int(parameters.width), "height": int(parameters.height), "island_count": int(parameters.island_count), "kind": parameters.kind}
	if identity(value.seed, normalized, islands) != id:
		return {}
	return {"seed": value.seed, "algorithm_version": VERSION, "identity_schema": 1, "parameters": normalized,
		"puzzle": {"id": id, "title": definition.title, "ruleset": Rules.VERSION, "islands": islands}}
