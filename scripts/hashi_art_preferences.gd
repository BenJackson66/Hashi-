extends RefCounted
## Cosmetic preferences remain separate from puzzle/progress snapshots.
var path: String
var motion := true
var sound := true
func _init(file_path: String) -> void:
	path=file_path
	var config:=ConfigFile.new()
	if config.load(path)==OK:
		var stored:Variant=config.get_value("appearance","motion",true)
		if stored is bool:motion=stored
		stored=config.get_value("appearance","sound",true)
		if stored is bool:sound=stored
func _save(key: String,value: bool) -> bool:
	var config:=ConfigFile.new()
	config.load(path)
	config.set_value("appearance","motion",motion)
	config.set_value("appearance","sound",sound)
	config.set_value("appearance",key,value)
	if config.save(path+".tmp")!=OK:return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".tmp"));return false
	return true
func save_motion(value: bool) -> bool:
	if not _save("motion",value):return false
	motion=value;return true
func save_sound(value: bool) -> bool:
	if not _save("sound",value):return false
	sound=value;return true
