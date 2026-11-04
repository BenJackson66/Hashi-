class_name HashiPlayMode
extends RefCounted
## Versioned run policy. Size and CPU time never define challenge.
const VERSION := 1
const MODES := ["free", "fixed", "progression", "iron"]
const PROFILES := ["local", "contradiction1"]
const MAX_WINS := 9007199254740990

static func fresh(mode: String = "free", profile: String = "local") -> Dictionary:
	return {"version": VERSION, "mode": mode, "fixed_profile": profile,
		"wins": 0, "credited_id": "", "board_profile": profile}

static func valid(value: Variant, procedural: Dictionary) -> bool:
	if not value is Dictionary or value.size() != 6 or not value.has_all(["version", "mode", "fixed_profile", "wins", "credited_id", "board_profile"]):
		return false
	if not value.version is int and not value.version is float:
		return false
	if value.version != VERSION or value.mode not in MODES or value.fixed_profile not in PROFILES or value.board_profile not in PROFILES:
		return false
	if not (value.wins is int or value.wins is float) or not is_finite(float(value.wins)) or value.wins < 0 or value.wins > MAX_WINS or float(value.wins) != floor(float(value.wins)):
		return false
	if not value.credited_id is String or (not value.credited_id.is_empty() and not procedural.has(value.credited_id)):
		return false
	if value.mode in ["fixed", "iron"] and value.fixed_profile != value.board_profile:
		return false
	if value.mode == "progression" and not procedural.is_empty():
		var at_entry: Dictionary = value.duplicate(true)
		at_entry.wins = int(value.wins) - (0 if value.credited_id.is_empty() else 1)
		if at_entry.wins < 0 or next_profile(at_entry) != value.board_profile:
			return false
	if value.mode != "free" and procedural.is_empty():
		return false
	return true

static func next_profile(run: Dictionary, free_profile: String = "local") -> String:
	if run.mode in ["fixed", "iron"]:
		return str(run.fixed_profile)
	if run.mode == "free":
		return free_profile
	var wins := int(run.wins)
	if wins < 3:
		return "local"
	if wins < 7:
		return "local" if (wins - 3) % 2 == 0 else "contradiction1"
	return "contradiction1"

static func credit(run: Dictionary, puzzle_id: String) -> Dictionary:
	var updated := run.duplicate(true)
	if updated.credited_id != puzzle_id:
		updated.wins = mini(MAX_WINS, int(updated.wins) + 1)
		updated.credited_id = puzzle_id
	return updated

static func description(run: Dictionary) -> String:
	var label := "Directo" if run.board_profile == "local" else "Reflexivo"
	if run.mode == "iron":
		return "Alma de Hierro · %s · %d perfectos" % [label, int(run.wins)]
	if run.mode == "fixed":
		return "Dificultad fija · %s · %d resueltos" % [label, int(run.wins)]
	if run.mode == "progression":
		var wins := int(run.wins)
		var stage := "Etapa 1 · Directo · %d/3" % wins if wins < 3 else ("Etapa 2 · Alternancia · %d/4" % (wins - 3) if wins < 7 else "Etapa 3 · Reflexivo · sin final")
		return "Progresión · %s · Tablero %s" % [stage, label]
	return "Partida libre · " + label
