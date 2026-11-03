extends RefCounted
## Optional next-board preference, independent from the unchanged v1/v2 game save.
const Policy = preload("res://scripts/hashi_free_play.gd")
var path: String
var profile := "local"

func _init(file_path: String) -> void:
	path = file_path

func restore() -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return
	file.close()
	var config := ConfigFile.new()
	if config.load(path) == OK and config.get_value("free", "version", 0) == 1:
		var value: Variant = config.get_value("free", "profile", "local")
		if value is String and Policy.LABELS.has(value):
			profile = value

func choose(value: String) -> bool:
	if not Policy.LABELS.has(value) or not path.begins_with("user://"):
		return false
	profile = value
	var config := ConfigFile.new()
	config.set_value("free", "version", 1)
	config.set_value("free", "profile", value)
	if config.save(path + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK
