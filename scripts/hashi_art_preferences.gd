extends RefCounted
## Cosmetic preference kept separately from puzzle/progress snapshots.
var path: String
var motion := true
func _init(file_path: String) -> void:
	path = file_path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var stored: Variant = config.get_value("appearance", "motion", true)
		if stored is bool:
			motion = stored
func save_motion(value: bool) -> bool:
	var config := ConfigFile.new()
	config.set_value("appearance", "motion", value)
	if config.save(path) != OK:
		return false
	motion = value
	return true
